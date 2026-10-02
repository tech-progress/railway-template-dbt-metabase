#!/usr/bin/env bash
set -euo pipefail

template_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required=(.dockerignore .env.example .gitignore .railway/railway.ts CHANGELOG.md Dockerfile FINDINGS.md LICENSE_REVIEW.md MARKETPLACE.md PUBLISHING.md README.md SUPPORT.md UPGRADE.md VERSION bun.lock compose.yaml dbt_project.yml package.json profiles.yml requirements.txt template-defaults.json template-descriptions.json template-networking.json template-volumes.json data/orders.csv models/order_summary.sql models/schema.yml scripts/audit-template.sh scripts/bootstrap_metabase.py scripts/health.py scripts/restore-template-draft.sh scripts/smoke.py scripts/start.sh scripts/verify.sh)
for file in "${required[@]}"; do test -f "${template_root}/${file}" || { echo "Missing ${file}" >&2; exit 1; }; done

version="$(<"${template_root}/VERSION")"; [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
escaped_version="${version//./\\.}"
grep -Eq "^## \\[${escaped_version}\\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" "${template_root}/CHANGELOG.md"
for file in README.md PUBLISHING.md; do grep -Fq "current template release is \`v${version}\`" "${template_root}/${file}"; done
publish_description="$(grep -E '^  --description "' "${template_root}/PUBLISHING.md" | cut -d '"' -f 2)"
[[ -n "${publish_description}" && ${#publish_description} -le 75 ]]

METABASE_POSTGRES_PASSWORD=verify-metadata WAREHOUSE_POSTGRES_PASSWORD=verify-warehouse METABASE_ADMIN_PASSWORD='Verify-7qL2!mN9#xP4' MB_ENCRYPTION_SECRET_KEY=verify-encryption-key docker compose -f "${template_root}/compose.yaml" config --quiet
for file in template-defaults.json template-descriptions.json template-networking.json template-volumes.json; do jq empty "${template_root}/${file}"; done
for file in scripts/audit-template.sh scripts/restore-template-draft.sh scripts/start.sh scripts/verify.sh; do bash -n "${template_root}/${file}"; done
python3 -c 'import pathlib,sys; [compile(pathlib.Path(p).read_text(),p,"exec") for p in sys.argv[1:]]' "${template_root}/scripts/bootstrap_metabase.py" "${template_root}/scripts/health.py" "${template_root}/scripts/smoke.py"

graph="$(cd "${template_root}" && ./node_modules/.bin/railway-iac-ts .railway/railway.ts)"
jq -e '
  .graph.resources |
  ([.[] | select(.type=="service") | .name] | sort) == ["Metabase","Metabase PostgreSQL","Warehouse PostgreSQL","dbt"] and
  ([.[] | select(.type=="volume")] | length) == 2 and
  ([.[] | select(.name=="dbt")][0].source.repo == "tech-progress/railway-template-dbt-metabase") and
  ([.[] | select(.name=="dbt")][0].source.branch == "release-v1") and
  ([.[] | select(.name=="dbt")][0].deploy.healthcheckPath == "/health") and
  ([.[] | select(.name=="Metabase")][0].deploy.healthcheckPath == "/api/health")
' <<<"${graph}" >/dev/null

grep -Fxq 'dbt-core==1.12.5' "${template_root}/requirements.txt"
grep -Fxq 'dbt-postgres==1.11.0' "${template_root}/requirements.txt"
grep -Fq 'python:3.12.15-slim-bookworm@sha256:54c85f3c47607a77f32adec749d3c81d1348bf25833671f512b26a9b6d778cb3' "${template_root}/Dockerfile"
for file in compose.yaml .railway/railway.ts; do
  grep -Fq 'metabase/metabase:v0.63.19@sha256:7324f83713df9851c6c7b6c8247098de14c0924fc3b868202f886df4877cd4ff' "${template_root}/${file}"
  grep -Fq 'postgres:17.11-alpine@sha256:b0f9560a2de083e2cc7382e75f808c7381a32852a7ec49117deedb300e552b24' "${template_root}/${file}"
done
jq -e '.Metabase.METABASE_ADMIN_PASSWORD=="${{secret(32)}}" and .Metabase.MB_ENCRYPTION_SECRET_KEY=="${{secret(48)}}" and .Metabase.MB_LOAD_SAMPLE_CONTENT=="false" and .dbt.METABASE_ADMIN_PASSWORD=="${{Metabase.METABASE_ADMIN_PASSWORD}}"' "${template_root}/template-defaults.json" >/dev/null
if find "${template_root}" -type f \( -name .env -o -name '*.local' \) -print -quit | grep -q .; then echo "Local secret file found." >&2; exit 1; fi
echo "dbt + Metabase structure, pins, variables, volumes, and networking are valid."
