# Panduan rilis Web untuk Oz

Urutan rilis Web adalah **itch.io → Playgama → CrazyGames Basic Launch → GameDistribution**. Buat draf dan jalankan cek di bawah pada tiap portal. Jika portal meminta perubahan, selesaikan cek portal itu sebelum menerbitkannya.

## Siapkan file di ponsel

1. Buka [GitHub Actions → Quality gates](https://github.com/projekpod/velokity-space-nonogram/actions/workflows/quality.yml). Pilih run hijau untuk commit yang akan dirilis, lalu gulir ke **Artifacts**. Masuk ke GitHub jika diminta.
2. Unduh **`velokity-itch`** dan ekstrak ZIP unduhan sekali. File di dalamnya adalah **`velokity-itch.zip`**. Unggah file di dalam itu sebagai build Web. `index.html` sudah ada di akar arsip.
3. Unduh **`velokity-store-videos`** dari run yang sama. Ekstrak `preview-landscape.mp4` dan `preview-portrait.mp4`. Keduanya menunjukkan pengisian kotak, kombo, dan kemenangan. Artefak tersedia setelah job **qa-screenshots** selesai.
4. Ambil gambar dari [`docs/store/`](store/) di commit yang sama. Buka file lalu pilih **Download raw file**. Pakai [teks EN/ID](store/TEXT.md) dan [privasi EN/ID](privacy.md). Jika ada kolom **Privacy Policy URL**, pakai [halaman privasi di main](https://github.com/projekpod/velokity-space-nonogram/blob/main/docs/privacy.md) setelah merge dan pastikan bisa dibuka tanpa login.
5. Isi penilaian usia berdasarkan isi aktual. Target kesesuaian internal adalah **PEGI 12 / IGRS 3+**. Cantumkan klasifikasi resmi hanya setelah diterbitkan oleh lembaga atau portal yang berwenang. Deskripsi publik memakai “untuk semua kalangan”.

## 1. itch.io

1. Buka [New project](https://itch.io/game/new). Isi **Title** dengan `Velokity: Space Nonogram`, **Project URL** dengan `velokity-space-nonogram` jika tersedia, **Short description** dari teks EN, **Classification** dengan **Games**, **Kind of project** dengan **HTML**, dan **Release status** dengan **Released** saat siap terbit.
2. Di **Pricing**, pilih opsi gratis dengan donasi opsional jika diinginkan. Di **Uploads**, unggah `velokity-itch.zip` dan centang **This file will be played in the browser**.
3. Di **Embed options**, pilih **Click to launch in fullscreen** dan centang **Mobile Friendly**. Di **Details**, tempel **Long description** dan **Controls** EN, lalu versi ID. Tambahkan [Traktir Velokity](https://trakteer.id/velokity_project) dan tautan privasi ke teks halaman.
4. Pilih **Genre** → **Puzzle**. Isi **Tags** dari teks EN. Unggah `itch-cover.jpg` di **Cover image** dan empat file `gameplay-*.png` di **Screenshots**.
5. Simpan **Visibility & access** sebagai **Draft**. Buka pratinjau. Jika screenshot tersembunyi, buka **Edit theme** dan aktifkan kolom screenshot. Ubah visibilitas ke **Public** setelah cek selesai.

**Cek sebelum terbit**

- [ ] Launcher membuka Moon 01 di browser baru. Panduan bisa dilewati dan menu muncul setelah puzzle pertama.
- [ ] Sentuhan, suara setelah input, dan save setelah muat ulang bekerja di pratinjau. Cek potret dan lanskap.
- [ ] Cover, screenshot, teks EN/ID, privasi, dan tautan Traktir tampil di halaman publik.

[Dokumentasi unggah dan embed itch.io](https://itch.io/docs/creators/html5) · [Pengaturan halaman itch.io](https://itch.io/docs/creators/getting-started)

### Update an existing itch.io page

1. Buka **Edit game → Uploads** dan hapus ZIP build lama.
2. Unggah `velokity-itch.zip` yang diekstrak dari artefak GitHub. **Pilih ZIP yang berisi `index.html` di akarnya. ZIP pembungkus artefak GitHub hanya berisi ZIP build.**
3. Pastikan **This file will be played in the browser** tetap dicentang, lalu klik **Save**.

## 2. Playgama

1. Buka [Playgama Developer](https://developer.playgama.com/) → **Add Game**. Isi **Title** dengan judul EN, **Game Engine** dengan **Godot**, **Game Archive** dengan `velokity-itch.zip`, **Description** dengan deskripsi singkat EN, dan **How to play** dengan kontrol EN.
2. Di **Supported Devices**, pilih desktop dan perangkat seluler yang lulus **Test Game**. Di **Screen Orientation**, pilih potret dan lanskap. Di **Game Features**, pilih puzzle satu pemain jika tersedia. Di **Game Languages**, pilih **English** dan **Indonesian**. Tambahkan teks ID bila form menyediakan lokal tambahan.
3. Di **Media**, unggah `icon.png`, tiga cover `crazygames-*.jpg`, empat screenshot `gameplay-*.png`, dan kedua MP4 jika kolomnya tersedia. Isi **Link** dengan URL halaman itch.io yang sudah terbit.
4. Di **Distribution**, pilih Playgama dan keluarkan CrazyGames serta GameDistribution jika muncul. Kedua portal tersebut punya pengajuan langsung di langkah selanjutnya. Pilih **Save as Draft**, lalu **Test Game**.

**Cek sebelum Submit Game**

- [ ] Moon 01 terbuka langsung di sesi baru. Muat ulang setelah menang memperlihatkan menu dan progres yang sama. Ulang di potret, lanskap, dan jendela persegi.
- [ ] Cek sinyal `game_ready` dan gameplay, pilihan bahasa, suara saat pindah tab, serta kasus iklan berhasil, gagal, dan ditutup. Banner harus hilang di potret dan di bawah 600 CSS px.
- [ ] Cek bahwa Bridge Storage memulihkan progres setelah reload dan memilih bahasa portal hanya jika pemain belum memilih bahasa. Cek status mute/pause portal, pindah tab, dan jeda interstitial 90 detik di Bridge.
- [ ] Setelah QA Tool dan persyaratan di atas beres, pilih **Submit Game**.

[Panduan unggah Playgama](https://wiki.playgama.com/playgama/submitting-a-game) · [Langkah wajib Bridge](https://wiki.playgama.com/playgama/bridge-sdk/api#required-steps) · [Self-check Playgama](https://wiki.playgama.com/playgama/game-requirements/game-self-check)

## 3. CrazyGames Basic Launch

1. Buka [CrazyGames Developer Portal](https://developer.crazygames.com/) → **Submit a game**. Pilih jalur **Basic Launch**. Di **Game files**, unggah `velokity-itch.zip`. Jika dialog meminta folder atau file individual, ekstrak arsip dan unggah semua file dengan `index.html` sebagai entry point.
2. Isi **Game title** dengan judul EN, **Description** dengan deskripsi panjang EN, **Controls** dengan kontrol EN, dan **Category** dengan **Puzzle**. Jika tersedia, pilih tag EN yang cocok dari daftar portal, bahasa English dan Indonesian, serta **Desktop** dan **Mobile** dengan kedua orientasi.
3. Isi **Landscape cover** dengan `crazygames-landscape.jpg` (1920×1080), **Portrait cover** dengan `crazygames-portrait.jpg` (800×1200), dan **Square cover** dengan `crazygames-square.jpg` (800×800). Unggah `preview-landscape.mp4` dan `preview-portrait.mp4` ke slot video sesuai orientasi.
4. Buka **Preview** atau QA Tool pada draf. Kirim ke **Basic Launch** setelah semua cek lulus. Monetisasi Basic Launch dinonaktifkan oleh CrazyGames.

**Cek sebelum submit**

- [ ] Sesi baru langsung menampilkan Moon 01. Langkah tutorial pertama muncul sambil papan bisa dimainkan. Tombol lewati, X, dan petunjuk angka bekerja.
- [ ] Ukuran initial download di QA Tool di bawah 50 MB. SDK mengenali gameplay pertama. Uji mouse, sentuhan, serta muat ulang setelah menang.
- [ ] Tidak ada iklan atau tautan Traktir di dalam embed Basic Launch. Judul terbaca pada ketiga cover dan masing-masing video diputar penuh.

[Persyaratan teknis CrazyGames](https://docs.crazygames.com/requirements/technical/) · [Cover dan video](https://docs.crazygames.com/requirements/game-covers/) · [Basic Launch](https://docs.crazygames.com/resources/basic-launch-metrics/)

## 4. GameDistribution

1. Masuk dari [halaman GameDistribution Developer](https://gamedistribution.com/developers/). Buat entri game dan salin **Game ID**. Nama menu dan label pengunggahan pada dashboard login bisa berbeda dari label di bawah.
2. Isi **Title** dengan judul EN, **Description** dengan deskripsi panjang EN, **Instructions** dengan kontrol EN, **Category** dengan **Puzzle**, dan **Tags** dari teks EN. Pilih English sebagai bahasa utama dan tambahkan Indonesian jika tersedia. Pilih desktop dan mobile serta kedua orientasi yang lulus QA.
3. Di **Thumbnails**, unggah `gamedistribution-square.jpg` (512×512), `gamedistribution-standard.jpg` (512×384), dan `gamedistribution-small.jpg` (200×120). Tambahkan screenshot dan video bila tersedia. Tautan rilis lain, jika diminta, masuk ke **Backlinks**.
4. Untuk **Game files**, siapkan nama arsip `velokity-gamedistribution.zip` dengan `index.html` di akar. Setelah konflik iklan selesai, tim build memasukkan Game ID di `platforms.game_distribution.gameId` pada `playgama-bridge-config.json` di salinan ekspor Web dan membuat arsip portal dengan `python3 tools/package_itch.py <folder-ekspor> build/velokity-gamedistribution.zip`. Unggah arsip itu ke draf dan jalankan QA portal.

**Cek sebelum submit**

- [ ] Dapatkan konfirmasi dari GameDistribution bahwa build boleh berjalan tanpa preroll. Adapter Bridge v2.4.4 memanggil interstitial pada `SDK_READY` saat Game ID diisi. Tahan pengajuan sampai QA portal mengonfirmasi interstitial diajukan pada jeda hasil, dengan pacing yang dikelola Bridge.
- [ ] SDK terhubung dengan Game ID yang benar. Banner hilang di potret dan di viewport sempit. Rewarded memberi hadiah sekali setelah selesai. Audio dan input pulih saat iklan tutup.
- [ ] Uji sesi baru, muat ulang save, potret serta lanskap, bahasa Inggris, dan tiadanya tautan keluar yang dilarang. Semua thumbnail sesuai ukuran. Kirim ke QA setelah cek lulus.

[GameDistribution Developer](https://gamedistribution.com/developers/partnership/) · [Pedoman pengembang](https://static.gamedistribution.com/developer/developers-guidelines.html) · [Ukuran thumbnail](https://gamedistribution.com/developers/faq/general-questions/what-are-the-requirements-for-the-thumbnails/)

## Android untuk tahap berikutnya

Preset **Android** menghasilkan AAB arm64 dengan package `com.projekpod.velokity` dan target API 36. Di Godot 4.7.2, siapkan Java dan Android SDK, lalu pilih **Project → Install Android Build Template**. Isi signing key lokal melalui preset dan simpan di luar repo. Ekspor ke `build/android/velokity.aab` dan uji di perangkat sebelum upload. [Panduan Android Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)
