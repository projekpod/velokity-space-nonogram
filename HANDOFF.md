# Handoff — Velokity v1.0

Branch `codex/t11b-portal-compliance` berangkat dari `origin/main` yang sudah memuat T11. v1.0 berisi 60 Nonogram, 12 puzzle Ronde Bonus, dan 120 papan Rasi Bintang. Oz membuka PR setelah review Claude.

## Yang berjalan

- Save baru langsung membuka Moon 01. Tiga langkah tutorial bisa dilewati sambil papan tetap bisa dimainkan. Hasil kemenangan pertama menawarkan tombol Menu. Progres, hadiah, dan penyelesaian onboarding tersimpan dalam satu transaksi. Save lama masuk menu seperti sebelumnya.
- Banner Bridge hanya diminta saat gameplay yang mendukungnya pada viewport lanskap selebar minimal 600 CSS px. Layout mengikuti tinggi strip yang diukur dari elemen DOM, termasuk perubahan ukuran saat bermain. Perubahan kelayakan banner mengikuti event resize browser. Interstitial melalui Bridge diajukan saat hasil ditutup. Bridge mengatur jeda 90 detik. FakeAds mempertahankan batas level, waktu sesi, dan cooldown.
- `docs/store/` berisi ikon 512×512, favicon 64×64, seluruh cover CrazyGames dan itch.io, tiga thumbnail GameDistribution, empat screenshot gameplay 720×1280, dan teks EN/ID. File terbesar 160.141 byte. `docs/.gdignore` tetap aktif. `art/icon.png` bersumber dari ikon toko.
- Playwright merekam pengisian sel, kombo, dan kemenangan Moon 01 melalui input biasa. Dua MP4 H.264 berdurasi 15,27 detik. Lanskap 1920×1080 berukuran 842.612 byte, potret 1080×1620 berukuran 1.135.515 byte. Job `qa-screenshots` membuat artefak `velokity-store-videos` saat push branch `codex/**` atau pada PR. Oz mengambilnya dari bagian **Artifacts** pada run **Quality gates** yang hijau.
- Panduan rilis `docs/RELEASE.md` memuat file dan kolom unggahan serta cek per portal, berurutan dari itch.io hingga GameDistribution. `docs/privacy.md` menjelaskan save browser dan penggunaan SDK portal.
- Preset Android menargetkan API 36 dan AAB arm64 dengan package `com.projekpod.velokity`. AAB bertanda tangan menunggu Android SDK dan signing key lokal. Repo tidak berisi keystore.

## T11b · Perbaikan CI

Run #25 gagal saat reload terakhir. Predikat asinkron `waitForFunction` dianggap berhasil saat mengembalikan Promise, bahkan jika isinya `false`. QA kini menunggu hasil setiap baca IndexedDB dan hanya reload setelah snapshot sesuai. Semua pemeriksaan playthrough tetap dijalankan.

## T11b · Playgama

- Web menunggu SDK selesai diinisialisasi, lalu membaca satu snapshot dari Bridge Storage sebelum menampilkan layar pertama. Save lama dikopi sekali dan file lokal dihapus sesudah SDK mengonfirmasi penulisan. Build tanpa SDK memakai file lokal. Data korup diarsipkan dan versi yang lebih baru dilindungi dari penulisan.
- Bahasa tersimpan mengalahkan bahasa portal. Satu event `game_ready` dikirim setelah menu atau Moon 01 tersedia. Sinyal pause dan tab tersembunyi menjeda game serta membisukan audio. Sinyal audio portal mengatur mute sambil menghormati alasan jeda lain. Tombol rewarded tersembunyi di portal yang tidak mendukungnya.

## Pemeriksaan

Impor Godot 4.7.2, kedua ekspor Web, 464 pemeriksaan Godot, 10 tes Python, dan validator keunikan lulus. Validator membuktikan satu solusi untuk setiap Nonogram utama, puzzle bonus, dan Rasi Bintang. Ukuran Web mentah **41.091.751 byte (41,09 MB)** untuk 12 file. Web QA 41.106.651 byte. ZIP rilis `velokity-itch.zip` **11.070.880 byte (11,07 MB)**. Batas 50 MB terpenuhi tanpa mengandalkan kompresi HTTP. Transfer aktual di portal bergantung pada kompresi hosting.

Playwright menyelesaikan Moon 01–05, Rasi Bintang, album dan pencapaian, tiga tahap Ronde Bonus, serta pratinjau, beli, dan pasang kostum. Muat ulang diuji setelah progres dan kostum persisten di IndexedDB. Sinkronisasi browser berlangsung asinkron, jadi muat ulang sebelum transaksi IndexedDB selesai dapat memuat snapshot sebelumnya. Uji banner melalui SDK simulasi mencakup lebar 599/600 CSS px, rotasi, dan pengukuran ulang tinggi 78/213 px. Build Web rilis mengabaikan rute QA.

Pengukuran profil sentuh 393×851 CSS @2× dengan SwiftShader menghasilkan **4,7 FPS, p95 417 ms** pada runner ini. Uji stres dengan CPU 4× lebih lambat menghasilkan 2,8 FPS dan p95 800 ms. Uji pembanding dengan batching bintang tidak meningkatkan hasil. CI melaporkan FPS dan p95 di ringkasan run. Gate performa T11 masih terbuka sampai pengujian pada ponsel kelas menengah dengan GPU perangkat.

## Yang masih terbuka

- QA portal resmi menunggu Oz. Validasi Bridge Storage, bahasa, mute/pause, dan interstitial di QA Tool Playgama sebelum submit.
- GameDistribution memerlukan Game ID dan SDK. Adapter Bridge v2.4.4 meminta preroll ketika menerima `SDK_READY`. Preroll perlu dikonfirmasi karena proyek meminta interstitial pada jeda hasil. Tahan pengajuan GameDistribution sampai QA portal memastikan alur tanpa preroll.
- Pengukuran saat ini memakai template Web resmi. Evaluasi template tanpa 3D bila kompresi hosting belum mencapai target 20 MB. Uji ulang 2D, input, dan audio sebelum mengganti template.

## Perintah reproduksi

Dari akar repo, gunakan Godot 4.7.2 dengan template ekspor yang sesuai, Python 3, Node.js 24, Chromium, dan FFmpeg.

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
git diff --check origin/main
npm --prefix .github/qa ci
(cd .github/qa && npx playwright install chromium)
python3 -m http.server --bind 127.0.0.1 8765 --directory build
```

Dengan server berjalan, jalankan di terminal lain. Set `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium` bila memakai Chromium sistem.

```sh
node .github/qa/capture.mjs http://127.0.0.1:8765/ build/qa-screenshots
node .github/qa/release-check.mjs http://127.0.0.1:8765/
node .github/qa/store-art.mjs http://127.0.0.1:8765/ build/store
node .github/qa/preview-video.mjs http://127.0.0.1:8765/ build/store-videos
```

## Tiga langkah berikutnya

1. Oz buka PR dan cek artefak dari commit rilis. Di ponsel kelas menengah, rekam 10–15 detik saat mengisi Moon 01 sampai menang lewat panel Performance di Chrome DevTools dengan remote debugging. Targetnya minimal 30 FPS dengan p95 durasi frame maksimal 50 ms. Setelah lulus, uji dan terbitkan draf itch.io dengan tautan Traktir.
2. Jalankan QA portal berikutnya sesuai urutan di `docs/RELEASE.md`. Selesaikan syarat Playgama dan GameDistribution sebelum menekan Submit di masing-masing portal.
3. T12 — Tambahkan konten v1.1, termasuk 300 Nonogram hingga 15×15, zoom/pan, 365 puzzle harian, dan kurva kesulitan.
