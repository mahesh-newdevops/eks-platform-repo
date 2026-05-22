FROM python:3.12.8-slim

WORKDIR /app

RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

USER 65532:65532

EXPOSE 5000

CMD ["python", "app.py"]
