# Deploy relay server SPEEDCUBER'S CLOCK

Server ini hanya meneruskan status timer dari Host (HP 1) ke Remote (HP 2).
Tidak ada database, tidak ada API key. Room Code 6 angka dibuat server; token host dibuat acak
oleh server dan hanya disimpan di memori aplikasi saat room aktif.

## 1. Uji lokal (satu Wi-Fi)
```
npm install
npm test          # tes logika room (tanpa jaringan)
node server.js    # jalan di port 8080
```
Cari IP komputer (mis. 192.168.1.10). Di kedua HP (Wi-Fi yang sama) isi alamat server:
`ws://192.168.1.10:8080`. Izinkan port 8080 di firewall komputer.
Cek: buka `http://192.168.1.10:8080/health` di browser, harus muncul `{"ok":true,...}`.

## 2. Deploy ke internet (wajib wss:// untuk internet publik)
### Render.com (paling mudah)
1. Upload project ini ke repo GitHub (semua file sudah di satu level, tidak perlu mengatur Root Directory).
2. Render > New > Web Service > pilih repo.
3. Runtime Node, Build Command `npm install`, Start Command `node server.js`.
4. Setelah live kamu dapat URL `https://nama-app.onrender.com`. Di aplikasi isi `wss://nama-app.onrender.com`.
Catatan: paket gratis "tidur" setelah ~15 menit tanpa trafik; koneksi pertama bisa butuh sekitar 1 menit.
Untuk pemakaian rutin pakai paket berbayar kecil atau VPS.

### Railway / Fly.io
Keduanya bisa memakai `Dockerfile` di folder ini. Fly.io: `fly launch` lalu `fly deploy`. Port internal 8080.
Pastikan layanan memberi HTTPS/WSS otomatis.

### VPS sendiri (Ubuntu)
```
sudo apt install -y nodejs npm caddy
cd /opt/speedcubers-relay && npm install --omit=dev
sudo npm i -g pm2 && pm2 start server.js --name relay && pm2 save && pm2 startup
```
Caddyfile (HTTPS/WSS otomatis, ganti domain):
```
timer.contoh.com {
    reverse_proxy localhost:8080
}
```
Di aplikasi isi `wss://timer.contoh.com`.

## 3. Pengaturan opsional (environment variable)
- `PORT` port server (default 8080; platform hosting biasanya mengisinya sendiri)
- `MAX_REMOTES` jumlah Remote per room (default 5)
- `TRUST_PROXY=0` matikan pembacaan IP dari header X-Forwarded-For bila tidak di belakang proxy

## 4. Keamanan
- Tidak ada secret key di APK. Alamat server diisi pengguna di aplikasi.
- Hanya Host yang bisa mengirim status; field status disaring; ukuran pesan dibatasi 4 KB.
- Batas 40 pesan/detik per koneksi dan 8 percobaan join salah per menit per IP.
- Room kedaluwarsa 10 menit setelah Host menghilang, atau 12 jam sejak dibuat.
- Gunakan `wss://` untuk internet publik agar lalu lintas terenkripsi.

## 5. Pemecahan masalah
- "Tidak bisa terhubung ke server": cek alamat (`wss://` untuk hosting, `ws://` hanya untuk jaringan lokal), cek `/health`, cek izin Internet di APK.
- "Room tidak ditemukan": Room Code salah atau Host sudah menutup room.
- Waktu di HP 2 selisih: tunggu ping tampil di HP 1 sebelum mulai; jaringan seluler yang tidak stabil menambah selisih sekitar setengah RTT.
