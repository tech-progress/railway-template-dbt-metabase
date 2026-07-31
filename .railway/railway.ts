import {
  defineRailway,
  github,
  group,
  project,
  service,
  volume,
} from "railway/iac";

const SOURCE = github("tech-progress/railway-template-dbt-metabase", {
  branch: "release-v1",
  rootDirectory: "/",
});
const POSTGRES_IMAGE =
  "postgres:17.6-alpine@sha256:ef257d85f76e48da1c64832459b59fcaba1a4dac97bf5d7450c77753542eee94";
const METABASE_IMAGE =
  "metabase/metabase:v0.63.2@sha256:252f8c9bd56dd21158005675b55876cf9fb838e0a0e0541581af859eafe1f32e";

export default defineRailway(() => {
  const metadataData = volume("Metabase PostgreSQL Data", { sizeMB: 5_000 });
  const warehouseData = volume("Warehouse PostgreSQL Data", { sizeMB: 5_000 });

  const metadataDatabase = service("Metabase PostgreSQL", {
    source: { image: POSTGRES_IMAGE },
    volumeMounts: { "/var/lib/postgresql/data": metadataData },
    env: {
      PGDATA: "/var/lib/postgresql/data/pgdata",
      POSTGRES_DB: "metabase",
      POSTGRES_USER: "metabase",
      POSTGRES_PASSWORD: "${{secret(48)}}",
    },
  });

  const warehouse = service("Warehouse PostgreSQL", {
    source: { image: POSTGRES_IMAGE },
    volumeMounts: { "/var/lib/postgresql/data": warehouseData },
    env: {
      PGDATA: "/var/lib/postgresql/data/pgdata",
      POSTGRES_DB: "warehouse",
      POSTGRES_USER: "analytics",
      POSTGRES_PASSWORD: "${{secret(48)}}",
    },
  });

  const metabase = service("Metabase", {
    source: { image: METABASE_IMAGE },
    healthcheck: "/api/health",
    healthcheckTimeout: 600,
    env: {
      PORT: "3000",
      MB_JETTY_PORT: "3000",
      MB_DB_TYPE: "postgres",
      MB_DB_HOST: "${{Metabase PostgreSQL.RAILWAY_PRIVATE_DOMAIN}}",
      MB_DB_PORT: "5432",
      MB_DB_DBNAME: "${{Metabase PostgreSQL.POSTGRES_DB}}",
      MB_DB_USER: "${{Metabase PostgreSQL.POSTGRES_USER}}",
      MB_DB_PASS: "${{Metabase PostgreSQL.POSTGRES_PASSWORD}}",
      MB_ENCRYPTION_SECRET_KEY: "${{secret(48)}}",
      MB_ANON_TRACKING_ENABLED: "false",
      MB_LOAD_SAMPLE_CONTENT: "false",
      JAVA_OPTS: "-Xms128m -Xmx384m",
      METABASE_ADMIN_EMAIL: "admin@example.com",
      METABASE_ADMIN_PASSWORD: "${{secret(32)}}",
    },
  });

  const dbt = service("dbt", {
    source: SOURCE,
    build: { builder: "DOCKERFILE", dockerfilePath: "Dockerfile" },
    healthcheck: "/health",
    healthcheckTimeout: 600,
    env: {
      PORT: "8080",
      WAREHOUSE_HOST: "${{Warehouse PostgreSQL.RAILWAY_PRIVATE_DOMAIN}}",
      WAREHOUSE_PORT: "5432",
      WAREHOUSE_DATABASE: "${{Warehouse PostgreSQL.POSTGRES_DB}}",
      WAREHOUSE_USER: "${{Warehouse PostgreSQL.POSTGRES_USER}}",
      WAREHOUSE_PASSWORD: "${{Warehouse PostgreSQL.POSTGRES_PASSWORD}}",
      METABASE_URL: "http://${{Metabase.RAILWAY_PRIVATE_DOMAIN}}:3000",
      METABASE_ADMIN_EMAIL: "${{Metabase.METABASE_ADMIN_EMAIL}}",
      METABASE_ADMIN_PASSWORD: "${{Metabase.METABASE_ADMIN_PASSWORD}}",
      DBT_RUN_INTERVAL_SECONDS: "86400",
    },
  });

  return project("dbt + Metabase analytics", {
    resources: [
      group("Analytics", [metabase, dbt]),
      group("Data", [metadataDatabase, metadataData, warehouse, warehouseData]),
    ],
  });
});
