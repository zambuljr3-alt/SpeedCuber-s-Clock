'use strict';
// Logika room Host <-> Remote. Tidak bergantung pada library WebSocket
// (socket hanya perlu punya send(string) dan close(code, reason)), jadi bisa dites tanpa jaringan.
const crypto = require('crypto');

const DEFAULTS = {
  maxRemotes: 5,
  maxRooms: 5000,
  hostGraceMs: 10 * 60 * 1000,
  roomMaxAgeMs: 12 * 60 * 60 * 1000,
  joinFailLimit: 8,
  joinFailWindowMs: 60 * 1000,
  msgPerSec: 40,
};

class Relay {
  constructor(opts = {}) {
    this.o = Object.assign({}, DEFAULTS, opts);
    this.now = this.o.now || (() => Date.now());
    this.rooms = new Map();
    this.joinFails = new Map();
  }

  // ---------- util
  _send(sock, obj) {
    try { sock.send(JSON.stringify(obj)); } catch (e) { /* socket sudah mati */ }
  }
  _err(sock, msg, fatal = true) {
    this._send(sock, { t: 'error', msg, fatal });
  }
  _newCode() {
    for (let i = 0; i < 30; i++) {
      const c = String(crypto.randomInt(100000, 1000000));
      if (!this.rooms.has(c)) return c;
    }
    return null;
  }
  _tokenOk(a, b) {
    const x = Buffer.from(String(a));
    const y = Buffer.from(String(b));
    return x.length === y.length && crypto.timingSafeEqual(x, y);
  }
  _blocked(ip) {
    const e = this.joinFails.get(ip);
    return !!e && this.now() < e.reset && e.n >= this.o.joinFailLimit;
  }
  _fail(ip) {
    const t = this.now();
    const e = this.joinFails.get(ip);
    if (!e || t >= e.reset) this.joinFails.set(ip, { n: 1, reset: t + this.o.joinFailWindowMs });
    else e.n += 1;
  }
  _presence(room) {
    const m = { t: 'presence', host: !!room.host, remotes: room.remotes.size };
    if (room.host) this._send(room.host, m);
    for (const r of room.remotes) this._send(r, m);
  }
  allow(sock) {
    const t = this.now();
    const w = sock._win || (sock._win = { t, n: 0 });
    if (t - w.t >= 1000) { w.t = t; w.n = 0; }
    w.n += 1;
    if (w.n > this.o.msgPerSec * 5) { try { sock.close(1008, 'flood'); } catch (e) { /* abaikan */ } }
    return w.n <= this.o.msgPerSec;
  }
  _clean(s) {
    if (!s || typeof s !== 'object') return null;
    const str = (v, n) => (typeof v === 'string' ? v.slice(0, n) : '');
    const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : 0);
    return {
      p: str(s.p, 6),
      txt: str(s.txt, 16),
      tag: str(s.tag, 16),
      pb: str(s.pb, 16),
      m: Math.max(0, Math.min(2, Math.trunc(num(s.m)))),
      lim: Math.max(0, Math.min(3600, Math.trunc(num(s.lim)))),
      ins: Math.trunc(num(s.ins)),
      st: Math.trunc(num(s.st)),
    };
  }

  // ---------- entry points
  onMessage(sock, msg) {
    if (!this.allow(sock)) return;
    if (!msg || typeof msg.t !== 'string') return;
    switch (msg.t) {
      case 'ping':
        if (typeof msg.c === 'number') this._send(sock, { t: 'pong', c: msg.c, s: this.now() });
        break;
      case 'create': this._create(sock); break;
      case 'resume': this._resume(sock, msg); break;
      case 'join': this._join(sock, msg); break;
      case 'state': this._state(sock, msg); break;
      case 'leave': this.onClose(sock); break;
      default: break;
    }
  }

  onClose(sock) {
    const room = sock.room ? this.rooms.get(sock.room) : null;
    const role = sock.role;
    sock.room = null;
    sock.role = null;
    if (!room) return;
    if (role === 'host' && room.host === sock) {
      room.host = null;
      room.hostLeft = this.now();
      this._presence(room);
    } else if (role === 'remote') {
      room.remotes.delete(sock);
      this._presence(room);
    }
  }

  // ---------- handlers
  _create(sock) {
    this.onClose(sock);
    if (this.rooms.size >= this.o.maxRooms) return this._err(sock, 'Server sedang penuh. Coba lagi nanti.');
    const code = this._newCode();
    if (!code) return this._err(sock, 'Gagal membuat kode room. Coba lagi.');
    const room = {
      code,
      token: crypto.randomBytes(16).toString('hex'),
      host: sock,
      remotes: new Set(),
      state: null,
      lastQ: 0,
      created: this.now(),
      hostLeft: null,
    };
    this.rooms.set(code, room);
    sock.room = code;
    sock.role = 'host';
    this._send(sock, { t: 'created', room: code, token: room.token });
    this._presence(room);
  }

  _resume(sock, msg) {
    const room = this.rooms.get(String(msg.room || ''));
    if (!room || typeof msg.token !== 'string' || !this._tokenOk(room.token, msg.token)) {
      return this._err(sock, 'Room sudah ditutup. Buat room baru.');
    }
    this.onClose(sock);
    if (room.host && room.host !== sock) {
      const old = room.host;
      old.room = null;
      old.role = null;
      try { old.close(4000, 'replaced'); } catch (e) { /* abaikan */ }
    }
    room.host = sock;
    room.hostLeft = null;
    sock.room = room.code;
    sock.role = 'host';
    this._send(sock, { t: 'resumed', room: room.code });
    this._presence(room);
  }

  _join(sock, msg) {
    const ip = sock.ip || '?';
    if (this._blocked(ip)) return this._err(sock, 'Terlalu banyak percobaan. Tunggu 1 menit.');
    const code = String(msg.room || '');
    const room = /^\d{6}$/.test(code) ? this.rooms.get(code) : null;
    if (!room) {
      this._fail(ip);
      return this._err(sock, 'Room tidak ditemukan. Periksa Room Code.');
    }
    if (room.remotes.size >= this.o.maxRemotes) return this._err(sock, 'Room penuh.');
    this.onClose(sock);
    room.remotes.add(sock);
    sock.room = code;
    sock.role = 'remote';
    this._send(sock, { t: 'joined', room: code, host: !!room.host });
    if (room.state) this._send(sock, { t: 'state', s: room.state });
    this._presence(room);
  }

  _state(sock, msg) {
    if (sock.role !== 'host') return;
    const room = this.rooms.get(sock.room);
    if (!room || room.host !== sock) return;
    const s = this._clean(msg.s);
    if (!s) return;
    if (typeof msg.q === 'number') {
      if (msg.q <= room.lastQ) return;
      room.lastQ = msg.q;
    }
    room.state = s;
    for (const r of room.remotes) this._send(r, { t: 'state', s });
  }

  // ---------- perawatan berkala
  sweep() {
    const t = this.now();
    for (const [code, room] of this.rooms) {
      const hostGone = !room.host && room.hostLeft !== null && t - room.hostLeft > this.o.hostGraceMs;
      const tooOld = t - room.created > this.o.roomMaxAgeMs;
      if (!hostGone && !tooOld) continue;
      for (const r of room.remotes) {
        this._err(r, 'Room ditutup.');
        r.room = null;
        r.role = null;
        try { r.close(4001, 'closed'); } catch (e) { /* abaikan */ }
      }
      if (room.host) {
        this._err(room.host, 'Room kedaluwarsa.');
        room.host.room = null;
        room.host.role = null;
        try { room.host.close(4001, 'closed'); } catch (e) { /* abaikan */ }
      }
      this.rooms.delete(code);
    }
    for (const [ip, e] of this.joinFails) if (t >= e.reset) this.joinFails.delete(ip);
  }

  stats() {
    let remotes = 0;
    for (const r of this.rooms.values()) remotes += r.remotes.size;
    return { rooms: this.rooms.size, remotes };
  }
}

module.exports = { Relay };
