# Handoff — Velokity

T01 dan T02 selesai. Proyek menggunakan Godot 4.7.2 Compatibility dengan ekspor Web single-threaded. Menu EN/ID memilih puzzle dari tiga planet. Papan mendukung klik, sentuh, seret segaris, tanda X, petunjuk, tiga nyawa, dan gambar berwarna saat menang. Ada 60 gambar asli dari `art/levels_src/` dengan 20 puzzle untuk masing-masing ukuran 5×5, 8×8, dan 10×10.

## Yang masih terbuka

Rasi Bintang masih berupa tombol nonaktif dan katalog hariannya kosong sampai T03. Pemilihan puzzle belum menyimpan progres. Android punya preset placeholder dan belum diekspor. Artefak Web mentah berukuran 39.911.192 byte, di bawah batas 50 MB. Perkiraan transfer gzip 10,26 MB bergantung pada pengaturan host portal.

## Pemeriksaan lokal

Gunakan Godot 4.7.2-stable dan template ekspor yang cocok. Dari akar checkout, jalankan:

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

Impor bersih dan ekspor berjalan tanpa peringatan. Sebanyak 40 pemeriksaan Godot dan tiga tes Python lulus. Solver memverifikasi tepat satu solusi untuk setiap puzzle. Chromium WebGL2 menguji pilih dan buka papan, isi, tanda X, seret, petunjuk, menang, kalah, serta sentuhan pada tampilan potret berbahasa Indonesia.

Jika mengedit pixel art, jalankan `python3 tools/build_levels.py` sebelum pemeriksaan keunikan. Pertahankan 20 puzzle per planet. Jika ID berubah, hapus JSON dengan ID lama dari `data/levels/`.

## Tiga langkah berikutnya

1. T03 — Buat solver dan validator Star Battle. Tambahkan tes aturan baris, kolom, region, dan larangan bersentuhan diagonal.
2. T03 — Buat generator dan hasilkan 120 puzzle unik ukuran 6–9. Integrasikan verifikasi ke `tools/check_levels.py`.
3. T03 — Sambungkan Rasi Bintang ke menu. Uji pilihan tanggal lokal, rotasi kesulitan, tiga nyawa, dan kalender hadiah.
