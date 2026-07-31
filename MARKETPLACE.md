# Deploy and Host dbt + Metabase on Railway

Deploy scheduled dbt transformations, a ready-to-use Metabase dashboard, and separate PostgreSQL databases for Metabase state and warehouse data. The first boot seeds and tests an example model, connects Metabase to the warehouse, and creates a working question and dashboard.

## About Hosting dbt + Metabase

dbt turns warehouse SQL into tested, repeatable data models, while Metabase provides browser-based exploration and dashboards. This template runs dbt daily, keeps both databases private, and exposes only Metabase through Railway's public networking.

## Why Deploy dbt + Metabase on Railway

Railway supplies private service discovery, generated credentials, TLS, and persistent 5 GB database volumes. The bootstrap is idempotent, so initialized restarts preserve the administrator, warehouse connection, question, and dashboard.

## Common Use Cases

- Start a small internal analytics stack with tested SQL models and dashboards.
- Prototype a dbt project before connecting a production warehouse.
- Schedule lightweight transformations without operating a separate orchestrator.
- Give a team a private BI workspace backed by PostgreSQL.

## Dependencies for dbt + Metabase

Provision at least 2 GiB for Metabase, then replace the example dbt seed and model with your own project. Keep one dbt replica because every replica runs the same scheduled transformation.

### Deployment Dependencies

- dbt Core `1.12.0` with dbt-postgres `1.11.0`
- Metabase `0.63.2`
- Two PostgreSQL `17.6` services with persistent volumes
