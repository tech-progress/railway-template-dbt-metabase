#!/bin/bash
set -euo pipefail

rm -f /tmp/dbt-metabase-ready
python3 /app/scripts/health.py &
health_pid=$!

terminate() {
  kill -TERM "${health_pid}" 2>/dev/null || true
  wait "${health_pid}" 2>/dev/null || true
}
trap terminate INT TERM

run_pipeline() {
  dbt seed --full-refresh
  dbt build --exclude resource_type:seed
}

run_pipeline
python3 /app/scripts/bootstrap_metabase.py
touch /tmp/dbt-metabase-ready

interval="${DBT_RUN_INTERVAL_SECONDS:-86400}"
while true; do
  sleep "${interval}" &
  wait $!
  run_pipeline
done
