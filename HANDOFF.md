# Handoff — Velokity

T01–T09 selesai. T09 ada di branch `codex/t09-web-monetization` dari `origin/main` yang sudah memuat T08. Proyek memakai Godot 4.7.2 Compatibility dengan ekspor Web single-threaded. Semua layar tersedia dalam bahasa Inggris dan Indonesia.

## Yang berjalan

- Menu utama menampilkan level pemain, XP, saldo, dan akses ke Nonogram, Rasi Bintang, login harian, album planet, toko kostum, serta pengaturan. Save baru membuka Bulan 01. Selesaikan satu level untuk membuka level berikutnya di planet itu. Selesaikan 15 level Bulan untuk membuka Mars dan 15 level Mars untuk membuka Saturnus. Pilihan terkunci tetap terlihat dengan syaratnya. Level yang sudah selesai di save lama bisa diulang melalui pilihan tambahan jika planetnya masih terkunci. Tombol berikutnya hanya tampil saat level tujuan terbuka.
- Nonogram punya alur menang dan kalah dengan tampilan gambar saat menang. Hadiah dasar pertama 20–30 koin mengikuti sisa nyawa. Petunjuk seharga 30 koin memilih garis belum selesai dengan sel kosong paling sedikit. Jika seri, pilihan mengikuti urutan baris lalu kolom. Lanjut seharga 50 koin mempertahankan papan dan mengembalikan satu nyawa, sekali per percobaan. Rewarded ads menyediakan petunjuk, lanjut, dan penggandaan hadiah pertama pada portal yang mendukungnya. Hasil dan hadiah disimpan bersama agar muat ulang atau pengulangan level tidak menggandakan klaim.
- Kombo dimulai pada tiga garis benar berturut-turut dan naik dari ×2 sampai ×5 pada enam garis. Kesalahan mengakhiri rentetan aktif. Rentetan terbaik menentukan hadiah pertama hingga 60 koin, disimpan bersama kemenangan. Pengulangan memberi 0 koin. Penggandaan lewat iklan tetap merupakan klaim terpisah. Tema visual diacak dari tujuh tema sesuai level pemain. `Economy.player_level()` memakai XP tersimpan dengan ambang 200 XP per level. Penyelesaian pertama Nonogram atau Rasi Bintang memberi 100 XP, lencana baru memberi 20 XP, dan setiap tahap bonus memberi 40 XP.
- Save versi 6 menambahkan kuota iklan koin. Save menyimpan XP, kalender login, pembelian, dan kostum yang dipakai. Migrasi memberi 100 XP per kemenangan pertama yang tercatat, sehingga level dan tema kombo lama tetap terbuka. Save juga menyimpan satu lencana per level Nonogram yang selesai dengan tiga nyawa, termasuk saat diulang. Migrasi versi 1–5 mempertahankan saldo, progres, dan pengaturan, memakai streak yang tersimpan sebagai taksiran minimum kemenangan harian lama. Lencana untuk kemenangan lama bisa diperoleh saat mengulang level dengan sempurna. Save rusak diarsipkan dan versi lebih baru dilindungi dari penulisan.
- Setiap empat lencana membuka satu Ronde Bonus. Satu ronde berisi tiga Nonogram 5×5 dari katalog tersendiri dengan hadiah 10, 20, lalu 30 koin. Urutan puzzle tetap. Kemenangan dan koin tersimpan per tahap. Pemain dapat keluar lalu melanjutkan dari tahap yang belum selesai, atau mencoba tahap lagi setelah kalah.
- Album Bulan, Mars, dan Saturnus masing-masing berisi 20 gambar dari Nonogram yang sudah selesai. Setiap album lengkap membuka kostum eksklusif. Empat pencapaian membuka kostum tambahan dari penyelesaian Nonogram, lencana sempurna, kemenangan harian, dan penyelesaian ronde bonus.
- Tujuh kostum toko berharga 400–2.000 koin. Pemain dapat mencoba pratinjau lalu memasang helm, baju, jetpack, atau aksesori secara terpisah. Kostum mengubah tampilan maskot pada menu, permainan, dan perayaan. Pembelian menyimpan saldo dan kepemilikan dalam satu transaksi.
- Kalender login memakai tanggal lokal perangkat dan mengikuti jalur progres sendiri. Tujuh hadiah berturut-turut bernilai 10, 15, 15, 20, 20, 30, dan 40 koin. Melewatkan satu hari memulai siklus baru. Tanggal yang sama atau lebih lama dari klaim terakhir tetap terkunci setelah muat ulang.
- Rasi Bintang memilih dari 120 papan berdasarkan tanggal lokal perangkat. Kesulitan naik dari Senin ke Minggu. Kemenangan pertama menyimpan streak dan hadiah kalender tujuh hari. Bintang yang salah meninggalkan X merah permanen pada percobaan itu dan sel tersebut hanya bisa mengurangi nyawa sekali.
- Playgama Bridge v2.4.4 dipin pada commit `f666968b5af1cd2c110a561e40c0128872e55525`. Shell Web memuat SDK lokal. `Bridge` menjadi autoload pertama. Provider Bridge dipakai pada Web yang berhasil menginisialisasi SDK. Editor dan Godot headless memakai FakeAds. Web tanpa SDK tetap bisa dimainkan dengan iklan nonaktif.
- Bridge mengirim `game_ready` saat menu pertama tampil dan `gameplay_started` serta `gameplay_stopped` saat masuk, keluar, atau menjeda puzzle untuk iklan. Iklan layar penuh menjeda permainan dan membisukan audio. Banner hanya tampil di atas gameplay pada platform yang mendukungnya. Interstitial mengikuti syarat level, waktu sesi, dan cooldown. Timeout 45 detik memulihkan permainan dan menolak klaim kedaluwarsa. Provider menunggu event terminal SDK sebelum menerima permintaan baru dari Bridge yang sempat timeout.
- Placement rewarded adalah `hint`, `continue`, `double_coins`, dan `free_coins`. Toko memberi 25 koin per rewarded ad yang selesai, maksimal lima per tanggal lokal. Hadiah dan kuota disimpan bersama. Jam mundur tidak membuka kuota lama. Pasang URL HTTPS di `data/config/monetization.cfg` lalu ekspor ulang untuk menampilkan Traktir Velokity di situs mandiri atau itch.io. Konfigurasi awal kosong. Tombol hanya tampil jika Bridge melaporkan `mock` dan mengizinkan tautan eksternal.
- Bebas Iklan dan paket 500/2.000 koin sudah terdaftar di antarmuka pembelian. Tombol produknya nonaktif sampai provider pembayaran dan katalog portal tersedia. Workflow menetapkan bahwa Oz membuka dan menggabungkan PR sesudah review Claude.
- Velokity adalah rig kucing astronaut 2D yang digambar dengan kode. Maskot tampil di menu, Nonogram, dan Rasi Bintang, dengan delapan ekspresi, gerakan napas, kedipan acak, tatapan mengikuti penunjuk, gerak pegas pada telinga, ekor, dan antena, serta squash dan stretch. Isian melenting, garis benar menyala lembut, dan papan bergeser sedikit saat salah. Perayaan garis benar berlangsung 0,3 detik dan kombo 1 detik. Penyelesaian sempurna memakai perayaan 2 detik. Penyelesaian ronde dan album, streak tujuh hari, serta kenaikan level memakai perayaan 3,5 detik. Perayaan tertinggi tampil jika pencapaian terjadi bersamaan. Pada tier 3 dan 4 Velokity terbang ke tengah layar dan tombol Lewati tersedia setelah satu detik. Mode Tenang mempersingkat perayaan, menempatkan maskot langsung di tengah, dan mengurangi efek gerak.
- Preset `Web QA` membuka `?qa=menu|game|win|daily|mascot|reactions|combo|bonus|album|shop|celebration` dan memakai `user://qa-save.json`. Data awal memenuhi syarat membuka Saturnus. Rute `mascot` memperlihatkan delapan ekspresi berlabel. Rute `reactions` menampilkan empat pose berdampingan. Rute `combo` membekukan perayaan tier 2 pada detik 0,48. Rute `bonus` membuka puzzle pertama Ronde Bonus. Rute `album` menampilkan koleksi Bulan, `shop` menampilkan pratinjau Helm Ungu, dan `celebration` membekukan perayaan tier 4 penyelesaian album pada detik 0,62. Job `qa-screenshots` memakai Playwright dan Chromium dengan SwiftShader WebGL2 untuk mengunggah sebelas PNG dalam artefak `velokity-qa-screenshots`. Build rilis mengabaikan semua rute QA. Sembilan PNG review di `docs/qa/` masing-masing di bawah 300 KB. Ukuran tangkapan T08 adalah `album.png` 96.334 byte, `shop.png` 143.574 byte, dan `celebration.png` 166.317 byte. `docs/.gdignore` mengecualikannya dari impor dan ekspor Godot.

## Yang masih terbuka

Perayaan tier 4 dapat dipakai saat event tersedia. Pemutaran iklan dan inventori masih perlu dicek pada portal resmi sebelum rilis. Pengaturan suara dan musik sudah terhubung ke bus audio, dengan aset audio menyusul di T10. Save Web tersimpan di browser yang digunakan. Preset Android masih placeholder.

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
python3 tools/package_itch.py build/web build/velokity-itch.zip
git diff --check origin/main -- . ':(exclude)addons/playgama_bridge'
git diff --check da7b84a -- addons/playgama_bridge
```

Untuk tangkapan layar, gunakan Node.js 24 dan jalankan server di terminal tersendiri.

```sh
npm --prefix .github/qa ci
(cd .github/qa && npx playwright install chromium)
python3 -m http.server --bind 127.0.0.1 8765 --directory build
```

```sh
node .github/qa/capture.mjs http://127.0.0.1:8765/ build/qa-screenshots
```

Impor dan kedua ekspor lulus tanpa error atau peringatan. Ekspor rilis berukuran 40.526.004 byte dan ekspor QA 40.533.284 byte. Semua 419 pemeriksaan Godot dan 8 tes Python lulus, termasuk batas iklan, mute dan resume, pemulihan timeout, kuota harian setelah muat ulang, dan tombol IAP yang nonaktif. Validator membuktikan satu solusi pada masing-masing dari 60 level utama, 12 puzzle bonus, dan 120 papan Rasi Bintang. Playwright SwiftShader menghasilkan sebelas PNG, memverifikasi isolasi rute QA, dan memastikan menu tetap terbuka saat SDK absen. Pemeriksaan dengan portal simulasi menguji pesan Bridge, banner atas, jeda iklan, dan penyimpanan hadiah toko. `actionlint` lulus. Pemeriksaan lokal memakai `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium`. Job GitHub Actions berjalan saat pull request atau push ke `main`.

Jalankan `python3 tools/build_daily.py` untuk mereproduksi katalog Rasi Bintang. Jalankan `python3 tools/build_levels.py` setelah mengubah pixel art level utama atau bonus. Jika ID Nonogram berubah, hapus JSON dengan ID lama pada katalog terkait.

## Unggah ke itch.io

1. Unduh `velokity-itch.zip` dari artefak CI `velokity-itch` atau buat lewat perintah ekspor dan paket di atas. ZIP berisi 12 file dengan `index.html` di akar dan berukuran 10.542.750 byte. Ekspor memakai thread support nonaktif.
2. Buat atau edit halaman game di itch.io dan pilih **HTML** pada **Kind of project**. Unggah ZIP dan centang **This file will be played in the browser**.
3. Atur ukuran embed ke 720 × 1280 atau aktifkan peluncuran layar penuh. Simpan sebagai draf dan cek pratinjau potret serta lanskap, input, audio, dan save setelah muat ulang. Chromium lokal berhasil menjalankan isi ZIP tanpa isolasi lintas origin.

## Tiga langkah berikutnya

1. T10 — Tambahkan Nonogram hingga 300 papan dan jalankan pemeriksaan solusi unik bersama alat pembuat level.
2. T10 — Perluas katalog Rasi Bintang menjadi 365 papan dan uji kurva kesulitan serta mekanik baru.
3. T10 — Buat SFX dan dua loop musik secara prosedural. Catat aset di `docs/CREDITS.md` dan ukur ulang ekspor Web.

## Catatan T10 dan T11

- T10 — Rancang zoom dan pan saat menambahkan papan 15×15 agar target sentuh tetap nyaman. Uji potret dan lanskap.
- T11 — Evaluasi template ekspor Web kustom dengan 3D dinonaktifkan. Ukur ukurannya terhadap target 20 MB dan uji kembali 2D, input, audio, dan ekspor Compatibility.
