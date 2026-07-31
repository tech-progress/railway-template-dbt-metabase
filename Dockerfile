FROM python:3.12.11-slim-bookworm@sha256:519591d6871b7bc437060736b9f7456b8731f1499a57e22e6c285135ae657bf7

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
