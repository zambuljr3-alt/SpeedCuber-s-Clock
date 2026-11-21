'use strict';
// Tes logika relay tanpa jaringan: node test_relay.js
const assert = require('assert');
const { Relay } = require('./relay');

let clock = 1000000;
const relay = new Relay({ now: () => clock, maxRemotes: 2 });

function sock(ip = '1.1.1.1') {
  return { ip, room: null, role: null, out: [], closed: false,
    send(x) { this.out.push(JSON.parse(x)); },
    close() { this.closed = true; } };
}
const last = (s, t) => [...s.out].reverse().find((m) => m.t === t);
const msg = (s, m) => relay.onMessage(s, m);

// 1. buat room
const host = sock();
msg(host, { t: 'create' });
const created = last(host, 'created');
assert(created && /^\d{6}$/.test(created.room), 'kode room 6 angka');
assert(created.token.length === 32, 'token host dibuat server');
const code = created.room;

// 2. join salah / benar
const r1 = sock('2.2.2.2');
msg(r1, { t: 'join', room: '000000' });
assert(last(r1, 'error').fatal === true, 'room salah -> error');
msg(r1, { t: 'join', room: code });
assert(last(r1, 'joined').host === true, 'join berhasil');
assert(last(host, 'presence').remotes === 1, 'host tahu ada 1 remote');

// 3. state host diteruskan dan dibersihkan
msg(host, { t: 'state', q: 1, s: { p: 'run', txt: 'x'.repeat(100), m: 9, lim: 60, ins: 0, st: 1700000000123, hack: 'x' } });
const st = last(r1, 'state').s;
assert.strictEqual(st.p, 'run');
assert.strictEqual(st.txt.length, 16, 'teks dipotong');
assert.strictEqual(st.m, 2, 'mode dibatasi');
assert.strictEqual(st.st, 1700000000123);
assert(!('hack' in st), 'field asing dibuang');

// 4. remote tidak boleh kirim state; urutan q lama diabaikan
const before = r1.out.length;
msg(r1, { t: 'state', q: 5, s: { p: 'idle' } });
msg(host, { t: 'state', q: 1, s: { p: 'idle' } });
assert.strictEqual(r1.out.length, before, 'state ilegal/lama tidak diteruskan');

// 5. joiner terlambat langsung dapat state terakhir
const r2 = sock('3.3.3.3');
msg(r2, { t: 'join', room: code });
assert.strictEqual(last(r2, 'state').s.p, 'run', 'state tersimpan dikirim ke joiner baru');

// 6. room penuh
const r3 = sock('4.4.4.4');
msg(r3, { t: 'join', room: code });
assert(/penuh/i.test(last(r3, 'error').msg), 'room penuh');

// 7. host putus -> remote diberi tahu -> resume
relay.onClose(host);
assert.strictEqual(last(r1, 'presence').host, false);
const host2 = sock();
msg(host2, { t: 'resume', room: code, token: 'salah' });
assert(last(host2, 'error'), 'token salah ditolak');
msg(host2, { t: 'resume', room: code, token: created.token });
assert(last(host2, 'resumed'), 'resume berhasil');
assert.strictEqual(last(r1, 'presence').host, true);
msg(host2, { t: 'state', q: 2, s: { p: 'idle', txt: '9.876' } });
assert.strictEqual(last(r1, 'state').s.txt, '9.876', 'state setelah resume masih jalan');

// 8. ping/pong
const pinger = sock();
msg(pinger, { t: 'ping', c: 12345 });
assert.deepStrictEqual(last(pinger, 'pong'), { t: 'pong', c: 12345, s: clock });

// 9. host hilang lewat masa tenggang -> room ditutup
relay.onClose(host2);
clock += 11 * 60 * 1000;
relay.sweep();
assert.strictEqual(relay.stats().rooms, 0, 'room kedaluwarsa dibersihkan');
assert(r1.closed, 'remote diputus saat room ditutup');

// 10. batas percobaan join salah
const brute = sock('9.9.9.9');
for (let i = 0; i < 8; i++) msg(brute, { t: 'join', room: '111111' });
const h3 = sock();
msg(h3, { t: 'create' });
msg(brute, { t: 'join', room: last(h3, 'created').room });
assert(/banyak percobaan/i.test(last(brute, 'error').msg), 'brute force diblokir');

// 11. anti-flood
const spam = sock();
let ok = 0;
for (let i = 0; i < 100; i++) if (relay.allow(spam)) ok++;
assert.strictEqual(ok, 40, 'maksimal 40 pesan/detik');

console.log('SEMUA TES RELAY LULUS');
