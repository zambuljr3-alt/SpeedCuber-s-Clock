# Changelog - Speedcuber's Clock

## v12 (2026-11-21)
Dibuat supaya mudah diupload ke GitHub dari HP.

- Folder server/ dihapus: semua file backend dipindah ke folder utama, jadi seluruh project satu level dan bisa diupload sekaligus lewat Add file > Upload files
- Ditambah .gitignore (mengabaikan .godot/, APK, keystore, export_presets.cfg, node_modules)
- Teks yang menyebut folder server diperbarui (aplikasi, README, DEPLOY.md)
- Tidak ada perubahan fitur

## v11 (2026-11-21)
Panduan langkah demi langkah di dalam aplikasi.

- Kartu menu baru "Panduan" (menggantikan kartu Tentang; Tentang tetap ada di dalam Panduan)
- 5 panduan berlangkah dengan tombol Sebelumnya / Berikutnya: Cara pakai timer, Sambungkan 2 HP (Wi-Fi/Hotspot), Sambungkan lewat Internet, Mode dan fitur lain, Tips dan masalah umum
- Panduan "Cara pakai timer" tampil otomatis sekali saat aplikasi dibuka pertama kali (juga sekali setelah update ini)
- Tombol pintas di langkah terakhir panduan sambungan (Buka Layar Remote)

## v10 (2026-11-21)
Biar mudah: sambungan dua HP tanpa server.

- Mode baru "Wi-Fi / Hotspot" (jadi pilihan utama): tidak perlu server dan tidak perlu internet. HP 1 tekan BUAT ROOM, HP 2 ketik Room Code lalu GABUNG
- Host ditemukan otomatis lewat Wi-Fi yang sama (siaran + pencarian di seluruh jaringan /24), jadi tidak perlu mengetik alamat IP
- Bisa lewat hotspot: nyalakan hotspot di HP 1 dan sambungkan HP 2 ke sana
- Sinkron jam ke Host (ping/pong), status diulang tiap detik dan dikirim ulang cepat saat berubah agar paket UDP yang hilang tersusul
- Mode Internet (server) tetap ada sebagai pilihan kedua untuk beda jaringan
- Kartu menu "Online" diganti nama jadi "Layar Remote"; layar Online disederhanakan (tombol pilih mode, tombol besar BUAT ROOM, kolom kode)
- Layar Host di mode Wi-Fi menampilkan IP HP untuk bantuan jika gagal

## v9 (2026-11-21)
Perbaikan bug dari v8 (tidak ada fitur baru).

- main.gd baris 1639 (layar Online): perbaiki parse error "Cannot infer the type of code" dengan tipe String eksplisit; script main.gd kembali bisa dimuat
- Label versi di menu Tentang jadi v9

## v8 (2026-11-21)
Fitur baru: Remote Timer Display (dua HP lewat internet). Semua fitur v7 tetap ada.

Baru:
- Menu > Online: CREATE ROOM (Host, HP 1) dan JOIN ROOM + CONNECT (Remote, HP 2) dengan Room Code 6 angka
- Backend relay WebSocket sungguhan di folder `server/` (Node.js), lengkap dengan Dockerfile, panduan deploy, dan tes logika room
- Sinkron berbasis timestamp: Host mengirim waktu mulai (jam server), Remote menghitung waktu tampil sendiri; sinkron jam lewat ping/pong ala NTP (sampel RTT terkecil)
- Status dikirim hanya saat berubah (mulai inspeksi, tahan/siap, start, stop, reset), bukan tiap frame
- Reconnect otomatis (backoff 1-10 detik); Host kembali ke room yang sama lewat token yang dibuat server; Remote langsung dapat status terakhir saat tersambung ulang
- Mode Remote Display (tampilan Rubik Timer Stand): layar hitam, digit merah LED, tombol disembunyikan (ketuk layar untuk tombol KELUAR), layar tetap menyala
- Orientasi: opsi Landscape atau Otomatis (landscape + portrait) di Tema dan Suara; layout utama ikut berada di tengah saat portrait
- Tombol Back Android: keluar dari layar remote / menutup menu dulu, baru keluar aplikasi
- Menu: kartu Online (3x3 kartu), transisi fade

Keamanan:
- Tidak ada secret/API key di aplikasi; alamat server diisi pengguna, token host dibuat acak oleh server dan hanya ada di memori
- Server: batas ukuran pesan, batas pesan per detik, batas percobaan join salah per IP, hanya Host yang boleh mengirim status, field status disaring

## v7 (2026-11-20)
Perbaikan dari uji coba pakai tangan.

- Bug: timer berhenti sendiri sebelum sempat memegang cube. Penyebabnya, saat telapak tangan diangkat, layar kadang mencatat sentuhan singkat tambahan yang dianggap "stop". Sekarang timer hanya berhenti kalau SEMUA tangan sudah terangkat dulu, lalu KEDUA pad disentuh lagi (seperti Stackmat asli), plus jeda pengaman 150 ms
- Opsi baru di Tema dan Suara: "Berhenti dengan" 2 pad (default) atau 1 pad
- Waktu tahan pad default dinaikkan jadi 1000 ms (sebelumnya 550 ms); rentang 100 sampai 3000 ms, langkah 100 ms. Pengaturan lama di-reset ke default baru sekali
- Menu didesain ulang: kartu berikon, warna mengikuti tema, garis aksen, semua tombol layar menu/sub-menu bergaya sama
- Halaman Tentang (logo + versi)

## v6 (2026-11-20)
- Tangan di pad dibesarkan (sekitar 2x lipat) dengan cincin yang lebih besar
- Saat pad disentuh, tangan langsung berubah merah (per tangan), dan cincin terisi merah searah jarum jam selama menahan; penuh = hijau, lepas untuk mulai
- Layout memakai seluruh layar (aspek expand): pita hitam di kiri/kanan hilang, pad melebar sampai tepi layar
- Zona sentuh kiri/kanan ikut sampai tepi layar

## v5 (2026-11-20)
- Waktu tahan pad default dinaikkan dari 300 ms ke 550 ms (lebih terasa seperti Stackmat asli)
- Pengaturan waktu tahan lama dari v4 di-reset ke default baru sekali; setelah itu pilihanmu tersimpan
- Rentang waktu tahan diperluas: 100 sampai 1500 ms

## v4 (2026-11-20)
Dibuat supaya bisa dipakai seperti Stackmat asli, dengan telapak tangan utuh menutupi layar.

- Zona sentuh pad diperlebar: seluruh sisi kiri dan kanan layar (bukan hanya gambar pad), jadi telapak tangan yang menempel penuh tetap terdeteksi
- Gambar pad dibesarkan mengikuti zona sentuh
- Tombol (power, play, save, reset, menu) dan ketuk-scramble diabaikan selama ada pad yang ditekan, supaya jari yang menyenggol tombol saat meletakkan tangan tidak mengubah apa-apa
- Tema baru "Stackmat Asli" (digit LCD merah, bodi gelap) dan jadi tema default untuk instalasi baru
- Waktu tahan pad (merah ke hijau) bisa diatur di Tema dan Suara (100 sampai 1000 ms, default 300)

## v3 (2026-11-20)
Perbaikan bug dari v2 (tidak ada fitur baru).

- chart.gd: perbaiki error "Cannot infer the type of y" (baris 37) di Godot 4.7 dengan tipe float eksplisit
- main.gd: tombol konfirmasi (Hapus sesi / Hapus semua solve) tidak lagi mencoba connect Callable kosong
- Label versi di menu jadi v3

## v2 (2026-11-20)
Semua ide v2 dikerjakan, plus logo jadi ikon.

Baru:
- Sesi: banyak sesi dengan riwayat dan statistik terpisah (tambah, ganti nama, hapus, kosongkan)
- Pilih puzzle per sesi: 2x2, 3x3, 4x4, 5x5, Pyraminx, Skewb, Megaminx, Clock
- Preview scramble: net 2D berwarna untuk 2x2 sampai 5x5
- Statistik lengkap: Best, Worst, Mean, Ao5, Ao12, Ao50, Ao100 (sekarang dan terbaik) + grafik 50 solve terakhir
- Deteksi PB: tanda "PB!" / "PB Ao5!" / "PB Ao12!" di LCD + suara
- Suara: beep saat siap, stop, PB; suara inspeksi 8 dan 12 detik (TTS, cadangan beep)
- Tema: Stackmat, Neon Biru, Merah Racing, Hijau Matrix, Putih Bersih
- LCD digital 7-segmen (digambar lewat kode, tanpa font tambahan)
- Ekspor CSV (clipboard + file, format mirip csTimer) dan impor dari clipboard
- Mode: Normal, Countdown (batas waktu, DNF otomatis), BLD (memo + eksekusi)
- Metronom dengan tempo yang bisa diatur
- Menu utama (tombol hamburger kanan atas)
- Logo dipakai sebagai ikon aplikasi, splash screen, dan header menu

Berubah:
- Data sekarang per sesi; save lama v1 otomatis dimigrasi ke sesi "3x3"
- Preview/scramble panjang memakai ukuran huruf otomatis

## v1 (2026-11-20)
Rilis pertama.

- UI ala timer Stackmat QY Toys: dua pad tangan, LCD tengah, 2 LED, 4 tombol
- Logika Stackmat: tahan kedua pad (merah) -> hijau -> lepas untuk mulai -> sentuh pad untuk berhenti
- Inspeksi 15 detik (+2 / DNF otomatis)
- Scramble 3x3, Best/Ao5/Ao12, riwayat solve (+2, DNF, hapus), simpan lokal
- Kontrol PC: Space = kedua pad, klik mouse pada pad
