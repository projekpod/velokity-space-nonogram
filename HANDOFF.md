# Handoff — Velokity

T01–T06 selesai di branch `codex/t06-velokity-mascot`, dari `origin/main` yang sudah memuat T05. Proyek memakai Godot 4.7.2 Compatibility dengan ekspor Web single-threaded. Semua layar tersedia dalam bahasa Inggris dan Indonesia.

## Yang berjalan

- Menu utama menuju Nonogram, Rasi Bintang, dan pengaturan. Save baru membuka Bulan 01. Selesaikan satu level untuk membuka level berikutnya di planet itu. Selesaikan 15 level Bulan untuk membuka Mars dan 15 level Mars untuk membuka Saturnus. Pilihan terkunci tetap terlihat dengan syaratnya. Level yang sudah selesai di save lama bisa diulang melalui pilihan tambahan jika planetnya masih terkunci. Tombol berikutnya hanya tampil saat level tujuan terbuka.
- Nonogram punya alur menang dan kalah dengan tampilan gambar saat menang. Penyelesaian pertama memberi 20–30 koin sesuai sisa nyawa. Petunjuk seharga 10 koin memilih garis belum selesai dengan sel kosong paling sedikit. Jika seri, pilihan mengikuti urutan baris lalu kolom. Lanjut seharga 20 koin mempertahankan papan dan mengembalikan satu nyawa, sekali per percobaan. FakeAds menyediakan petunjuk, lanjut, dan penggandaan hadiah pertama. Hasil dan hadiah disimpan bersama agar muat ulang atau pengulangan level tidak menggandakan klaim.
- Save versi 3 menyimpan progres Nonogram, saldo, streak Rasi Bintang, dan pengaturan suara, musik, getaran, Mode Tenang, serta bahasa. Save versi 1 dan 2 dimigrasikan saat dibaca. Save rusak diarsipkan dan versi lebih baru dilindungi dari penulisan.
- Rasi Bintang memilih dari 120 papan berdasarkan tanggal lokal perangkat. Kesulitan naik dari Senin ke Minggu. Kemenangan pertama menyimpan streak dan hadiah kalender tujuh hari. Bintang yang salah meninggalkan X merah permanen pada percobaan itu dan sel tersebut hanya bisa mengurangi nyawa sekali.
- Ads memulihkan status jeda dan membuka permintaan baru saat provider melaporkan gagal atau diam selama 45 detik. Rewarded gagal memberi `granted = false` dan interstitial gagal ditutup. Respons yang datang terlambat diabaikan. Interstitial mengikuti syarat level, waktu sesi, dan cooldown. Workflow menetapkan bahwa Oz membuka dan menggabungkan PR sesudah review Claude.
- Velokity adalah rig kucing astronaut 2D yang digambar dengan kode. Maskot tampil di menu, Nonogram, dan Rasi Bintang, dengan delapan ekspresi, gerakan napas, kedipan acak, tatapan mengikuti penunjuk, gerak pegas pada telinga, ekor, dan antena, serta squash dan stretch. Isian melenting, garis benar menyala lembut, dan papan bergeser sedikit saat salah. Kombo tiga garis benar tanpa salah dan kemenangan memicu reaksi pendek. Mode Tenang menghentikan parallax tiga lapis, menonaktifkan efek papan, kedipan, pelacakan penunjuk, dan partikel, serta menyisakan gerak maskot yang sangat kecil.
- Preset `Web QA` membuka `?qa=menu|game|win|daily|mascot|reactions` dan memakai `user://qa-save.json`. Data awal memenuhi syarat membuka Saturnus. Rute `mascot` memperlihatkan delapan ekspresi berlabel. Rute `reactions` menampilkan empat pose berdampingan. Job `qa-screenshots` memakai Playwright dan Chromium dengan SwiftShader WebGL2 untuk mengunggah enam PNG dalam artefak `velokity-qa-screenshots`. Build rilis mengabaikan semua rute QA. Empat PNG review di `docs/qa/` masing-masing di bawah 300 KB, dengan ukuran terbesar 262.954 byte. `docs/.gdignore` mengecualikannya dari impor dan ekspor Godot.

## Yang masih terbuka

Perayaan bertingkat, pengali koin kombo, lencana, dan Bonus Round menunggu T07. Provider portal menunggu T09. Pengaturan suara dan musik sudah terhubung ke bus audio, dengan aset audio menyusul di T10. Save Web tersimpan di browser yang digunakan. Preset Android masih placeholder.

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
for shot in mascot reactions menu game; do
  cp "build/qa-screenshots/$shot.png" docs/qa/
done
```

Impor dan kedua ekspor lulus tanpa error atau peringatan. Ekspor rilis berukuran 40.004.721 byte dan ekspor QA 40.009.985 byte. Semua 203 pemeriksaan Godot dan 8 tes Python lulus. Validator membuktikan satu solusi per papan untuk 60 Nonogram dan 120 Rasi Bintang. Playwright menghasilkan enam PNG dan memverifikasi bahwa setiap parameter QA diabaikan pada build rilis. Uji browser juga memeriksa Mode Tenang dan klik pada papan Nonogram di layar lanskap. `actionlint` lulus. Pengujian lokal memakai `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium`. Job GitHub Actions berjalan saat pull request atau push ke `main`.

Jalankan `python3 tools/build_daily.py` untuk mereproduksi katalog Rasi Bintang. Jalankan `python3 tools/build_levels.py` setelah mengubah pixel art Nonogram. Jika ID Nonogram berubah, hapus JSON dengan ID lama dari `data/levels/`.

## Tiga langkah berikutnya

1. T07 — Lanjutkan penghitung garis benar menjadi kombo yang memberi pengali koin berdasarkan performa. Acak hanya tema visual yang sudah terbuka.
2. T07 — Tambahkan empat tingkat perayaan, versi Mode Tenang, dan opsi lewati setelah satu detik untuk perayaan yang berlangsung minimal dua detik.
3. T07 — Simpan lencana tanpa kesalahan dan uji Bonus Round tiga puzzle 5×5 setelah empat lencana.

## Catatan T10 dan T11

- T10 — Rancang zoom dan pan saat menambahkan papan 15×15 agar target sentuh tetap nyaman. Uji potret dan lanskap.
- T11 — Evaluasi template ekspor Web kustom dengan 3D dinonaktifkan. Ukur ukurannya terhadap target 20 MB dan uji kembali 2D, input, audio, dan ekspor Compatibility.
