# Handoff — Velokity Feel & Shop v1.1

Branch `codex/t12-feel-shop` berangkat dari `origin/main` setelah merge T11b. Oz membuka PR setelah review Claude. Katalog puzzle saat ini berisi 60 Nonogram, 12 puzzle Ronde Bonus, dan 120 papan Rasi Bintang.

## T12 · Feel & Shop

- Bridge Storage menulis snapshot dalam urutan commit. Saldo dan pengaturan dibaca ulang sebelum transaksi berikutnya. Stub Bridge lambat memverifikasi dua commit beruntun, transaksi yang saling menunggu, dan kelanjutan antrean setelah satu write gagal.
- Sebelas efek WAV mencapai −1 dBFS peak dan kedua loop musik sekitar −16 dBFS RMS dengan peak di bawah −1 dBFS. Bus efek 0 dB dan musik −3 dB saat normal. Mode Tenang memakai −6 dB untuk keduanya. Slider efek dan musik disimpan masing-masing dari 0 sampai 100%.
- Streak Nonogram memuncak pada pose menahan papan dan menambah denyut retakan untuk rekor berikutnya. Kesalahan memutus streak aktif sambil mempertahankan rekor. Efek streak dan toast kombo mulai pada frame berbeda. Setelah menang, retakan menutup dan Velokity mendorong papan naik sebelum panel hasil.
- Latar antariksa memuat bintang berkelip, meteor, komet, tabrakan bintang berpartikel, nebula, dan planet. Mode Tenang menyisakan kelip lambat. Setelah tiga detik dengan rata-rata frame di atas 20 ms, game beralih ke efek ringan sampai sesi berakhir.
- Toko memakai tab Kucing, Warna Bulu, dan Kostum dalam EN/ID, dengan pembelian langsung memakai koin. Save v8 menyimpan kepemilikan dan pilihan kucing dan warna bulu. Migrasi mempertahankan kostum lama beserta slotnya dan memberi pemain lama Velokity serta bulu alami.
- Web QA menambahkan `?qa=streak`, `?qa=space`, `?qa=cats`, dan `?qa=shop-legendary`. Job `qa-screenshots` menangkap rute dan mengecek batas ukuran 300 KB serta memastikan build rilis mengabaikan query QA. Empat PNG di `docs/qa/` berukuran 177.407 byte (streak), 132.302 byte (space), 196.234 byte (cats), dan 163.554 byte (shop-legendary).

## Pemeriksaan T12

Godot 4.7.2 lulus impor, 513 pemeriksaan, serta ekspor Web dan Web QA tanpa error atau warning. Sepuluh tes Python dan validator solusi lulus. Ekspor Web **41.148.430 byte (41,15 MB)**, Web QA **41.165.410 byte**, dan ZIP itch.io **11.128.611 byte**. Web memenuhi batas unduhan mentah 50 MB. Verifikasi audio dan performa pada ponsel fisik masih terbuka.

## Yang berjalan

- Save baru langsung membuka Moon 01. Tiga langkah tutorial bisa dilewati sambil papan tetap bisa dimainkan. Hasil kemenangan pertama menawarkan tombol Menu. Progres, hadiah, dan penyelesaian onboarding tersimpan dalam satu transaksi. Save lama masuk menu seperti sebelumnya.
- Banner Bridge hanya diminta saat gameplay yang mendukungnya pada viewport lanskap selebar minimal 600 CSS px. Layout mengikuti tinggi strip yang diukur dari elemen DOM, termasuk perubahan ukuran saat bermain. Perubahan kelayakan banner mengikuti event resize browser. Interstitial melalui Bridge diajukan saat hasil ditutup. Bridge mengatur jeda 90 detik. FakeAds mempertahankan batas level, waktu sesi, dan cooldown.
- `docs/store/` berisi ikon 512×512, favicon 64×64, seluruh cover CrazyGames dan itch.io, tiga thumbnail GameDistribution, empat screenshot gameplay 720×1280, dan teks EN/ID. File terbesar 160.141 byte. `docs/.gdignore` tetap aktif. `art/icon.png` bersumber dari ikon toko.
- Playwright merekam pengisian sel, kombo, dan kemenangan Moon 01 melalui input biasa. Dua MP4 H.264 berdurasi 15,27 detik. Lanskap 1920×1080 berukuran 842.612 byte, potret 1080×1620 berukuran 1.135.515 byte. Job `qa-screenshots` membuat artefak `velokity-store-videos` saat push branch `codex/**` atau pada PR. Oz mengambilnya dari bagian **Artifacts** pada run **Quality gates** yang hijau.
- Panduan rilis `docs/RELEASE.md` memuat file dan kolom unggahan serta cek per portal, berurutan dari itch.io hingga GameDistribution. `docs/privacy.md` menjelaskan save browser dan penggunaan SDK portal.
- Preset Android menargetkan API 36 dan AAB arm64 dengan package `com.projekpod.velokity`. AAB bertanda tangan menunggu Android SDK dan signing key lokal. Repo tidak berisi keystore.

## T11b · Perbaikan CI

Run #25 gagal saat reload terakhir. Predikat asinkron `waitForFunction` dianggap berhasil saat mengembalikan Promise, bahkan jika isinya `false`. QA kini menunggu hasil setiap baca IndexedDB dan hanya reload setelah snapshot sesuai. Semua pemeriksaan playthrough tetap dijalankan dan job browser lulus kembali pada run #26.

## T11b · Playgama

- Web menunggu SDK selesai diinisialisasi, lalu membaca satu snapshot dari Bridge Storage sebelum menampilkan layar pertama. Save lama dikopi sekali dan file lokal dihapus sesudah SDK mengonfirmasi penulisan. Build tanpa SDK memakai file lokal. Data korup diarsipkan dan versi yang lebih baru dilindungi dari penulisan.
- Bahasa tersimpan mengalahkan bahasa portal. Satu event `game_ready` dikirim setelah menu atau Moon 01 tersedia. Sinyal pause dan tab tersembunyi menjeda game serta membisukan audio. Sinyal audio portal mengatur mute sambil menghormati alasan jeda lain. Tombol rewarded tersembunyi di portal yang tidak mendukungnya.

## URL uji GitHub Pages

https://projekpod.github.io/velokity-space-nonogram/

Job `publish-pages` mengunduh artefak Web rilis dari run yang sama dan menerbitkannya setelah job `web` dan `qa-screenshots` lulus pada push ke `main`. Di **Settings → Pages → Build and deployment**, sumber harus **GitHub Actions**. Cek status job dan buka URL di atas setelah merge pertama. Playwright berhasil membuka ekspor rilis dari URL direktori proyek lokal yang setara dan memuat WASM, PCK, dan SDK lewat path relatif.

## Pemeriksaan T11b

Impor Godot 4.7.2, kedua ekspor Web, 466 pemeriksaan Godot, 10 tes Python, dan validator keunikan lulus. Validator membuktikan satu solusi untuk setiap Nonogram utama, puzzle bonus, dan Rasi Bintang. Ukuran Web mentah **41.096.414 byte (41,10 MB)** untuk 12 file. Web QA 41.111.778 byte. ZIP rilis `velokity-itch.zip` **11.075.453 byte (11,07 MB)**. Batas 50 MB terpenuhi tanpa mengandalkan kompresi HTTP. Transfer aktual di portal bergantung pada kompresi hosting.

Playwright menyelesaikan Moon 01–05, Rasi Bintang, album dan pencapaian, tiga tahap Ronde Bonus, serta pratinjau, beli, dan pasang kostum. Dengan Bridge simulasi, reload memulihkan progres dan kostum yang sudah dikonfirmasi SDK. Uji migrasi juga membuktikan fallback tanpa SDK memulihkan save setelah transaksi IndexedDB selesai, lalu memindahkannya sekali ke Bridge. Uji banner melalui SDK simulasi mencakup lebar 599/600 CSS px, rotasi, dan pengukuran ulang tinggi 78/213 px. Build Web rilis mengabaikan rute QA.

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

1. Oz buka PR T12 setelah review Claude. Cek job **Quality gates**, empat screenshot di artefak `velokity-qa-screenshots`, dan deployment Pages dari `main`.
2. Ukur volume dan performa di ponsel kelas menengah, lalu jalankan QA Playgama dan portal lain sesuai `docs/RELEASE.md` untuk menutup T11 dan T11b.
3. T13 — Tambahkan papan 12×12 dan 15×15 dengan zoom/pan, naikkan katalog ke 300 Nonogram dan 365 puzzle harian, lalu sesuaikan kurva kesulitan. T14 menyusul dengan mekanik kecil tiap 10–15 level.
