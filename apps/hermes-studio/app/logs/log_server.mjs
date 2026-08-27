import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import zlib from "node:zlib";
import { execFileSync } from "node:child_process";

const logDir = path.resolve(process.env.HERMES_LOG_DIR || ".");
const appName = process.env.HERMES_LOG_APP_NAME || "Hermes Studio";
const host = process.env.HERMES_LOG_VIEWER_BIND || "0.0.0.0";
const port = Number(process.env.HERMES_LOG_VIEWER_PORT || 8649);

function files() {
  fs.mkdirSync(logDir, { recursive: true });
  return fs.readdirSync(logDir).filter((name) => name.endsWith(".log") || name.endsWith(".txt"))
    .map((name) => {
      const stat = fs.statSync(path.join(logDir, name));
      return { name, size: stat.size, updated_at: stat.mtime.toISOString() };
    }).sort((a, b) => a.name.localeCompare(b.name));
}

function safePath(name) {
  if (!name || path.basename(name) !== name || !/\.(log|txt)$/.test(name)) return null;
  const file = path.join(logDir, name);
  return fs.existsSync(file) && fs.statSync(file).isFile() ? file : null;
}

function tail(file, lines = 500) {
  const content = fs.readFileSync(file, "utf8").split(/(?<=\n)/);
  return content.slice(-Math.max(1, Math.min(Number(lines) || 500, 5000))).join("");
}

function send(res, status, type, body, headers = {}) {
  const data = Buffer.isBuffer(body) ? body : Buffer.from(body);
  res.writeHead(status, { "Content-Type": type, "Content-Length": data.length, ...headers });
  res.end(data);
}

function html() {
  return `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${appName} 日志</title><style>body{font-family:system-ui,sans-serif;margin:24px;background:#f6f7f9;color:#1f2937}main{max-width:1200px;margin:auto;background:#fff;padding:20px;border-radius:12px;box-shadow:0 2px 12px #0001}header{display:flex;gap:12px;align-items:center;flex-wrap:wrap}button,select{padding:8px 12px;border:1px solid #d1d5db;border-radius:7px;background:#fff}pre{white-space:pre-wrap;word-break:break-word;background:#111827;color:#d1fae5;padding:16px;border-radius:8px;min-height:480px;overflow:auto}small{color:#6b7280}</style></head><body><main><header><h2>${appName} 日志</h2><select id="file"></select><button onclick="loadLog()">刷新</button><button onclick="location.href='/api/bundle'">导出全部日志</button></header><small>仅显示最近 500 行；需要完整排查时请点击“导出全部日志”。</small><pre id="log">正在加载……</pre></main><script>const s=document.getElementById('file'),o=document.getElementById('log');async function list(){const d=await(await fetch('/api/files')).json();s.innerHTML=d.files.map(x=>'<option value="'+x.name+'">'+x.name+'</option>').join('');if(d.files.length)loadLog();else o.textContent='暂无日志。'}async function loadLog(){if(!s.value)return;o.textContent='正在加载……';const d=await(await fetch('/api/log?file='+encodeURIComponent(s.value)+'&lines=500')).json();o.textContent=d.content||d.error||'暂无内容'}s.onchange=loadLog;list();setInterval(list,30000);</script></body></html>`;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  if (url.pathname === "/") return send(res, 200, "text/html; charset=utf-8", html());
  if (url.pathname === "/api/files") return send(res, 200, "application/json; charset=utf-8", JSON.stringify({ app: appName, files: files() }));
  if (url.pathname === "/api/log") {
    const file = url.searchParams.get("file");
    const target = safePath(file);
    if (!target) return send(res, 404, "application/json; charset=utf-8", JSON.stringify({ error: "日志文件不存在" }));
    return send(res, 200, "application/json; charset=utf-8", JSON.stringify({ file, content: tail(target, url.searchParams.get("lines")) }));
  }
  if (url.pathname === "/api/bundle") {
    const names = files().map((item) => item.name);
    const payload = names.length ? execFileSync("tar", ["-czf", "-", "-C", logDir, ...names]) : zlib.gzipSync(Buffer.from("暂无日志\n"));
    return send(res, 200, "application/gzip", payload, { "Content-Disposition": `attachment; filename="hermes-studio-logs-${Date.now()}.tar.gz"` });
  }
  send(res, 404, "text/plain; charset=utf-8", "Not Found");
});

server.listen(port, host);
