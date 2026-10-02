# Changelog

## [1.0.1] - 2026-10-02

- Upgrade dbt Core to 1.12.5, retaining dbt-postgres 1.11.0.
- Refresh the standard Metabase image to 0.63.19 and both PostgreSQL images to 17.11 with immutable registry digests.
- Refresh Python to 3.12.15 on Debian Bookworm and verify the current release and image pins.

## [1.0.0] - 2026-07-31

- Add dbt Core 1.12.0 with PostgreSQL models and daily scheduling.
- Add Metabase 0.63.2 with an isolated application database and ready-to-use dashboard.
- Pin all runtime images and verify empty-volume boot, queries, and initialized restart.
