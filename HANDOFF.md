# Handoff — Velokity

T01–T03 selesai. Proyek berjalan di Godot 4.7.2 Compatibility dengan ekspor Web single-threaded. Nonogram memiliki 60 puzzle di Bulan, Mars, dan Saturnus. Rasi Bintang memiliki 120 papan Star Battle ukuran 6×6 sampai 9×9, tiga nyawa per percobaan, serta catatan X yang bisa dihapus. Menu dan permainan tersedia dalam bahasa Inggris dan Indonesia.

Rasi Bintang memakai tanggal lokal perangkat. Rotasi Senin–Minggu menaikkan tingkat kesulitan berdasarkan ukuran papan dan jumlah langkah pencarian solver. Kemenangan pertama pada tanggal itu menyimpan streak dan hadiah koin dalam satu transaksi. Kalender hadiah berputar setiap tujuh kemenangan beruntun. Hari yang terlewat memulai streak baru. Save versi 2 memigrasikan saldo koin dan pengaturan dari versi 1.

## Yang masih terbuka

Progres Nonogram, alur album lengkap, dan layar pengaturan menunggu T04. Progres harian disimpan di perangkat atau browser yang digunakan. Preset Android masih placeholder. Artefak Web mentah berukuran 39.959.737 byte, di bawah batas 50 MB. Kompresi gzip menghasilkan sekitar 10,28 MB bila diaktifkan oleh host.

## Pemeriksaan lokal

Gunakan Godot 4.7.2-stable beserta template ekspor yang cocok, lalu jalankan perintah berikut dari akar checkout.

```sh
godot --headless --import
godot --headless -s res://tests/run_tests.gd
python3 -m unittest discover -s tools
python3 tools/check_levels.py
mkdir -p build/web
godot --headless --export-release Web build/web/index.html
python3 tools/report_web_size.py build/web
python3 -m http.server --bind 127.0.0.1 8765 --directory build/web
```

Impor dan ekspor lulus tanpa peringatan. Sebanyak 87 pemeriksaan Godot dan 8 tes Python lulus. Tepat satu solusi terbukti untuk masing-masing dari 60 Nonogram dan 120 Rasi Bintang. Chromium WebGL2 menguji tanggal Jakarta saat UTC masih hari sebelumnya, kemenangan pada dua hari berturut-turut, penyimpanan klaim setelah muat ulang, penolakan klaim ulang, dan alur kalah dengan sentuhan potret dalam bahasa Indonesia. Menu Nonogram juga diuji ulang.

Jalankan `python3 tools/build_daily.py` untuk mereproduksi katalog Rasi Bintang. Jalankan `python3 tools/build_levels.py` setelah mengubah pixel art Nonogram. Jika ID Nonogram berubah, hapus JSON dengan ID lama dari `data/levels/`.

## Tiga langkah berikutnya

1. T04 — Buat alur menu, album, dan pemilihan level dengan indikator progres serta teaser album terkunci.
2. T04 — Simpan hasil Nonogram dan uji penghasilan koin serta transaksi petunjuk dan lanjut.
3. T04 — Hubungkan layar pengaturan dan uji muat ulang, migrasi save, serta alur menang dan kalah di Web.
