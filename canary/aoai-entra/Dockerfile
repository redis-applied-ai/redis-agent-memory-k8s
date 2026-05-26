FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

RUN useradd --create-home --uid 65532 --shell /sbin/nologin canary
USER 65532

ENTRYPOINT ["python", "-u", "app.py"]
