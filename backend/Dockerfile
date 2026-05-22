FROM python:3.12.8-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install -r requirements.txt

COPY app.py .

USER 65532:65532

EXPOSE 5000

CMD ["python", "app.py"]
