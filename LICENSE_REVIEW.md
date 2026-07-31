# License review

dbt Core is Apache-2.0, dbt-postgres is Apache-2.0, PostgreSQL uses the PostgreSQL License, and the Metabase Open Source edition is AGPL-3.0. The template references official binaries and images without copying their source into this repository.

Metabase's repository also contains commercially licensed code, but the public `metabase/metabase` image used here is the Open Source edition and no enterprise token or commercial feature is configured. The custom dbt source contains only this template's project and bootstrap code.
