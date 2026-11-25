# Handoff — Velokity

T01–T08 selesai. T08 ada di branch `codex/t08-meta-progression` dari `origin/main` yang sudah memuat T07. Proyek memakai Godot 4.7.2 Compatibility dengan ekspor Web single-threaded. Semua layar tersedia dalam bahasa Inggris dan Indonesia.

## Yang berjalan

- Menu utama menampilkan level pemain, XP, saldo, dan akses ke Nonogram, Rasi Bintang, login harian, album planet, toko kostum, serta pengaturan. Save baru membuka Bulan 01. Selesaikan satu level untuk membuka level berikutnya di planet itu. Selesaikan 15 level Bulan untuk membuka Mars dan 15 level Mars untuk membuka Saturnus. Pilihan terkunci tetap terlihat dengan syaratnya. Level yang sudah selesai di save lama bisa diulang melalui pilihan tambahan jika planetnya masih terkunci. Tombol berikutnya hanya tampil saat level tujuan terbuka.
- Nonogram punya alur menang dan kalah dengan tampilan gambar saat menang. Hadiah dasar pertama 20–30 koin mengikuti sisa nyawa. Petunjuk seharga 30 koin memilih garis belum selesai dengan sel kosong paling sedikit. Jika seri, pilihan mengikuti urutan baris lalu kolom. Lanjut seharga 50 koin mempertahankan papan dan mengembalikan satu nyawa, sekali per percobaan. FakeAds menyediakan petunjuk, lanjut, dan penggandaan hadiah pertama. Hasil dan hadiah disimpan bersama agar muat ulang atau pengulangan level tidak menggandakan klaim.
- Kombo dimulai pada tiga garis benar berturut-turut dan naik dari ×2 sampai ×5 pada enam garis. Kesalahan mengakhiri rentetan aktif. Rentetan terbaik menentukan hadiah pertama hingga 60 koin, disimpan bersama kemenangan. Pengulangan memberi 0 koin. Penggandaan lewat iklan tetap merupakan klaim terpisah. Tema visual diacak dari tujuh tema sesuai level pemain. `Economy.player_level()` memakai XP tersimpan dengan ambang 200 XP per level. Penyelesaian pertama Nonogram atau Rasi Bintang memberi 100 XP, lencana baru memberi 20 XP, dan setiap tahap bonus memberi 40 XP.
- Save versi 5 menyimpan XP, kalender login, pembelian, dan kostum yang dipakai. Migrasi memberi 100 XP per kemenangan pertama yang tercatat, sehingga level dan tema kombo lama tetap terbuka. Save juga menyimpan satu lencana per level Nonogram yang selesai dengan tiga nyawa, termasuk saat diulang. Migrasi versi 1–4 mempertahankan saldo, progres, dan pengaturan, memakai streak yang tersimpan sebagai taksiran minimum kemenangan harian lama. Lencana untuk kemenangan lama bisa diperoleh saat mengulang level dengan sempurna. Save rusak diarsipkan dan versi lebih baru dilindungi dari penulisan.
- Setiap empat lencana membuka satu Ronde Bonus. Satu ronde berisi tiga Nonogram 5×5 dari katalog tersendiri dengan hadiah 10, 20, lalu 30 koin. Urutan puzzle tetap. Kemenangan dan koin tersimpan per tahap. Pemain dapat keluar lalu melanjutkan dari tahap yang belum selesai, atau mencoba tahap lagi setelah kalah.
- Album Bulan, Mars, dan Saturnus masing-masing berisi 20 gambar dari Nonogram yang sudah selesai. Setiap album lengkap membuka kostum eksklusif. Empat pencapaian membuka kostum tambahan dari penyelesaian Nonogram, lencana sempurna, kemenangan harian, dan penyelesaian ronde bonus.
- Tujuh kostum toko berharga 400–2.000 koin. Pemain dapat mencoba pratinjau lalu memasang helm, baju, jetpack, atau aksesori secara terpisah. Kostum mengubah tampilan maskot pada menu, permainan, dan perayaan. Pembelian menyimpan saldo dan kepemilikan dalam satu transaksi.
- Kalender login memakai tanggal lokal perangkat dan mengikuti jalur progres sendiri. Tujuh hadiah berturut-turut bernilai 10, 15, 15, 20, 20, 30, dan 40 koin. Melewatkan satu hari memulai siklus baru. Tanggal yang sama atau lebih lama dari klaim terakhir tetap terkunci setelah muat ulang.
- Rasi Bintang memilih dari 120 papan berdasarkan tanggal lokal perangkat. Kesulitan naik dari Senin ke Minggu. Kemenangan pertama menyimpan streak dan hadiah kalender tujuh hari. Bintang yang salah meninggalkan X merah permanen pada percobaan itu dan sel tersebut hanya bisa mengurangi nyawa sekali.
- Ads memulihkan status jeda dan membuka permintaan baru saat provider melaporkan gagal atau diam selama 45 detik. Rewarded gagal memberi `granted = false` dan interstitial gagal ditutup. Respons yang datang terlambat diabaikan. Interstitial mengikuti syarat level, waktu sesi, dan cooldown. Workflow menetapkan bahwa Oz membuka dan menggabungkan PR sesudah review Claude.
- Velokity adalah rig kucing astronaut 2D yang digambar dengan kode. Maskot tampil di menu, Nonogram, dan Rasi Bintang, dengan delapan ekspresi, gerakan napas, kedipan acak, tatapan mengikuti penunjuk, gerak pegas pada telinga, ekor, dan antena, serta squash dan stretch. Isian melenting, garis benar menyala lembut, dan papan bergeser sedikit saat salah. Perayaan garis benar berlangsung 0,3 detik dan kombo 1 detik. Penyelesaian sempurna memakai perayaan 2 detik. Penyelesaian ronde dan album, streak tujuh hari, serta kenaikan level memakai perayaan 3,5 detik. Perayaan tertinggi tampil jika pencapaian terjadi bersamaan. Pada tier 3 dan 4 Velokity terbang ke tengah layar dan tombol Lewati tersedia setelah satu detik. Mode Tenang mempersingkat perayaan, menempatkan maskot langsung di tengah, dan mengurangi efek gerak.
- Preset `Web QA` membuka `?qa=menu|game|win|daily|mascot|reactions|combo|bonus|album|shop|celebration` dan memakai `user://qa-save.json`. Data awal memenuhi syarat membuka Saturnus. Rute `mascot` memperlihatkan delapan ekspresi berlabel. Rute `reactions` menampilkan empat pose berdampingan. Rute `combo` membekukan perayaan tier 2 pada detik 0,48. Rute `bonus` membuka puzzle pertama Ronde Bonus. Rute `album` menampilkan koleksi Bulan, `shop` menampilkan pratinjau Helm Ungu, dan `celebration` membekukan perayaan tier 4 penyelesaian album pada detik 0,62. Job `qa-screenshots` memakai Playwright dan Chromium dengan SwiftShader WebGL2 untuk mengunggah sebelas PNG dalam artefak `velokity-qa-screenshots`. Build rilis mengabaikan semua rute QA. Sembilan PNG review di `docs/qa/` masing-masing di bawah 300 KB. Ukuran tangkapan baru adalah `album.png` 96.334 byte, `shop.png` 143.574 byte, dan `celebration.png` 166.317 byte. `docs/.gdignore` mengecualikannya dari impor dan ekspor Godot.

## Yang masih terbuka

Perayaan tier 4 dapat dipakai saat event tersedia. Provider portal menunggu T09. Pengaturan suara dan musik sudah terhubung ke bus audio, dengan aset audio menyusul di T10. Save Web tersimpan di browser yang digunakan. Preset Android masih placeholder.

## Pemeriksaan lokal

Gunakan Godot 4.7.2-stable dan template ekspor yang cocok. Jalankan dari akar checkout.

```sh
godot --headless --import
godot --headless -s res://tests/run_tests.gd
python3 -m unittest discover -s tools
python3 tools/check_levels.py
mkdir -p build/web build/web-qa
godot --headless --export-release Web build/web/index.html
godot --headless --export-release 'Web QA' build/web-qa/index.html
python3 tools/report_web_size.py build/web
python3 tools/report_web_size.py build/web-qa
git diff --check origin/main
```

Untuk tangkapan layar, gunakan Node.js 24 dan jalankan server di terminal tersendiri.

```sh
npm --prefix .github/qa ci
(cd .github/qa && npx playwright install chromium)
python3 -m http.server --bind 127.0.0.1 8765 --directory build
```

```sh
node .github/qa/capture.mjs http://127.0.0.1:8765/ build/qa-screenshots
mkdir -p docs/qa
for shot in album shop celebration; do
  cp "build/qa-screenshots/$shot.png" docs/qa/
done
```

Impor dan kedua ekspor lulus tanpa error atau peringatan. Ekspor rilis berukuran 40.050.849 byte dan ekspor QA 40.058.145 byte. Semua 363 pemeriksaan Godot dan 8 tes Python lulus. Tes mencakup migrasi XP dan tema kombo, pembayaran 30/50 koin dan opsi iklan, pembelian dan pemasangan kostum, hadiah album dan pencapaian, serta klaim login setelah muat ulang atau jam dimundurkan. Validator membuktikan satu solusi pada masing-masing dari 60 level utama, 12 puzzle bonus, dan 120 papan Rasi Bintang. Playwright menghasilkan sebelas PNG dan memverifikasi bahwa semua parameter QA diabaikan pada build rilis. Uji Web rilis juga mengklaim hadiah sebelum dan sesudah tengah malam Jakarta, lalu memverifikasi bahwa jam mundur serta muat ulang tidak membuka klaim lagi. Pengujian lokal memakai `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium`. Job GitHub Actions berjalan saat pull request atau push ke `main`.

Jalankan `python3 tools/build_daily.py` untuk mereproduksi katalog Rasi Bintang. Jalankan `python3 tools/build_levels.py` setelah mengubah pixel art level utama atau bonus. Jika ID Nonogram berubah, hapus JSON dengan ID lama pada katalog terkait.

## Tiga langkah berikutnya

1. T09 — Hubungkan Playgama Bridge ke antarmuka Ads dan uji semua placement, batas waktu, serta fallback.
2. T09 — Tambahkan tombol Traktir Velokity dengan URL dari konfigurasi dan stub IAP.
3. T09 — Siapkan ekspor untuk itch.io dan uji alur Web saat iklan tersedia, gagal, atau ditolak.

## Catatan T10 dan T11

- T10 — Rancang zoom dan pan saat menambahkan papan 15×15 agar target sentuh tetap nyaman. Uji potret dan lanskap.
- T11 — Evaluasi template ekspor Web kustom dengan 3D dinonaktifkan. Ukur ukurannya terhadap target 20 MB dan uji kembali 2D, input, audio, dan ekspor Compatibility.
