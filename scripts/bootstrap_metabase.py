#!/usr/bin/env python3
"""Idempotently configure Metabase around the template's dbt warehouse."""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request


BASE_URL = os.environ["METABASE_URL"].rstrip("/")
TIMEOUT_SECONDS = 600


def request(method: str, path: str, payload=None, session: str | None = None):
    data = None if payload is None else json.dumps(payload).encode()
    headers = {"Content-Type": "application/json"}
    if session:
        headers["X-Metabase-Session"] = session
    req = urllib.request.Request(
        f"{BASE_URL}{path}", data=data, method=method, headers=headers
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            body = response.read()
            return response.status, json.loads(body) if body else None
    except urllib.error.HTTPError as error:
        body = error.read()
        try:
            parsed = json.loads(body) if body else None
        except json.JSONDecodeError:
            parsed = body.decode(errors="replace")
        return error.code, parsed
    except urllib.error.URLError:
        return 0, None


def wait_for_metabase() -> dict:
    deadline = time.monotonic() + TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        status, _ = request("GET", "/api/health")
        if status == 200:
            status, properties = request("GET", "/api/session/properties")
            if status == 200:
                return properties
        time.sleep(3)
    raise RuntimeError("Metabase did not become ready before bootstrap timeout")


def setup(properties: dict) -> None:
    token = properties.get("setup-token")
    if not token:
        return
    status, body = request(
        "POST",
        "/api/setup",
        {
            "token": token,
            "user": {
                "email": os.environ["METABASE_ADMIN_EMAIL"],
                "first_name": "Railway",
                "last_name": "Admin",
                "password": os.environ["METABASE_ADMIN_PASSWORD"],
                "site_name": "Railway analytics",
            },
            "prefs": {
                "site_name": "Railway analytics",
                "site_locale": "en",
                "allow_tracking": False,
            },
            "database": {
                "engine": "postgres",
                "name": "Analytics warehouse",
                "details": {
                    "host": os.environ["WAREHOUSE_HOST"],
                    "port": int(os.environ.get("WAREHOUSE_PORT", "5432")),
                    "dbname": os.environ["WAREHOUSE_DATABASE"],
                    "user": os.environ["WAREHOUSE_USER"],
                    "password": os.environ["WAREHOUSE_PASSWORD"],
                    "ssl": False,
                },
            },
        },
    )
    if status != 200:
        raise RuntimeError(f"Metabase setup failed: HTTP {status}: {body}")


def login() -> str:
    status, body = request(
        "POST",
        "/api/session",
        {
            "username": os.environ["METABASE_ADMIN_EMAIL"],
            "password": os.environ["METABASE_ADMIN_PASSWORD"],
        },
    )
    if status != 200:
        raise RuntimeError(f"Metabase login failed: HTTP {status}: {body}")
    return body["id"]


def ensure_content(session: str) -> None:
    status, databases = request("GET", "/api/database", session=session)
    if status != 200:
        raise RuntimeError(f"Unable to list Metabase databases: {databases}")
    database = next(
        (item for item in databases["data"] if item["name"] == "Analytics warehouse"),
        None,
    )
    if database is None:
        status, database = request(
            "POST",
            "/api/database",
            {
                "engine": "postgres",
                "name": "Analytics warehouse",
                "details": {
                    "host": os.environ["WAREHOUSE_HOST"],
                    "port": int(os.environ.get("WAREHOUSE_PORT", "5432")),
                    "dbname": os.environ["WAREHOUSE_DATABASE"],
                    "user": os.environ["WAREHOUSE_USER"],
                    "password": os.environ["WAREHOUSE_PASSWORD"],
                    "ssl": False,
                },
                "is_on_demand": False,
                "is_full_sync": True,
                "schedules": {},
            },
            session,
        )
        if status != 200:
            raise RuntimeError(
                f"Unable to create the Analytics warehouse connection: {database}"
            )
    database_id = database["id"]
    request("POST", f"/api/database/{database_id}/sync_schema", {}, session)

    status, cards = request("GET", "/api/card", session=session)
    if status != 200:
        raise RuntimeError(f"Unable to list Metabase questions: {cards}")
    card = next((item for item in cards if item["name"] == "Orders by status"), None)
    if card is None:
        status, card = request(
            "POST",
            "/api/card",
            {
                "name": "Orders by status",
                "display": "table",
                "visualization_settings": {},
                "dataset_query": {
                    "type": "native",
                    "database": database_id,
                    "native": {
                        "query": "select status, order_count, total_order_value from analytics.order_summary order by status",
                        "template-tags": {},
                    },
                },
            },
            session,
        )
        if status != 200:
            raise RuntimeError(f"Unable to create Metabase question: {card}")

    status, dashboards = request("GET", "/api/dashboard", session=session)
    if status != 200:
        raise RuntimeError(f"Unable to list Metabase dashboards: {dashboards}")
    dashboard = next(
        (item for item in dashboards if item["name"] == "Railway order overview"),
        None,
    )
    if dashboard is None:
        status, dashboard = request(
            "POST",
            "/api/dashboard",
            {
                "name": "Railway order overview",
                "description": "A ready-to-query dashboard created by the Railway template.",
            },
            session,
        )
        if status != 200:
            raise RuntimeError(f"Unable to create Metabase dashboard: {dashboard}")
    status, dashboard_detail = request(
        "GET", f"/api/dashboard/{dashboard['id']}", session=session
    )
    if status != 200:
        raise RuntimeError(f"Unable to read Metabase dashboard: {dashboard_detail}")
    if not any(
        item.get("card_id") == card["id"]
        for item in dashboard_detail.get("dashcards", [])
    ):
        status, body = request(
            "PUT",
            f"/api/dashboard/{dashboard['id']}",
            {
                "dashcards": [
                    *dashboard_detail.get("dashcards", []),
                    {
                        "id": -1,
                        "card_id": card["id"],
                        "row": 0,
                        "col": 0,
                        "size_x": 12,
                        "size_y": 8,
                        "parameter_mappings": [],
                        "series": [],
                    },
                ],
                "tabs": dashboard_detail.get("tabs", []),
            },
            session,
        )
        if status != 200:
            raise RuntimeError(f"Unable to add the question to dashboard: {body}")

    status, result = request(
        "POST",
        "/api/dataset",
        {
            "database": database_id,
            "type": "native",
            "native": {
                "query": "select sum(order_count) as orders from analytics.order_summary",
                "template-tags": {},
            },
        },
        session,
    )
    rows = result.get("data", {}).get("rows", []) if isinstance(result, dict) else []
    if status != 202 or rows != [[3]]:
        raise RuntimeError(f"Metabase warehouse query failed: HTTP {status}: {result}")


def main() -> None:
    setup(wait_for_metabase())
    session = login()
    ensure_content(session)
    print("Metabase bootstrap complete: warehouse, question, dashboard, and query passed")


if __name__ == "__main__":
    main()
