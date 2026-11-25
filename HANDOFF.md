# Handoff — Velokity

T01–T03 selesai. Proyek berjalan di Godot 4.7.2 Compatibility dengan ekspor Web single-threaded. Nonogram memiliki 60 puzzle di Bulan, Mars, dan Saturnus. Rasi Bintang memiliki 120 papan Star Battle ukuran 6×6 sampai 9×9, tiga nyawa per percobaan, serta catatan X yang bisa dihapus. Menu dan permainan tersedia dalam bahasa Inggris dan Indonesia.

Rasi Bintang memakai tanggal lokal perangkat. Rotasi Senin–Minggu menaikkan tingkat kesulitan berdasarkan ukuran papan dan jumlah langkah pencarian solver. Kemenangan pertama pada tanggal itu menyimpan streak dan hadiah koin dalam satu transaksi. Kalender hadiah berputar setiap tujuh kemenangan beruntun. Hari yang terlewat memulai streak baru. Save versi 2 memigrasikan saldo koin dan pengaturan dari versi 1.

## Perbaikan QC T01–T02

- Nonogram langsung mengoreksi sel yang salah. Sel yang sama hanya bisa mengurangi nyawa sekali, dan kesalahan pertama menghentikan drag. Petunjuk mengisi sel pada baris atau kolom belum selesai dengan jumlah sel kosong paling sedikit. Jika seri, petunjuk memilih salah satu garis secara acak.
- Gutter petunjuk mengikuti panjang petunjuk per sumbu. Pada lebar dasar 720 px, papan 10×10 memiliki sel minimal 56 px. Papan mulai ukuran 10×10 memakai pemisah tebal setiap lima sel.
- Iklan memakai `Ads.request_rewarded(placement)` dan sinyal `rewarded_finished(placement, granted)`. Pemberian hadiah menunggu sinyal dengan `granted = true`. Interstitial mengikuti sinyal `interstitial_closed`. FakeAds mengirim hasil secara deferred, dan input serta audio gameplay dijeda selama iklan.
- Save yang rusak diarsipkan ke `user://save.corrupt-<unix_time>.json` dan permainan kembali ke nilai awal. Save dengan versi lebih baru dipertahankan dan dilindungi dari penulisan.
- Workflow CI berjalan saat push ke `main` dan saat pull request.

## Yang masih terbuka

Progres Nonogram, alur album lengkap, dan layar pengaturan menunggu T04. Progres harian disimpan di perangkat atau browser yang digunakan. Preset Android masih placeholder. Artefak Web mentah berukuran 39.963.449 byte, di bawah batas 50 MB. Kompresi gzip menghasilkan sekitar 10,28 MB bila diaktifkan oleh host.

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

Impor dan ekspor lulus tanpa peringatan. Sebanyak 128 pemeriksaan Godot dan 8 tes Python lulus. Tepat satu solusi terbukti untuk masing-masing dari 60 Nonogram dan 120 Rasi Bintang. Chromium WebGL2 menguji tanggal Jakarta saat UTC masih hari sebelumnya, kemenangan pada dua hari berturut-turut, penyimpanan klaim setelah muat ulang, penolakan klaim ulang, dan alur kalah dengan sentuhan potret dalam bahasa Indonesia. Uji Web QC memverifikasi penghentian drag, pengabaian tap ulang pada sel yang sudah dikoreksi, dan sentuhan pada papan Saturnus 10×10.

Jalankan `python3 tools/build_daily.py` untuk mereproduksi katalog Rasi Bintang. Jalankan `python3 tools/build_levels.py` setelah mengubah pixel art Nonogram. Jika ID Nonogram berubah, hapus JSON dengan ID lama dari `data/levels/`.

## Tiga langkah berikutnya

1. T04 — Buat alur menu, album, dan pemilihan level dengan indikator progres serta teaser album terkunci.
2. T04 — Simpan hasil Nonogram dan uji penghasilan koin serta transaksi petunjuk dan lanjut.
3. T04 — Hubungkan layar pengaturan dan uji muat ulang, migrasi save, serta alur menang dan kalah di Web.


## Catatan T10 dan T11

- T10 — Rancang zoom dan pan saat menambahkan papan 15×15 agar target sentuh tetap nyaman. Uji potret dan lanskap.
- T11 — Evaluasi template ekspor Web kustom yang dioptimalkan untuk ukuran dengan 3D dinonaktifkan. Ukur penurunan dari 39,9 MB mentah menuju target ≤20 MB dan uji kembali 2D, input, audio, dan ekspor Compatibility.
