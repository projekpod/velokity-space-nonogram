# Handoff — Velokity

T01 menyiapkan proyek Godot, menu, terjemahan EN/ID, autoload, dan jalur ekspor Web.
T02 mengisi jalur permainan Nonogram. Rasi Bintang menyusul di T03.

## Pemeriksaan lokal

```sh
godot --headless --import
godot --headless -s res://tests/run_tests.gd
python3 tools/check_levels.py
mkdir -p build/web
godot --headless --export-release Web build/web/index.html
python3 tools/report_web_size.py build/web
```

## Langkah berikutnya

1. Selesaikan dan verifikasi T02.
2. Implementasikan generator serta validasi Rasi Bintang di T03.
3. Tambahkan alur album dan penyimpanan progres di T04.
