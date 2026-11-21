'use strict';
// Server relay WebSocket untuk SPEEDCUBER'S CLOCK (Remote Timer Display).
// Server hanya meneruskan status timer dari Host ke Remote. Tidak ada database,
// tidak ada secret/API key; token room dibuat acak oleh server saat room dibuat.
const http = require('http');
const { WebSocketServer } = require('ws');
const { Relay } = require('./relay');

const PORT = parseInt(process.env.PORT || '8080', 10);
const TRUST_PROXY = process.env.TRUST_PROXY !== '0'; // di belakang proxy (Render, Caddy, dll)
const relay = new Relay({ maxRemotes: parseInt(process.env.MAX_REMOTES || '5', 10) });

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, ...relay.stats() }));
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end("SPEEDCUBER'S CLOCK relay server\n");
});

const wss = new WebSocketServer({ server, maxPayload: 4096, perMessageDeflate: false });

wss.on('connection', (ws, req) => {
  const xff = TRUST_PROXY ? String(req.headers['x-forwarded-for'] || '').split(',')[0].trim() : '';
  ws.ip = xff || req.socket.remoteAddress || '?';
  ws.room = null;
  ws.role = null;
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });
  ws.on('message', (data, isBinary) => {
    if (isBinary) return;
    let msg;
    try { msg = JSON.parse(data.toString()); } catch (e) { return; }
    relay.onMessage(ws, msg);
  });
  ws.on('close', () => relay.onClose(ws));
  ws.on('error', () => { /* close handler akan membereskan */ });
});

// Putus koneksi yang mati (jaringan HP sering putus tanpa pamit).
const heartbeat = setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    try { ws.ping(); } catch (e) { /* abaikan */ }
  }
}, 20000);
const sweeper = setInterval(() => relay.sweep(), 30000);

server.listen(PORT, '0.0.0.0', () => console.log('Relay berjalan di port ' + PORT));

function shutdown() {
  clearInterval(heartbeat);
  clearInterval(sweeper);
  for (const ws of wss.clients) ws.close(1001, 'server restart');
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 3000).unref();
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
