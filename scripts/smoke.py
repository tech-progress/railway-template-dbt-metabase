#!/usr/bin/env python3
"""Verify the ready-to-use Metabase content through its public API."""

from __future__ import annotations

import argparse
import json
import urllib.error
import urllib.request


def call(base_url: str, method: str, path: str, payload=None, session=None):
    data = None if payload is None else json.dumps(payload).encode()
    headers = {"Content-Type": "application/json"}
    if session:
        headers["X-Metabase-Session"] = session
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}{path}", data=data, method=method, headers=headers
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            body = response.read()
            return response.status, json.loads(body) if body else None
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode(errors="replace")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--email", required=True)
    parser.add_argument("--password", required=True)
    args = parser.parse_args()

    status, body = call(
        args.url,
        "POST",
        "/api/session",
        {"username": args.email, "password": args.password},
    )
    if status != 200:
        raise RuntimeError(f"Administrator login failed: HTTP {status}: {body}")
    session = body["id"]

    status, databases = call(args.url, "GET", "/api/database", session=session)
    database = next(
        (
            item
            for item in databases.get("data", [])
            if item["name"] == "Analytics warehouse"
        ),
        None,
    )
    if status != 200 or database is None:
        raise RuntimeError("Analytics warehouse connection is missing")

    status, cards = call(args.url, "GET", "/api/card", session=session)
    card = (
        next((item for item in cards if item["name"] == "Orders by status"), None)
        if status == 200
        else None
    )
    if card is None:
        raise RuntimeError("Orders by status question is missing")
    status, dashboards = call(args.url, "GET", "/api/dashboard", session=session)
    dashboard = (
        next(
            (
                item
                for item in dashboards
                if item["name"] == "Railway order overview"
            ),
            None,
        )
        if status == 200
        else None
    )
    if dashboard is None:
        raise RuntimeError("Railway order overview dashboard is missing")
    status, dashboard_detail = call(
        args.url,
        "GET",
        f"/api/dashboard/{dashboard['id']}",
        session=session,
    )
    if status != 200 or not any(
        dashcard.get("card_id") == card["id"]
        for dashcard in dashboard_detail.get("dashcards", [])
    ):
        raise RuntimeError("Orders by status question is not attached to the dashboard")

    status, result = call(
        args.url,
        "POST",
        "/api/dataset",
        {
            "database": database["id"],
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
        raise RuntimeError(f"Warehouse query failed: HTTP {status}: {result}")
    print("Metabase smoke test passed: admin, warehouse, question, dashboard, and 3 orders")


if __name__ == "__main__":
    main()
