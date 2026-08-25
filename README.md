# Buku Laris — Aplikasi Manajemen UMKM

Aplikasi mobile (Android & iOS) untuk pencatatan bisnis UMKM berbasis **workspace**: produk fisik/digital, jasa & layanan, pre-order, kas masuk/keluar, pelanggan, laporan, karyawan dengan dua role (`OWNER` dan `EMPLOYEE`), dibangun di atas **Flutter + Firebase Authentication + Cloud Firestore**.

---

## Daftar Isi
1. [Arsitektur](#arsitektur)
2. [Struktur Folder](#struktur-folder)
3. [Desain Data Firestore](#desain-data-firestore)
4. [Konfigurasi Project Firebase](#konfigurasi-project-firebase)
5. [Firebase Authentication](#firebase-authentication)
6. [Firestore Security Rules & Indexes](#firestore-security-rules--indexes)
7. [Menjalankan Development](#menjalankan-development)
8. [Firebase Emulator & Testing](#firebase-emulator--testing)
9. [Environment Configuration](#environment-configuration)
10. [Build Release Android / iOS](#build-release-android--ios)
11. [Alur Aplikasi & Aturan Bisnis Penting](#alur-aplikasi--aturan-bisnis-penting)

---

## Arsitektur

Feature-first architecture dengan pemisahan lapisan:

```
UI (features/*/screens)  →  Controllers (Riverpod Notifier/Stream)  →  Repositories  →  Cloud Firestore
                                                        ↑
                                        Services (auth, image, connectivity, demo-seed)
```

- **State management:** `flutter_riverpod` (Riverpod 3) secara konsisten di seluruh aplikasi.
  - `GateController` — mesin status auth-gate: `loading → signedOut → hasInvitations → needsOnboarding → ready`.
  - `activeWorkspaceProvider` — workspace aktif + membership (role & permission).
  - UI tidak pernah memanggil Firestore langsung; hanya melalui repository.
- **Multi-tenancy:** seluruh data bisnis hidup di bawah `workspaces/{workspaceId}/...` sehingga query, rules, dan pagination bekerja per-tenant.
- **Konsistensi:** operasi sensitif memakai `runTransaction` (penjualan + stok + counter nomor transaksi + ringkasan harian dalam satu atomic op) atau `WriteBatch` (pembuatan workspace, hapus cascade).

## Struktur Folder

```
lib/
├── main.dart                  # bootstrap Firebase, locale id_ID, ProviderScope
├── app.dart                   # MaterialApp.router + error boundary global
├── firebase_options.dart      # konfigurasi Firebase (Android dari google-services.json)
├── config/
│   ├── providers.dart         # DI: service & repository providers
│   ├── gate.dart              # auth/workspace gate state machine
│   └── router.dart            # go_router + redirect berbasis gate
├── core/
│   ├── constants/             # nama koleksi, batasan, katalog (jenis usaha, kategori kas, timezone)
│   ├── errors/app_exception.dart   # penerjemah error Firebase → Bahasa Indonesia
│   ├── theme/app_theme.dart   # Material 3 theme
│   ├── utils/                 # formatter Rupiah/tanggal id_ID, validator form, debug utils
│   └── widgets/common.dart    # StatCard, EmptyState, ErrorStateView, skeleton,
│                              # PagedListView (cursor-based lazy loading), QtyStepper, dialog
├── models/                    # UserProfile, Workspace(+Settings), WorkspaceMember, Invitation,
│                              # Product, ProductCategory, StockMovement, Customer, Sale(+SaleItem),
│                              # CashTransaction, PaymentMethodModel, NotificationModel, AuditLog,
│                              # DailySummary + semua enum (role, permission, order type, dst.)
├── repositories/              # akses Firestore: user, workspace, membership, invitation,
│                              # product, category, stock, customer, sale (atomic),
│                              # cashflow, dashboard (aggregate), report, audit, notification
├── services/                  # AuthService (email/password + Google), ImageService (kompresi),
│                              # ConnectivityService, DemoDataService (seed data dev)
└── features/
    ├── auth/                  # login, register, lupa password
    ├── onboarding/            # wizard 3 langkah pembuatan usaha
    ├── workspace/             # personal-workspace state (ex-employee)
    ├── invitations/           # layar terima/tolak undangan
    ├── dashboard/             # dashboard owner (metrik + grafik) & employee (ringkas)
    ├── products/              # list, form, detail + histori stok, kategori
    ├── inventory/             # stok menipis
    ├── sales/                 # POS keranjang, pre-order, daftar, detail + invoice share
    ├── customers/             # CRUD pelanggan + histori transaksi
    ├── cashflow/              # uang masuk/keluar + form bottom-sheet
    ├── reports/               # laporan penjualan, kas, stok, pre-order (+ grafik fl_chart)
    ├── employees/             # manajemen karyawan, permission, undangan
    ├── settings/              # pengaturan usaha, metode bayar, konfigurasi, zona berbahaya
    ├── notifications/         # notifikasi internal per-user
    ├── more/                  # menu Lainnya (bottom nav ke-5)
    └── shared/widgets/        # bottom navigation & quick actions
```

## Desain Data Firestore

```
users/{uid}
  uid, email, displayName, photoUrl, phoneNumber
  workspaceIds[]                # denormalisasi untuk resolusi cepat membership
  activeWorkspaceId             # workspace terakhir dipakai
  notifications/{notifId}       # subcollection notifikasi internal

workspaces/{wsId}
  ownerId, name, businessType, businessCategory, description
  businessModels[]              # physicalProduct | digitalProduct | service | layanan | preOrder
  whatsappNumber, address, logoUrl(dataURI terkompresi), currency, timezone
  status (ACTIVE|ARCHIVED), personalWorkspace (bool)
  settings { allowOverselling, requireCustomerForSale, taxPercent,
             preOrder{ enabled, requireEstimatedDate, deductStockOnConfirm },
             invoice{ footerNote } }
  createdAt, updatedAt (serverTimestamp)
  ├─ members/{uid}              role OWNER|EMPLOYEE, permissions[], status, joinedAt…
  ├─ products/{id}              tipe item, harga modal/jual, stok/minStock, unlimited, licenseCount…
  ├─ categories/{id}            kategori produk (opsional parentId utk subkategori)
  ├─ stockMovements/{id}        ledger immutable: reason, qtyChange(±), before→after
  ├─ sales/{id}                 transactionNumber, orderType READY_STOCK|PRE_ORDER, items[],
  │                             subtotal/diskon/pajak/ongkir/grandTotal, paidAmount,
  │                             paymentStatus, status + statusHistory[], countsRevenue,
  │                             stockDeducted, offlineCreated
  ├─ cashTransactions/{id}      INCOME|EXPENSE, category, amount, occurredAt,
  │                             sourceSaleId (tautan ke penjualan), sourceType
  ├─ paymentMethods/{id}        name, type, isActive, sortOrder (dikelola Owner)
  ├─ counters/sales             { seq } → nomor transaksi TRX-YYYYMMDD-0001 (transaction-increment)
  ├─ dailySummaries/YYYY-MM-DD  revenue/orderCount/estimatedProfit/cashIn/cashOut (denormalisasi;
  │                             sumber kebenaran tetap koleksi sales & cashTransactions)
  └─ auditLogs/{id}             append-only, dibaca Owner

invitations/{id}                (top-level; bisa dicari by invitedEmail+status)
  workspaceId, ownerId, invitedEmail(lowercase), invitedUserId?, role EMPLOYEE,
  status PENDING|ACCEPTED|REJECTED|EXPIRED|REVOKED, token, createdAt/expiresAt/acceptedAt/...
```

**Keputusan penting desain:**
- Subcollection per workspace → rules per-dokumen sederhana, index composite minim, biaya query proporsional.
- `dailySummaries` = strategi denormalisasi agar dashboard & grafik membaca ≤31 dokumen/halaman alih-alih memindai ribuan transaksi.
- `countsRevenue` (bool) pada sales membuat aggregate sum() cukup satu filter tanpa `whereIn` status.
- Snapshot harga modal & kategori disimpan di tiap `SaleItem` → histori laporan tidak berubah saat produk diedit.

## Konfigurasi Project Firebase

Project aktif: **buku-laris** (config Android sudah tertanam di `android/app/google-services.json` dan `lib/firebase_options.dart`).

1. Buat project di [Firebase Console](https://console.firebase.google.com) (atau pakai existing `buku-laris`).
2. Tambahkan aplikasi Android dengan package `com.example.buku_laris`, download `google-services.json` → simpan di `android/app/`.
3. Untuk iOS: jalankan `dart pub global activate flutterfire_cli` lalu `flutterfire configure`, atau tambahkan app iOS secara manual dan letakkan `GoogleService-Info.plist` di `ios/Runner/` (via Xcode). `lib/firebase_options.dart` saat ini hanya berisi Android; generate ulang dengan `flutterfire configure` untuk menambah iOS/web.
4. Aktifkan **Cloud Firestore** (mode production) dan set region sesuai kebutuhan (mis. asia-southeast2).

## Firebase Authentication

Di Console → **Authentication → Sign-in method**, aktifkan:

1. **Email/Password** — dipakai register/login biasa.
2. **Google** — wajib menambahkan **SHA-1** (dan SHA-256) debug/release:
   ```powershell
   cd android ; .\gradlew signingReport ; cd ..
   ```
   Masukkan SHA-1 di *Project Settings → Android app → Add fingerprint*, lalu **download ulang google-services.json** dan ganti file di `android/app/`. Tanpa ini, tombol Google akan gagal dengan pesan yang dijelaskan di UI.
3. Opsional: isi Web Client ID lewat dart-define (lihat [Environment Configuration](#environment-configuration)) untuk memperkuat alur token Google.

**Persistence sesi** sudah default Firebase Auth di mobile (sesi bertahan antar buka-tutup app). Tidak ada session timeout internal — user hanya login ulang setelah logout manual, hapus akun, disable di console, atau reauth yang diminta sistem (hapus akun).

## Firestore Security Rules & Indexes

File:
- `firestore.rules` — deploy dengan:
  ```powershell
  firebase deploy --only firestore:rules
  ```
- `firestore.indexes.json` — deploy dengan:
  ```powershell
  firebase deploy --only firestore:indexes
  ```

Ringkasan model keamanan:
- Semua akses data workspace diverifikasi lewat dokumen `workspaces/{wsId}/members/{uid}` (bukan field di users/client).
- `OWNER` = kontrol penuh; `EMPLOYEE` hanya akses sesuai array `permissions`. Permission granular: `productsView, productsManage, categoriesManage, stockAdjust, preorderManage, salesCreate, salesEditStatus, salesRecordPayment, customersManage, cashflowManage, reportsSalesView, reportsFinanceView, dashboardView`.
- Karyawan dilarang mengubah `ownerId`, `role`, membership, invitation, `transactionNumber`, `createdAt`, `sellerId`; update sales dibatasi whitelist field.
- Terima undangan = batch {invitation→ACCEPTED, create member EMPLOYEE dengan permission default persis, update user}; rules memvalidasi via `getAfter()` sehingga atomik & tak bisa dipalsukan.
- `stockMovements` immutable; `auditLogs` create-only; sales tidak bisa dihapus dari client.
- Setiap index composite di `firestore.indexes.json` diberi keterangan `why` yang menjelaskan query yang membutuhkannya.

## Menjalankan Development

```powershell
flutter pub get
flutter run                       # device/emulator Android terpasang
flutter run -t lib/main.dart
```

Perintah rutin:
```powershell
flutter analyze                   # harus "No issues found!"
flutter test                      # unit + widget test
```

Data contoh (khusus mode debug): centang *"Isi dengan data contoh"* di wizard onboarding, atau **Pengaturan → Zona Berbahaya → Isi Data Contoh (Dev)** — memilih template toko fisik / digital / servis / kombinasi lalu menghasilkan produk, pelanggan, ±100 transaksi 60 hari, kas bulanan, sehingga seluruh halaman & laporan terisi realistis. Seeder menulis ke Firestore sungguhan, bukan data hardcode di UI.

## Firebase Emulator & Testing

```powershell
npm install -g firebase-tools
firebase init emulators           # pilih Auth + Firestore
firebase emulators:start
```

Jalankan suite integrational (opsional) yang menarget emulator:
```powershell
$env:FLUTTER_TEST_EMULATOR="1"; $env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"; $env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
flutter test test/integration
```

Test yang tersedia:
- `test/formatters_test.dart` — format Rupiah `Rp1.500.000`, singkatan `Rp1,5jt`, tanggal `id_ID`.
- `test/validators_test.dart` (tercakup di formatters_test) — email, password ≥8 huruf+angka, nominal >0, WhatsApp Indonesia.
- `test/models_test.dart` — serialisasi SaleItem/Sale/Customer/DailySummary, aturan low-stock & overselling, kategori kas.
- `test/widget_test.dart` — smoke test halaman login.
- `test/integration/firestore_flow_test.dart` — (guard `FLUTTER_TEST_EMULATOR`) alur end-to-end: registrasi → buat workspace → invite → terima → jual ready-stock & pre-order → kas → keluarkan karyawan → validasi rules.

## Environment Configuration

Tidak ada secret di kode selain API key Firebase publik (memang dirancang demikian oleh Firebase). Opsi runtime via dart-define:

```powershell
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com
```

| Key | Default | Fungsi |
|---|---|---|
| `GOOGLE_WEB_CLIENT_ID` | kosong | serverClientId untuk Google Sign-In v7 (idToken). Wajib jika ingin idToken tanpa bergantung pada oauth_client di google-services.json |

Logging (`Logger`) hanya mencetak pada `kDebugMode`; produksi tidak mencetak data sensitif.

## Build Release Android / iOS

**Android**
```powershell
keytool -genkey -v -keystore %USERPROFILE%\bukularis-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bukularis
```
Buat `android/key.properties` (jangan di-commit):
```properties
storePassword=***  keyPassword=***  keyAlias=bukularis
storeFile=C:/Users/<Anda>/bukularis-release.jks
```
Daftarkan SHA-1 release ke Firebase Console → download ulang `google-services.json`. Lalu:
```powershell
flutter build apk --release          # APK
flutter build appbundle --release    # Play Store
```

**iOS** (macOS + Xcode):
```bash
flutter build ios --release
# signing di Xcode → Runner → Signing & Capabilities (Team + Bundle ID)
```
Tambahkan `GoogleService-Info.plist` dan URL scheme `REVERSED_CLIENT_ID` di `Info.plist` untuk Google Sign-In iOS.

## Alur Aplikasi & Aturan Bisnis Penting

1. **Auth Gate** — splash → belum login → Login/Register; login → profil dibuat otomatis (`users/{uid}`).
2. **Undangan aktif?** → layar Undangan lebih dulu (terima = menjadi EMPLOYEE; tolak = kembali ke pilihan).
3. **Tanpa workspace** → wizard onboarding (info usaha → model bisnis → metode bayar) → workspace dibuat, user menjadi OWNER, masuk dashboard.
4. **Employee lifecycle** — dikeluarkan Owner: membership `REMOVED`, akun tetap ada; saat login berikutnya masuk *personal workspace state* dan boleh membuat usaha sendiri. Untuk menerima undangan baru dari workspace lama, ia harus **menghapus workspace pribadinya dulu** (konfirmasi berlapis + ketik nama usaha + cascade delete terkontrol per-subcollection dengan progress). Akun Auth tidak pernah dihapus oleh proses ini.
5. **Ready-stock sale** — transaksi memverifikasi stok terbaru via transaction; stok kurang → ditolak kecuali Owner mengaktifkan overselling. Nomor transaksi, pengurangan stok, ledger gerakan, catatan kas, statistik pelanggan, dan ringkasan harian ditulis **atomik**.
6. **Pre-order** — stok tidak dicek saat order; dikurangi saat masuk `PROCESSING` (atau `CONFIRMED` jika dikonfigurasi); DP dicatat sebagai kas masuk kategori "Pembayaran DP".
7. **Offline** — jika transaksi gagal karena jaringan, otomatis disimpan sebagai DRAFT `offlineCreated` tanpa menyentuh stok; detail transaksi menampilkan banner dan tombol **Proses Stok** untuk finalisasi atomik saat online. Indikator offline tampil di app bar.
8. **Laporan** — dihitung dari agregasi + dailySummaries; laba ditandai *estimasi* bila ada produk tanpa harga modal (dijelaskan di UI).
