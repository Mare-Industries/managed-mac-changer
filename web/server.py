#!/usr/bin/env python3
"""
managed-mac-changer web UI — MAC group management
Runs on http://localhost:7779
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import urllib.parse

DEFAULT_CONFIG = {
    "active_groups": ["default"],
    "excluded_groups": [],
    "groups": {
        "default": {
            "description": "Default MAC addresses",
            "macs": []
        }
    }
}

def load_config(config_dir):
    path = Path(config_dir) / "groups.json"
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        save_config(config_dir, DEFAULT_CONFIG)
        return DEFAULT_CONFIG
    with open(path) as f:
        return json.load(f)

def save_config(config_dir, cfg):
    path = Path(config_dir) / "groups.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)

def validate_mac(mac):
    return bool(re.match(r'^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$', mac))

def normalize_mac(mac):
    return mac.lower().strip()

def validate_group_name(name):
    return bool(re.match(r'^[a-zA-Z0-9_-]{1,32}$', name))

def api_response(handler, status, data):
    body = json.dumps(data).encode()
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", len(body))
    handler.end_headers()
    handler.wfile.write(body)

class Handler(BaseHTTPRequestHandler):
    config_dir = None

    def log_message(self, fmt, *args):
        pass  # suppress default access log

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/" or path == "/index.html":
            self._serve_ui()
        elif path == "/api/config":
            cfg = load_config(self.config_dir)
            api_response(self, 200, cfg)
        elif path == "/api/status":
            self._api_status()
        else:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        try:
            data = json.loads(body) if body else {}
        except json.JSONDecodeError:
            api_response(self, 400, {"error": "Invalid JSON"})
            return

        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/api/groups":
            self._create_group(data)
        elif path.startswith("/api/groups/") and path.endswith("/macs"):
            group = path.split("/")[3]
            if not validate_group_name(group):
                api_response(self, 400, {"error": "Invalid group name"}); return
            self._add_mac(group, data)
        elif path.startswith("/api/groups/") and path.endswith("/activate"):
            group = path.split("/")[3]
            if not validate_group_name(group):
                api_response(self, 400, {"error": "Invalid group name"}); return
            self._set_group_active(group, True)
        elif path.startswith("/api/groups/") and path.endswith("/deactivate"):
            group = path.split("/")[3]
            if not validate_group_name(group):
                api_response(self, 400, {"error": "Invalid group name"}); return
            self._set_group_active(group, False)
        elif path.startswith("/api/groups/") and path.endswith("/exclude"):
            group = path.split("/")[3]
            if not validate_group_name(group):
                api_response(self, 400, {"error": "Invalid group name"}); return
            self._set_group_excluded(group, True)
        elif path.startswith("/api/groups/") and path.endswith("/include"):
            group = path.split("/")[3]
            if not validate_group_name(group):
                api_response(self, 400, {"error": "Invalid group name"}); return
            self._set_group_excluded(group, False)
        else:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path
        parts = path.split("/")

        if path.startswith("/api/groups/") and len(parts) == 4:
            group = parts[3]
            if not validate_group_name(group):
                api_response(self, 400, {"error": "Invalid group name"}); return
            self._delete_group(group)
        elif path.startswith("/api/groups/") and len(parts) == 6 and parts[4] == "macs":
            group = parts[3]
            if not validate_group_name(group):
                api_response(self, 400, {"error": "Invalid group name"}); return
            mac = urllib.parse.unquote(parts[5])
            self._delete_mac(group, mac)
        else:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()

    # ── API handlers ──────────────────────────────────────────────────────────

    def _api_status(self):
        import subprocess
        status = {}
        try:
            status["hostname"] = subprocess.check_output(
                ["hostname"], text=True, timeout=5).strip()
        except (subprocess.SubprocessError, OSError):
            status["hostname"] = "unknown"
        try:
            result = subprocess.check_output(
                ["ip", "-o", "link", "show"], text=True, timeout=5)
            iface = None
            for line in result.splitlines():
                name = line.split(":")[1].strip().split("@")[0]
                if name.startswith("wl"):
                    iface = name
                    break
            if not iface:
                for line in result.splitlines():
                    name = line.split(":")[1].strip().split("@")[0]
                    if name != "lo":
                        iface = name
                        break
            status["interface"] = iface or "none"
            if iface:
                mac_out = subprocess.check_output(
                    ["ip", "link", "show", iface], text=True, timeout=5)
                for line in mac_out.splitlines():
                    if "ether" in line:
                        status["mac"] = line.split()[1]
                        break
        except (subprocess.SubprocessError, OSError, IndexError):
            status["interface"] = "unknown"
            status["mac"] = "unknown"
        api_response(self, 200, status)

    def _create_group(self, data):
        name = data.get("name", "").strip()
        description = data.get("description", "").strip()
        if not validate_group_name(name):
            api_response(self, 400, {"error": "Invalid group name (a-z, 0-9, -, _ only, max 32 chars)"})
            return
        cfg = load_config(self.config_dir)
        if name in cfg["groups"]:
            api_response(self, 409, {"error": f"Group '{name}' already exists"})
            return
        cfg["groups"][name] = {"description": description, "macs": []}
        save_config(self.config_dir, cfg)
        api_response(self, 201, {"ok": True, "group": name})

    def _delete_group(self, group):
        cfg = load_config(self.config_dir)
        if group not in cfg["groups"]:
            api_response(self, 404, {"error": f"Group '{group}' not found"})
            return
        del cfg["groups"][group]
        cfg["active_groups"] = [g for g in cfg["active_groups"] if g != group]
        cfg["excluded_groups"] = [g for g in cfg["excluded_groups"] if g != group]
        save_config(self.config_dir, cfg)
        api_response(self, 200, {"ok": True})

    def _add_mac(self, group, data):
        mac = normalize_mac(data.get("mac", ""))
        if not validate_mac(mac):
            api_response(self, 400, {"error": "Invalid MAC address format"})
            return
        cfg = load_config(self.config_dir)
        if group not in cfg["groups"]:
            api_response(self, 404, {"error": f"Group '{group}' not found"})
            return
        if mac in cfg["groups"][group]["macs"]:
            api_response(self, 409, {"error": "MAC already exists in this group"})
            return
        cfg["groups"][group]["macs"].append(mac)
        save_config(self.config_dir, cfg)
        api_response(self, 201, {"ok": True, "mac": mac})

    def _delete_mac(self, group, mac):
        mac = normalize_mac(mac)
        cfg = load_config(self.config_dir)
        if group not in cfg["groups"]:
            api_response(self, 404, {"error": f"Group '{group}' not found"})
            return
        macs = cfg["groups"][group]["macs"]
        if mac not in macs:
            api_response(self, 404, {"error": "MAC not found in group"})
            return
        cfg["groups"][group]["macs"].remove(mac)
        save_config(self.config_dir, cfg)
        api_response(self, 200, {"ok": True})

    def _set_group_active(self, group, active):
        cfg = load_config(self.config_dir)
        if group not in cfg["groups"]:
            api_response(self, 404, {"error": f"Group '{group}' not found"})
            return
        if active and group not in cfg["active_groups"]:
            cfg["active_groups"].append(group)
        elif not active and group in cfg["active_groups"]:
            cfg["active_groups"].remove(group)
        save_config(self.config_dir, cfg)
        api_response(self, 200, {"ok": True})

    def _set_group_excluded(self, group, excluded):
        cfg = load_config(self.config_dir)
        if group not in cfg["groups"]:
            api_response(self, 404, {"error": f"Group '{group}' not found"})
            return
        if excluded and group not in cfg["excluded_groups"]:
            cfg["excluded_groups"].append(group)
        elif not excluded and group in cfg["excluded_groups"]:
            cfg["excluded_groups"].remove(group)
        save_config(self.config_dir, cfg)
        api_response(self, 200, {"ok": True})

    def _serve_ui(self):
        ui_path = Path(__file__).parent / "templates" / "index.html"
        if not ui_path.exists():
            self.send_response(500)
            self.end_headers()
            self.wfile.write(b"UI template not found")
            return
        content = ui_path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", len(content))
        self.end_headers()
        self.wfile.write(content)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config-dir", default="/etc/managed-mac-changer")
    parser.add_argument("--port", type=int, default=7779)
    parser.add_argument("--host", default="127.0.0.1")
    args = parser.parse_args()

    if args.host != "127.0.0.1":
        print(f"WARNING: binding to {args.host} — web UI will be network-accessible.", flush=True)

    Handler.config_dir = args.config_dir

    print(f"managed-mac-changer web UI")
    print(f"  http://{args.host}:{args.port}")
    print(f"  Config: {args.config_dir}")
    print(f"  Press Ctrl+C to stop.")

    server = HTTPServer((args.host, args.port), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")

if __name__ == "__main__":
    main()
