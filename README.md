# Speedcuber's Clock v12

Timer cube ala Stackmat, dibuat dengan Godot 4 (Compatibility renderer).

## Cara buka
1. Ekstrak zip, buka `project.godot` di Godot 4.3+ (biarkan Godot meng-import `icon.png`).
2. Tekan F5 untuk jalan di PC.

## Export ke Android
Project > Export > Add > Android, lalu export APK. Orientasi sudah landscape.

## Cara pakai
(Panduan langkah demi langkah juga ada di dalam aplikasi: Menu > Panduan.)

- Tahan kedua pad sampai tangan jadi hijau, lepas untuk mulai, sentuh pad untuk berhenti.
- Play = mulai inspeksi 15 detik, Power = inspeksi ON/OFF.
- Save = riwayat solve, Reset = layar kembali ke 0.000.
- Hamburger (kanan atas) = menu: Sesi, Puzzle, Mode dan Alat, Statistik, Riwayat, Tema dan Suara, Data (CSV).
- Ketuk area scramble di atas untuk scramble baru.
- PC: tahan Space = kedua pad, atau klik mouse pada pad.

## Mode
- Normal: timer biasa.
- Countdown: hitung mundur dari batas waktu; habis = DNF otomatis.
- BLD: tahan-lepas mulai memo, sentuh pad selesai memo, tahan-lepas lagi untuk eksekusi.

## Berkas
- `main.gd` UI, logika timer, menu
- `scrambler.gd` scramble semua puzzle + simulasi cube untuk preview
- `sfx.gd` suara (dibuat lewat kode) dan TTS inspeksi
- `chart.gd` grafik statistik
- `ico.gd` ikon kartu menu
- `net_client.gd` klien WebSocket via server (mode Internet)
- `lan_client.gd` sambungan langsung Wi-Fi/Hotspot tanpa server (mode utama)
- `server.js`, `relay.js`, `package.json`, `Dockerfile`, `test_relay.js`, `DEPLOY.md` backend relay Node.js (hanya untuk mode Internet)

## Tips pakai ala Stackmat asli
- Taruh HP landscape di meja, tempelkan telapak tangan kiri dan kanan di sisi layar.
- Gesture navigasi Android dari tepi layar bisa terpicu kalau tangan menyentuh pinggir. Gunakan navigasi 3 tombol, atau aktifkan screen pinning, supaya aman.
- Kalau timer terlalu cepat/lambat berubah hijau, atur Waktu tahan pad di Tema dan Suara.

## Cara paling mudah: Wi-Fi / Hotspot (tanpa server)
1. HP 1 dan HP 2 di Wi-Fi yang sama, atau nyalakan hotspot di HP 1 dan sambungkan HP 2 ke sana.
2. HP 1: Menu > Layar Remote > BUAT ROOM. Room Code muncul.
3. HP 2: Menu > Layar Remote > ketik Room Code > GABUNG. Layar langsung jadi tampilan Remote.
4. Kalau host tidak ketemu: pastikan kode benar; Wi-Fi umum/sekolah sering memblokir antar-perangkat, pakai hotspot HP 1.

## Remote Timer Display lewat Internet (butuh server)
1. Deploy server (`DEPLOY.md`) atau jalankan lokal untuk uji coba.
2. HP 1 (Host): Menu > Online > isi alamat server > CREATE ROOM. Room Code muncul.
3. HP 2 (Remote): Menu > Online > isi alamat server yang sama + Room Code > CONNECT. Layar langsung masuk mode Remote Display.
4. Tunggu ping tampil di HP 1 (tanda jam sudah sinkron), lalu pakai timer seperti biasa di HP 1.
5. HP 2: ketuk layar untuk memunculkan tombol KELUAR. Tombol Back Android juga keluar dari mode ini.

## Build APK
1. Godot 4.3+ dengan Android build tools (JDK 17, Android SDK) diatur di Editor Settings > Export > Android.
2. Project > Export > Add > Android. Pastikan izin **Internet** tercentang (Permissions).
3. Isi Package > Unique Name (mis. `com.speedcubers.clock`), centang Export With Debug untuk uji coba.
4. Export Project (APK) lalu pasang di kedua HP, atau Remote Debug lewat USB.
