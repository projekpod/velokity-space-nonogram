# Handoff — Velokity

T01–T05 selesai di branch `codex/t05-qa-screenshots`, dari `origin/main` yang sudah memuat T04. Proyek memakai Godot 4.7.2 Compatibility dengan ekspor Web single-threaded. Semua layar tersedia dalam bahasa Inggris dan Indonesia.

## Yang berjalan

- Menu utama menuju Nonogram, Rasi Bintang, dan pengaturan. Save baru membuka Bulan 01. Selesaikan satu level untuk membuka level berikutnya di planet itu. Selesaikan 15 level Bulan untuk membuka Mars dan 15 level Mars untuk membuka Saturnus. Pilihan terkunci tetap terlihat dengan syaratnya. Level yang sudah selesai di save lama bisa diulang melalui pilihan tambahan jika planetnya masih terkunci. Tombol berikutnya hanya tampil saat level tujuan terbuka.
- Nonogram punya alur menang dan kalah dengan tampilan gambar saat menang. Penyelesaian pertama memberi 20–30 koin sesuai sisa nyawa. Petunjuk seharga 10 koin memilih garis belum selesai dengan sel kosong paling sedikit. Jika seri, pilihan mengikuti urutan baris lalu kolom. Lanjut seharga 20 koin mempertahankan papan dan mengembalikan satu nyawa, sekali per percobaan. FakeAds menyediakan petunjuk, lanjut, dan penggandaan hadiah pertama. Hasil dan hadiah disimpan bersama agar muat ulang atau pengulangan level tidak menggandakan klaim.
- Save versi 3 menyimpan progres Nonogram, saldo, streak Rasi Bintang, dan pengaturan suara, musik, getaran, Mode Tenang, serta bahasa. Save versi 1 dan 2 dimigrasikan saat dibaca. Save rusak diarsipkan dan versi lebih baru dilindungi dari penulisan.
- Rasi Bintang memilih dari 120 papan berdasarkan tanggal lokal perangkat. Kesulitan naik dari Senin ke Minggu. Kemenangan pertama menyimpan streak dan hadiah kalender tujuh hari. Bintang yang salah meninggalkan X merah permanen pada percobaan itu dan sel tersebut hanya bisa mengurangi nyawa sekali.
- Ads memulihkan status jeda dan membuka permintaan baru saat provider melaporkan gagal atau diam selama 45 detik. Rewarded gagal memberi `granted = false` dan interstitial gagal ditutup. Respons yang datang terlambat diabaikan. Interstitial mengikuti syarat level, waktu sesi, dan cooldown. Workflow menetapkan bahwa Oz membuka dan menggabungkan PR sesudah review Claude.
- Preset `Web QA` membuka `?qa=menu|game|win|daily` dengan data awal yang memenuhi syarat membuka Saturnus. Build QA menggunakan `user://qa-save.json`. Build rilis mengabaikan parameter QA. Job `qa-screenshots` memakai Chromium headless, Playwright, dan SwiftShader WebGL2 untuk mengunggah empat PNG dalam artefak `velokity-qa-screenshots`. Templat PR ada di `.github/pull_request_template.md`.

## Yang masih terbuka

Provider portal menunggu T09. Pengaturan suara dan musik sudah terhubung ke bus audio. SFX dan trek musik menunggu T10. Mode Tenang mematikan getaran kesalahan. Efek gerak dan perayaan menyusul di T06–T07. Save Web tersimpan di browser yang digunakan. Preset Android masih placeholder. Ekspor rilis sebesar 39.978.573 byte dan ekspor QA sebesar 39.981.161 byte. Keduanya di bawah batas 50 MB.

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
```

Impor dan kedua ekspor lulus tanpa error atau peringatan. Semua 191 pemeriksaan Godot dan 8 tes Python lulus. Validator membuktikan satu solusi per papan untuk 60 Nonogram dan 120 Rasi Bintang. Playwright menghasilkan keempat PNG dan memverifikasi bahwa setiap parameter QA diabaikan pada build rilis. Uji sentuh rilis memverifikasi label kunci bahasa Indonesia dan bahwa planet serta level terkunci tidak merespons tap. `actionlint` lulus. Pengujian lokal memakai `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium` karena CDN Playwright diblokir di lingkungan ini. Job GitHub Actions berjalan saat pull request atau push ke `main`.

Jalankan `python3 tools/build_daily.py` untuk mereproduksi katalog Rasi Bintang. Jalankan `python3 tools/build_levels.py` setelah mengubah pixel art Nonogram. Jika ID Nonogram berubah, hapus JSON dengan ID lama dari `data/levels/`.

## Tiga langkah berikutnya

1. T06 — Gambar dan susun bagian rig Velokity 2D di kode.
2. T06 — Tambahkan idle, kedip, arah pandang, gerak sekunder, dan delapan ekspresi.
3. T06 — Hubungkan reaksi pemain dan parallax tiga lapis. Uji Mode Tenang serta tangkapan layar QA.

## Catatan T10 dan T11

- T10 — Rancang zoom dan pan saat menambahkan papan 15×15 agar target sentuh tetap nyaman. Uji potret dan lanskap.
- T11 — Evaluasi template ekspor Web kustom dengan 3D dinonaktifkan. Ukur ukurannya terhadap target 20 MB dan uji kembali 2D, input, audio, dan ekspor Compatibility.
