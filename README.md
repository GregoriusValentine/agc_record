
# AGC Record
Aplikasi Perekaman Suara, menggunakan algoritma Automatic Gain Control sebagai pemrosesan audio yang diterapkan di cloud server.

|No|Nama|Dokumentasi|
|--|--|---|
|1|Flutter|<a  href="https://docs.flutter.dev/" target="_blank">Lihat</a>|
|2|Dart|<a  href="https://dart.dev/docs"  target="_blank">Lihat</a>|

## 🗂️ Struktur Folder Utama
```
project_root/
├── assets/
│   ├── animation/
│   └── images/                    
│       ├── logo_agc_record.png       # Gambar Logo Aplikasi
│       ├── logo_agc_record-2.png     # ...
│       └── logo_agc_record-3.png     # ...
├── lib/
│   ├── pages/
│   │   ├── agc_result.dart           # Tampilan Menu Hasil Pemrosesan Audio
│   │   ├── fade_page_route.dart      # Mengatur Perpindahan Halaman
│   │   ├── recording_result.dart     # Tampilan Menu Hasil Rekaman
│   │   └── recording.dart            # Tampilan Menu Rekaman
│   ├── widgets/
│   │   └── bottom_nav.dart           # Menu Navigasi
│   ├── main.dart                     # App entry point
│   └── splash_screen.dart            # Loading aplikasi
├── README.md                         # Dokumentasi proyek ini
└── ...
```
## Fitur Utama
 1. Perekaman Suara
 2. Pengriman Suara Audio Menuju Cloud Server
 4. Hasil Pengelolaan Audio
## Tampilan Aplikasi
<div style="display: flex; justify-content: center; gap: 50px;">
  <img src="screenshots/Screenshot-1.jpg" alt="Perekaman Suara" width="200" />
  <img src="screenshots/Screenshot-5.jpg" alt="Hasil Rekaman Suara" width="200" />
  <img src="screenshots/Screenshot-6.jpg" alt="Hasil Pengelolaan AGC" width="200" />
</div>
Untuk Menampilkan Hasil Audio Secara Detail dapat mengakses <a  href="https://agcrecord.batutech.cloud/"  target="_blank">Hasil Pemrosesan Audio</a>

## 🔁Alur Fungsional Menu

> Diagram berikut menjelaskan alur pengguna dalam mengakses, memutar,
> menghapus, atau mengirim hasil rekaman.

 1. Menu perekaman Suara
```mermaid
flowchart TD
    A([Mulai])
    B[Pengguna Membuka Menu Perekaman Suara]
    C[Sistem Menampilkan Halaman Perekaman]
    D{Apakah Pengguna Menekan Tombol Rekam?}
    E([Selesai])
    F[Sistem Merekam Suara]
    G{Apakah di Jeda/Simpan/Batal?}
    H([Selesai])
    I[Perekaman Dalam Status Jeda]
    J{Apakah di Lanjut/Simpan/Batal?}
    K([Selesai])
    A --> B --> C --> D
    D -- Tidak --> E
    D -- Ya --> F --> G
    G -- Simpan/Batal --> H
    G -- Jeda --> I --> J
    J -- Lanjut --> F
    J -- Simpan/Batal --> K
```
2. Hasil Rekaman
```mermaid
flowchart TD
    A([Mulai])
    B[Pengguna Membuka Menu Hasil Rekaman]
    C[Sistem Menampilkan Daftar Rekaman]
    D[Pengguna Memilih Audio]
    E{Apakah di Putar/Kirim/Hapus?}
    F1[Sistem Memutar Audio]
    F2[Sistem Menghapus Audio]
    F3[Sistem Mengirim Audio]
    G1([Selesai])
    G2([Selesai])
    G3([Selesai])
    H{Apakah Berhasil?}
    I[Sistem Menampilkan Pesan Berhasil]
    J([Selesai])

    A --> B --> C --> D --> E
    E -- Putar --> F1 --> G1
    E -- Hapus --> F2 --> G2
    E -- Kirim --> F3 --> H
    H -- Ya --> I --> G3
    H -- Tidak --> J
```
 3. Hasil Pengelolaan AGC
```mermaid
flowchart TD
    A([Mulai])
    B[Pengguna Membuka Menu Hasil AGC]
    C[Sistem Memuat Data Dari Server]
    D{Apakah Berhasil Memuat Data?}
    E1[Sistem Menampilkan Pesan Error]
    F1([Selesai])
    E2[Sistem Menampilkan Data]
    G{Apakah di Putar/Hapus?}
    H1[Sistem Memutar Audio]
    H2[Sistem Menghapus Audio]
    F2([Selesai])
    F3([Selesai])
    A --> B --> C --> D
    D -- Tidak --> E1 --> F1
    D -- Ya --> E2 --> G
    G -- Putar --> H1 --> F2
    G -- Hapus --> H2 --> F3
```
## Requirements
 -  Flutter (version 3.19.0 or higher)
-   Dart (version 3.3.0 or higher)
-   Android Studio / VS Code
-   Android SDK (for Android deployment)
-   Xcode (for iOS deployment)
## 🛠️ Langkah-langkah Inisialisasi Proyek
### 1. Clone Repositori
```bash
git  clone  https://github.com/GregoriusValentine/agc_record.git
cd agc_record
```
### 2. Install Dependencies
```bash
flutter pub get
```
### 3. Jalankan Aplikasi
```bash
flutter run
```
Untuk perangkat tertentu:
```bash
flutter run -d chrome       # Untuk web
flutter run -d macos        # Untuk macOS
flutter run -d <device-id>  # Untuk Perangkat Spesifik
```
### 4. Untuk Produksi
Android
```bash
flutter build apk --release
# Atau
flutter build appbundle --release
```
iOS
```bash
flutter build ios --release
```
Lalu arsipkan dan unggah menggunakan Xcode.
### 🫱🏼‍🫲🏼5. Berkontribusi
Alur Kerja
```bash
# Fork repository melalui GitHub UI

# Clone fork Anda
git clone https://github.com/GregoriusValentine/agc_record.git
cd agc_record

# Tambahkan remote upstream
git remote add upstream https://github.com/GregoriusValentine/agc_record.git

# Buat branch fitur baru
git checkout -b [nama_branch_fitur]

# Buat perubahan kode menggunakan editor Anda
# Tambahkan perubahan dan commit
git add .
git commit -m 'Add user authentication screens and logic' #sesuaikan

# Sinkronkan dengan upstream sebelum push
git fetch upstream
git rebase upstream/main

# Push ke GitHub
git push -u origin [nama_branch_fitur]

# Buat Pull Request melalui GitHub UI
```


## 📄 Lisensi
> Proyek ini merupakan bagian dari Tugas Akhir dan tidak digunakan untuk
> tujuan komersial. Anda bebas memodifikasi dan mengembangkan ulang
> dengan menyertakan atribusi.
