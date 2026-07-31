# Upgrade runbook

Back up both PostgreSQL databases and test the restore before changing Metabase, dbt, an adapter, Python, or PostgreSQL. Upgrade one layer at a time so a migration failure has an unambiguous cause.

For Metabase, read every intermediate release note and let the application database migration finish before testing login, the saved question, and the dashboard query. Never downgrade Metabase against a database migrated by a newer release.

For dbt, update `dbt-core` and `dbt-postgres` together, rebuild from an empty cache, run `dbt seed` and `dbt build`, and inspect manifest changes before moving the `release-v1` source branch. Change PostgreSQL major versions only through a tested dump and restore.
