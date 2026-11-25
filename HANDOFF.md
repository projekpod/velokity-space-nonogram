# Handoff — Velokity

T01–T04 selesai di branch `codex/t04-game-flow-save`, dari `origin/main` yang sudah memuat T03. Proyek memakai Godot 4.7.2 Compatibility dengan ekspor Web single-threaded. Semua layar tersedia dalam bahasa Inggris dan Indonesia.

## Yang berjalan

- Menu utama menuju Nonogram, Rasi Bintang, dan pengaturan. Bulan, Mars, dan Saturnus masing-masing punya 20 level yang bisa dipilih dan diulang. Daftar planet serta level menampilkan progres. Jupiter dan Neptunus tampil sebagai teaser terkunci.
- Nonogram punya alur menang dan kalah dengan tampilan gambar saat menang. Penyelesaian pertama memberi 20–30 koin sesuai sisa nyawa. Petunjuk seharga 10 koin memilih garis belum selesai dengan sel kosong paling sedikit. Jika seri, pilihan mengikuti urutan baris lalu kolom. Lanjut seharga 20 koin mempertahankan papan dan mengembalikan satu nyawa, sekali per percobaan. FakeAds menyediakan petunjuk, lanjut, dan penggandaan hadiah pertama. Hasil dan hadiah disimpan bersama agar muat ulang atau pengulangan level tidak menggandakan klaim.
- Save versi 3 menyimpan progres Nonogram, saldo, streak Rasi Bintang, dan pengaturan suara, musik, getaran, Mode Tenang, serta bahasa. Save versi 1 dan 2 dimigrasikan saat dibaca. Save rusak diarsipkan dan versi lebih baru dilindungi dari penulisan.
- Rasi Bintang memilih dari 120 papan berdasarkan tanggal lokal perangkat. Kesulitan naik dari Senin ke Minggu. Kemenangan pertama menyimpan streak dan hadiah kalender tujuh hari. Bintang yang salah meninggalkan X merah permanen pada percobaan itu dan sel tersebut hanya bisa mengurangi nyawa sekali.
- Ads memulihkan status jeda dan membuka permintaan baru saat provider melaporkan gagal atau diam selama 45 detik. Rewarded gagal memberi `granted = false` dan interstitial gagal ditutup. Respons yang datang terlambat diabaikan. Interstitial mengikuti syarat level, waktu sesi, dan cooldown. Workflow menetapkan bahwa Oz membuka dan menggabungkan PR sesudah review Claude.

## Yang masih terbuka

Provider portal menunggu T09. Pengaturan suara dan musik sudah terhubung ke bus audio. SFX dan trek musik menunggu T10. Mode Tenang mematikan getaran kesalahan. Efek gerak dan perayaan menyusul di T06–T07. Save Web tersimpan di browser yang digunakan. Preset Android masih placeholder. Ekspor Web mentah sebesar 39.976.317 byte, di bawah batas 50 MB.

## Pemeriksaan lokal

Gunakan Godot 4.7.2-stable dan template ekspor yang cocok. Jalankan dari akar checkout.

```sh
godot --headless --import
godot --headless -s res://tests/run_tests.gd
python3 -m unittest discover -s tools
python3 tools/check_levels.py
mkdir -p build/web
godot --headless --export-release Web build/web/index.html
python3 tools/report_web_size.py build/web
git diff --check origin/main
python3 -m http.server --bind 127.0.0.1 8765 --directory build/web
```

Impor dan ekspor lulus tanpa error atau peringatan. Semua 173 pemeriksaan Godot dan 8 tes Python lulus. Validator membuktikan satu solusi per papan untuk 60 Nonogram dan 120 Rasi Bintang. Uji terpisah dengan provider rewarded yang diam memulihkan permainan setelah sekitar 45 detik. Tes Godot juga mencakup interstitial yang diam, kegagalan provider, respons terlambat, dan pemulihan permintaan berikutnya.

Chromium WebGL2 dengan Playwright dan SwiftShader menguji sentuhan potret untuk pengaturan, pemilihan planet dan level, kalah, lanjut, menang, penggandaan hadiah, muat ulang, serta pembelian petunjuk dan lanjut. Rasi Bintang memakai tanggal lokal Jakarta, menampilkan X merah, dan mengabaikan tap ulang pada sel itu. Uji lanskap memakai mouse pada papan Saturnus 10×10 berbahasa Inggris.

Jalankan `python3 tools/build_daily.py` untuk mereproduksi katalog Rasi Bintang. Jalankan `python3 tools/build_levels.py` setelah mengubah pixel art Nonogram. Jika ID Nonogram berubah, hapus JSON dengan ID lama dari `data/levels/`.

## Tiga langkah berikutnya

1. T05 — Tambahkan rute `?qa=menu|game|win|daily` khusus build QA, termasuk data awal yang konsisten.
2. T05 — Layani build QA di CI dan ambil tangkapan layar dengan Chromium headless, Playwright, dan SwiftShader WebGL2.
3. T05 — Unggah tangkapan layar sebagai artefak CI, tambahkan templat PR, dan pastikan rute QA nonaktif pada build rilis.

## Catatan T10 dan T11

- T10 — Rancang zoom dan pan saat menambahkan papan 15×15 agar target sentuh tetap nyaman. Uji potret dan lanskap.
- T11 — Evaluasi template ekspor Web kustom dengan 3D dinonaktifkan. Ukur ukurannya terhadap target 20 MB dan uji kembali 2D, input, audio, dan ekspor Compatibility.
