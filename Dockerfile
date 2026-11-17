FROM python:3.12-slim
# git dipakai worker untuk mengambil kode (repo job / repo proyek untuk CI) pada commit SHA tertentu
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Runtime untuk build/test repo proyek ada di image ini. Python sudah tersedia.
# Bila repo proyek memakai bahasa lain, tambahkan di baris apt di atas, mis. "nodejs npm".
WORKDIR /app
COPY worker.py .
RUN useradd -u 10001 worker
USER worker
ENV PYTHONDONTWRITEBYTECODE=1
CMD ["python", "-u", "worker.py"]
