FROM python:3.12.15-slim-bookworm@sha256:54c85f3c47607a77f32adec749d3c81d1348bf25833671f512b26a9b6d778cb3

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DBT_PROFILES_DIR=/app

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --requirement requirements.txt

COPY dbt_project.yml profiles.yml ./
COPY data ./data
COPY models ./models
COPY scripts ./scripts
RUN chmod 0555 scripts/*.py scripts/*.sh

EXPOSE 8080
CMD ["./scripts/start.sh"]
