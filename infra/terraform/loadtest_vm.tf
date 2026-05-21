resource "azurerm_network_security_group" "loadtest" {
  name                = "${var.cluster_name}-loadtest-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "loadtest" {
  name                = "${var.cluster_name}-loadtest-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "loadtest" {
  name                = "${var.cluster_name}-loadtest-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.loadtest.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.loadtest.id
  }
}

resource "azurerm_network_interface_security_group_association" "loadtest" {
  network_interface_id      = azurerm_network_interface.loadtest.id
  network_security_group_id = azurerm_network_security_group.loadtest.id
}

resource "azurerm_linux_virtual_machine" "loadtest" {
  name                = "${var.cluster_name}-loadtest"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.loadtest_vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.loadtest.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOT
    #cloud-config
    packages:
      - python3-pip
      - python3-venv
    runcmd:
      - python3 -m venv /opt/locust
      - /opt/locust/bin/pip install 'locust>=2.32.0'
      - ln -sf /opt/locust/bin/locust /usr/local/bin/locust
    EOT
  )
}
