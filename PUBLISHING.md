# Publishing

The current template release is `v1.0.1`. Railway builds dbt from `tech-progress/railway-template-dbt-metabase` on `release-v1`; Metabase and PostgreSQL use immutable image digests.

This release uses dbt Core `1.12.5`, dbt-postgres `1.11.0`, the standard Metabase `v0.63.19` image (not the enterprise variant), PostgreSQL `17.11` on Alpine, and Python `3.12.15` on Debian Bookworm.

Run `bun install --frozen-lockfile`, `./scripts/verify.sh`, the empty-volume and initialized-volume smoke tests, and `scripts/check-dbt-metabase-standalone.sh` before release. Verify the exact stored draft with `templateDeployV2`, because legacy template deployment can ignore Composer configuration.

```bash
railway templates publish TEMPLATE_ID \
  --category Analytics \
  --description "Scheduled dbt transformations with a ready-to-use Metabase analytics layer." \
  --readme-file MARKETPLACE.md \
  --json
```
