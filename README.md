# dbt + Metabase Railway template

The current template release is `v1.0.1`. It deploys dbt Core `1.12.5`, dbt-postgres `1.11.0`, Metabase `0.63.19`, and two PostgreSQL `17.11` services. Runtime base images are pinned by digest.

Upstream projects: [dbt](https://www.getdbt.com) and [Metabase](https://www.metabase.com).

## Deploy on Railway

Set `METABASE_ADMIN_EMAIL` if the default is unsuitable. Railway generates the administrator password, both database passwords, and Metabase's credential-encryption key. The dbt service seeds three example orders, builds and tests `analytics.order_summary`, connects Metabase to the warehouse, and creates the `Orders by status` question and `Railway order overview` dashboard. Open the Metabase domain and sign in with the administrator values stored on that service.

The dbt pipeline reruns every 86,400 seconds. Change `DBT_RUN_INTERVAL_SECONDS` on the dbt service for another cadence, then replace the example seed and model in the source repository with your own project. A failed dbt build leaves the previous warehouse table intact and keeps the service unhealthy on its first boot.

## Environment variables

- `METABASE_POSTGRES_PASSWORD` authenticates Metabase to its metadata database, while `WAREHOUSE_POSTGRES_PASSWORD` authenticates dbt and Metabase to the analytics warehouse. Railway generates both; local Compose requires strong values in `.env`.
- `METABASE_ADMIN_PASSWORD` creates the first Metabase administrator and must pass Metabase's common-password check. Railway generates it; changing the variable after setup does not rotate the existing account password.
- `MB_ENCRYPTION_SECRET_KEY` encrypts database credentials stored by Metabase. Railway generates it; keep the same value for the life of an initialized metadata database.
- `METABASE_ADMIN_EMAIL` defaults to `admin@example.com`, and `DBT_RUN_INTERVAL_SECONDS` defaults to `86400`; set them before first boot when you need another administrator identity or schedule.

## Services and persistence

- Metabase is public on port 3000 and stores its users, questions, and dashboards in a private PostgreSQL service.
- dbt is private, exposes only a health endpoint, and runs the pipeline once on boot and once per configured interval.
- Warehouse PostgreSQL is private and holds source seeds plus transformed analytics tables.
- Both PostgreSQL services have separate 5 GB volumes, so back up both before upgrades.

Metabase's Java heap is bounded at 384 MB and bundled sample content is disabled. The final local cold-boot snapshot used about 904 MiB for Metabase, 18 MiB for dbt, 86 MiB for the metadata database, and 33 MiB for the warehouse. Provision at least 2 GiB for Metabase so cold starts and routine queries have operating headroom; raise the heap and service memory together before adding substantial dashboards, concurrency, or additional drivers.

## Local verification

Copy `.env.example` to `.env`, replace every required placeholder, and use a strong administrator password that Metabase's common-password check accepts. Then run:

```bash
docker compose up --build -d --wait
python3 scripts/smoke.py --url http://127.0.0.1:18081 --email admin@example.com --password '<password>'
```

The smoke test authenticates, verifies the warehouse, saved question, and dashboard, then executes a query and asserts that the model contains three orders. Review [SUPPORT.md](SUPPORT.md) before production use and [UPGRADE.md](UPGRADE.md) before changing pins.
