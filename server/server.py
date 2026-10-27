#!/usr/bin/env python3
"""Estación de deberes: archivos estáticos + MatheBase → puente cocina.

Basado en server.py de MatheBase v3 (Grok). Nombres, PIN y webhook viven SOLO
en el Chromebook (no en git):

  /etc/estacion/mathebase.json   {"pin": "1234", "kinder": [{"id": "...", "name": "..."}]}
  /etc/estacion/webhook.env      MATHEBASE_WEBHOOK_URL=...  MATHEBASE_WEBHOOK_KEY=...  (opcional)

Se crean con:  sudo estacion-config
Sin webhook.env el servidor solo guarda el registro local y no llama a nada.
"""
from __future__ import annotations

import hmac
import json
import os
import sys
import urllib.request
from datetime import date
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PORT = int(os.environ.get("ESTACION_PORT", "8765"))
ROOT = Path(os.environ.get("ESTACION_ROOT", ".")).resolve()
CONFIG_DIR = Path(os.environ.get("ESTACION_CONFIG", "/etc/estacion"))
STATE_DIR = Path(os.environ.get("ESTACION_STATE", "/var/lib/estacion"))

CFG_JSON = CONFIG_DIR / "mathebase.json"
CFG_WEBHOOK = CONFIG_DIR / "webhook.env"
INBOX = STATE_DIR / "mathe-inbox.jsonl"
MAX_BODY = 10_000


def load_config() -> dict:
    try:
        data = json.loads(CFG_JSON.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {"pin": "", "kinder": []}
    kinder = [
        {"id": str(k.get("id", "")).strip(), "name": str(k.get("name", "")).strip()}
        for k in data.get("kinder", [])
        if isinstance(k, dict) and str(k.get("id", "")).strip()
    ]
    return {"pin": str(data.get("pin", "")).strip(), "kinder": kinder}


def load_env(path: Path) -> dict:
    out = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return out
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def append_inbox(obj: dict) -> None:
    try:
        INBOX.parent.mkdir(parents=True, exist_ok=True)
        with INBOX.open("a", encoding="utf-8") as f:
            f.write(json.dumps(obj, ensure_ascii=False) + "\n")
    except OSError as e:
        sys.stderr.write(f"inbox write failed: {e}\n")


def forward_webhook(obj: dict) -> tuple[bool, str]:
    env = load_env(CFG_WEBHOOK)
    url, key = env.get("MATHEBASE_WEBHOOK_URL"), env.get("MATHEBASE_WEBHOOK_KEY")
    if not url or not key:
        return False, "no_webhook_config"
    req = urllib.request.Request(
        url,
        data=json.dumps(obj).encode("utf-8"),
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
            "X-Automation-Key": key,
            "User-Agent": "estacion-chicos-mathebase/1",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return True, f"http_{resp.status}"
    except Exception as e:  # noqa: BLE001 – el juego no debe romperse por la red
        append_inbox({**obj, "forward_error": str(e)})
        return False, "forward_failed"


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(ROOT), **k)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    # ---- helpers
    def _json(self, code: int, obj: dict) -> None:
        payload = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def _body(self) -> dict | None:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None
        if length < 0 or length > MAX_BODY:
            return None
        raw = self.rfile.read(length) if length else b"{}"
        try:
            body = json.loads(raw.decode("utf-8") or "{}")
        except (UnicodeDecodeError, ValueError):
            return None
        return body if isinstance(body, dict) else None

    def _route(self) -> str:
        return self.path.split("?")[0].rstrip("/")

    # ---- GET
    def do_GET(self):
        route = self._route()
        if route == "/api/config":
            cfg = load_config()
            return self._json(200, {"kinder": cfg["kinder"]})  # nunca el PIN
        if route in ("/api/mathe/export", "/mathebase/api/mathe/export"):
            ids = {k["id"] for k in load_config()["kinder"]}
            stats: dict = {}
            try:
                lines = INBOX.read_text(encoding="utf-8").splitlines()
            except OSError:
                lines = []
            for line in lines:
                try:
                    ev = json.loads(line)
                except ValueError:
                    continue
                if ev.get("action") != "mathe_done" or ev.get("kind") not in ids:
                    continue
                k = stats.setdefault(ev["kind"], {"days": set(), "forward_errors": 0})
                k["days"].add(ev.get("date"))
                if ev.get("forward_error"):
                    k["forward_errors"] += 1
            out = {
                kind: {
                    "mathe_days": sorted(d for d in v["days"] if d),
                    "count": len(v["days"]),
                    "forward_errors": v["forward_errors"],
                }
                for kind, v in stats.items()
            }
            return self._json(200, {"ok": True, "kinds": out})
        return super().do_GET()

    # ---- POST
    def do_POST(self):
        route = self._route()
        body = self._body()
        if body is None:
            return self._json(400, {"ok": False, "reason": "bad_request"})

        if route == "/api/pin":
            pin = load_config()["pin"]
            if not pin:
                return self._json(200, {"ok": False, "reason": "no_pin"})
            ok = hmac.compare_digest(str(body.get("pin", "")), pin)
            return self._json(200, {"ok": ok})

        if route in ("/api/mathe/kueche", "/mathebase/api/mathe/kueche"):
            if body.get("action") == "ping":  # v4: Test Küche, setzt kein Häkchen
                ev = {"action": "ping", "source": "mathebase",
                      "date": str(body.get("date") or date.today().isoformat())[:10]}
                ok, detail = forward_webhook(ev)
                return self._json(200, {"ok": True, "forwarded": ok, "detail": detail})
            ids = {k["id"] for k in load_config()["kinder"]}
            kind = body.get("kind")
            if kind not in ids:
                return self._json(400, {"ok": False, "reason": "unknown_kind"})
            event = {
                "action": "mathe_done",
                "kind": kind,
                "date": str(body.get("date") or date.today().isoformat())[:10],
                "habit": str(body.get("habit") or "lesen_oder_sport")[:40],
                "source": "mathebase",
                "correct": body.get("correct"),
                "total": body.get("total"),
                "profile": str(body.get("profile") or "")[:40],
            }
            append_inbox(event)
            ok, detail = forward_webhook(event)
            return self._json(200, {"ok": True, "queued": True, "forwarded": ok, "detail": detail})

        return self._json(404, {"ok": False, "reason": "not_found"})


def main():
    httpd = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"estacion listening http://127.0.0.1:{PORT}/  root={ROOT}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
