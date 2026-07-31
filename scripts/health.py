#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import os
from pathlib import Path


READY_FILE = Path("/tmp/dbt-metabase-ready")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/health":
            self.send_response(404)
            self.end_headers()
            return
        if not READY_FILE.exists():
            self.send_response(503)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status":"ok"}')

    def log_message(self, *_args):
        return


HTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), Handler).serve_forever()
