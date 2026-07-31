# Publishing

The current template release is `v1.0.0`. Railway builds dbt from `tech-progress/railway-template-dbt-metabase` on `release-v1`; Metabase and PostgreSQL use immutable image digests.

Run `bun install --frozen-lockfile`, `./scripts/verify.sh`, the empty-volume and initialized-volume smoke tests, and `scripts/check-dbt-metabase-standalone.sh` before release. Verify the exact stored draft with `templateDeployV2`, because legacy template deployment can ignore Composer configuration.

```bash
railway templates publish TEMPLATE_ID \
  --category Analytics \
  --description "Scheduled dbt models with a ready-to-use Metabase dashboard." \
  --readme-file MARKETPLACE.md \
  --json
```
