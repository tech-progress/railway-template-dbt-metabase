# Support boundary

This template is a single-region baseline for evaluation and small internal analytics teams. It runs one Metabase replica and one dbt scheduler; it does not provide high availability, an orchestrator, alerting, SMTP, SSO, or warehouse replicas.

Metabase runs with a 384 MB Java heap and settled near 904 MiB locally, so provision at least 2 GiB rather than relying on a 1 GiB limit with almost no cold-start headroom. Increase the service memory and `JAVA_OPTS` together before adding meaningful concurrency or large result sets. Keep one dbt replica, because multiple replicas would run the same scheduled transformation concurrently.

Back up both PostgreSQL volumes together. The metadata database owns Metabase users and content, while the warehouse owns dbt sources and models; restoring only one can leave a valid login pointing at missing analytics data or vice versa.
