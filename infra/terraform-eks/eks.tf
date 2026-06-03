# POC networking: reuse the account's default VPC + its (public) subnets.
# Default-VPC subnets span multiple AZs and have internet egress via the IGW,
# which RAM pods need to reach *.openai.azure.com and login.microsoftonline.com.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  # Restrict to EKS-supported AZs. The default VPC has a subnet per AZ, and some
  # (e.g. us-east-1e) cannot host EKS control-plane instances.
  filter {
    name   = "availability-zone"
    values = var.availability_zones
  }
}

# Worker nodes need a public IP for internet egress (to join the cluster and to
# reach *.openai.azure.com / login.microsoftonline.com). A modified default VPC
# can contain extra subnets that do NOT auto-assign public IPs, so restrict the
# node group to the original per-AZ default subnets, which always do.
data "aws_subnets" "nodes" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = var.availability_zones
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# --- Cluster IAM role ---

data "aws_iam_policy_document" "eks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- Cluster ---

resource "aws_eks_cluster" "ram" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = data.aws_subnets.default.ids
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  # API auth + auto-grant admin to the creating principal so `aws eks
  # update-kubeconfig` gives kubectl access without manual aws-auth editing.
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# --- Node group IAM role ---

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# POC: grant EBS CSI permissions to the node role so the addon can provision
# gp3 volumes without a dedicated IRSA role. Production should use IRSA instead.
resource "aws_iam_role_policy_attachment" "node_ebs_csi" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# --- Managed node group ---

resource "aws_eks_node_group" "ram" {
  cluster_name    = aws_eks_cluster.ram.name
  node_group_name = "ram"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = data.aws_subnets.nodes.ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_count
    min_size     = var.node_count
    max_size     = var.node_count
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
    aws_iam_role_policy_attachment.node_ebs_csi,
  ]
}

# --- EBS CSI driver (provisions the gp3 StorageClass volumes for Redis Enterprise) ---

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.ram.name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.ram]
}
