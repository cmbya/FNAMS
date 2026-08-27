#!/usr/bin/env python3
"""Small dependency-free LAN log viewer for the fnOS package."""

import io
import json
import os
import posixpath
import tarfile
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


LOG_DIR = os.path.abspath(os.environ.get("HERMES_LOG_DIR", "."))
APP_NAME = os.environ.get("HERMES_LOG_APP_NAME", "Hermes")
HOST = os.environ.get("HERMES_LOG_VIEWER_BIND", "0.0.0.0")
PORT = int(os.environ.get("HERMES_LOG_VIEWER_PORT", "8643"))
MAX_LINES = 5000


def allowed_file(name: str) -> str | None:
    clean = posixpath.basename(name)
    if clean != name or not clean.endswith((".log", ".txt")):
        return None
    path = os.path.join(LOG_DIR, clean)
    if not os.path.isfile(path):
        return None
    return path


def log_files() -> list[dict]:
    os.makedirs(LOG_DIR, exist_ok=True)
    result = []
    for name in sorted(os.listdir(LOG_DIR)):
        path = allowed_file(name)
        if path is None:
            continue
        stat = os.stat(path)
        result.append({
            "name": name,
            "size": stat.st_size,
            "updated_at": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
        })
    return result


def tail_file(path: str, lines: int) -> str:
    lines = max(1, min(lines, MAX_LINES))
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        data = handle.readlines()
    return "".join(data[-lines:])


class Handler(BaseHTTPRequestHandler):
    server_version = "HermesLogViewer/1.0"

    def log_message(self, fmt, *args):
        # The parent lifecycle redirects stderr to log-viewer.log.
        super().log_message(fmt, *args)

    def send_json(self, payload, status=200):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        if parsed.path == "/api/files":
            return self.send_json({"app": APP_NAME, "files": log_files()})
        if parsed.path == "/api/log":
            name = query.get("file", [""])[0]
            path = allowed_file(name)
            if path is None:
                return self.send_json({"error": "日志文件不存在"}, 404)
            try:
                lines = int(query.get("lines", ["500"])[0])
            except ValueError:
                lines = 500
            return self.send_json({"file": name, "content": tail_file(path, lines)})
        if parsed.path == "/api/bundle":
            return self.send_bundle()
        if parsed.path == "/" or parsed.path == "/index.html":
            return self.send_html()
        self.send_error(404)

    def send_bundle(self):
        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode="w:gz") as archive:
            for item in log_files():
                archive.add(os.path.join(LOG_DIR, item["name"]), arcname=item["name"], recursive=False)
        body = buffer.getvalue()
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        self.send_response(200)
        self.send_header("Content-Type", "application/gzip")
        self.send_header("Content-Disposition", f'attachment; filename="hermes-logs-{stamp}.tar.gz"')
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_html(self):
        body = f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{APP_NAME} 日志</title>
<style>body{{font-family:system-ui,sans-serif;margin:24px;background:#f6f7f9;color:#1f2937}}main{{max-width:1200px;margin:auto;background:white;padding:20px;border-radius:12px;box-shadow:0 2px 12px #0001}}header{{display:flex;gap:12px;align-items:center;flex-wrap:wrap}}button,select{{padding:8px 12px;border:1px solid #d1d5db;border-radius:7px;background:white}}pre{{white-space:pre-wrap;word-break:break-word;background:#111827;color:#d1fae5;padding:16px;border-radius:8px;min-height:480px;overflow:auto}}small{{color:#6b7280}}</style></head>
<body><main><header><h2>{APP_NAME} 日志</h2><select id="file"></select><button onclick="loadLog()">刷新</button><button onclick="location.href='/api/bundle'">导出全部日志</button></header>
<small>仅显示最近 500 行；需要完整排查时请点击“导出全部日志”。</small><pre id="log">正在加载……</pre></main>
<script>
const select=document.getElementById('file'), out=document.getElementById('log');
async function files(){{const r=await fetch('/api/files');const d=await r.json();select.innerHTML=d.files.map(x=>`<option value="${{x.name}}">${{x.name}}</option>`).join('');if(d.files.length)loadLog();else out.textContent='暂无日志。';}}
async function loadLog(){{if(!select.value)return;out.textContent='正在加载……';const r=await fetch('/api/log?file='+encodeURIComponent(select.value)+'&lines=500');const d=await r.json();out.textContent=d.content||d.error||'暂无内容';}}
select.addEventListener('change',loadLog);files();setInterval(files,30000);
</script></body></html>""".encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    os.makedirs(LOG_DIR, exist_ok=True)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
