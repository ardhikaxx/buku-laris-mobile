# RULE-BUKU-LARIS.md
## Dokumen Arsitektur & Blueprint Sistem — Aplikasi "Buku Laris"

> **Tagline:** Satu aplikasi untuk mengelola usaha, dari transaksi sampai laporan.
> **Kategori:** Aplikasi Mobile Operasional Bisnis UMKM (Point of Sale + Manajemen Bisnis)

---

## DAFTAR ISI

1. Ringkasan & Filosofi Produk
2. Teknologi & Stack Resmi
3. Arsitektur Aplikasi (Layered Architecture)
4. Struktur Folder Project
5. Konvensi Kode & Penamaan
6. Sistem Akun & Autentikasi
7. Aturan Utama: Satu Akun — Satu Usaha — Isolasi Data
8. Model Pembayaran Sekali Bayar
9. Alur Onboarding Usaha
10. Struktur Database Cloud Firestore
11. Firestore Security Rules
12. State Management — Pola Riverpod
13. Modul: Dashboard
14. Modul: Produk
15. Modul: Jasa
16. Modul: Kategori
17. Modul: POS / Transaksi Penjualan
18. Modul: Pelanggan
19. Modul: Supplier & Pembelian
20. Modul: Inventory / Manajemen Stok
21. Modul: Pengeluaran
22. Modul: Hutang & Piutang
23. Modul: Laporan & Analitik
24. Modul: Karyawan & Role-Based Access Control
25. Sistem Notifikasi (FCM + In-App)
26. Sistem Offline & Sinkronisasi Data
27. Export, Cetak Struk, & Share
28. Audit Log
29. Exception Handling & Error Strategy
30. Routing (go_router) & Navigasi
31. Testing Strategy
32. Roadmap Pengembangan (MVP → Fase Lanjutan)
33. Prinsip Non-Negosiasi Arsitektur

---

## 1. RINGKASAN & FILOSOFI PRODUK

Buku Laris adalah aplikasi mobile operasional bisnis untuk pelaku UMKM Indonesia — baik yang berjualan **barang**, **jasa**, maupun **kombinasi keduanya**. Aplikasi ini **bukan ERP besar**. Posisinya adalah:

> Aplikasi operasional sederhana untuk mengelola seluruh aktivitas bisnis UMKM (transaksi, stok, keuangan sederhana, hutang-piutang, dan laporan) dalam satu aplikasi yang mudah dipahami tanpa pelatihan khusus.

Prinsip produk:

- **Simple** — UI tidak boleh terasa rumit bagi pengguna yang belum pernah pakai aplikasi bisnis apa pun.
- **Modular** — Setiap modul (produk, jasa, POS, stok, dsb.) berdiri sendiri secara kode, tapi terintegrasi secara data.
- **Scalable** — Struktur data & arsitektur harus tetap kuat dipakai baik oleh warung kecil (1 produk, 1 orang) maupun usaha menengah (ratusan produk, beberapa karyawan).
- **Secure & Isolated** — Data antar usaha (`businessId`) tidak boleh pernah saling terlihat.
- **Offline-first mindset** — Transaksi harus tetap bisa dilakukan meski sinyal buruk.
- **Data-driven** — Setiap layar penting harus memberi insight, bukan sekadar daftar data mentah.
- **One Business per Account** — Satu akun pemilik = satu usaha. Karyawan adalah pengguna tambahan di usaha yang sama, bukan pemilik usaha baru.

---

## 2. TEKNOLOGI & STACK RESMI

| Layer | Teknologi |
|---|---|
| Framework | Flutter (Dart, null-safety) |
| State Management | Riverpod (`flutter_riverpod` + `riverpod_annotation` / code generation) |
| Routing | `go_router` |
| Backend | Firebase (serverless, tanpa backend kustom di MVP) |
| Autentikasi | Firebase Authentication (Email & Password, Google Sign-In) |
| Database | Cloud Firestore (NoSQL, realtime, offline persistence built-in) |
| File Storage | Firebase Storage (foto produk, logo usaha, bukti pembayaran, foto bukti pengeluaran) |
| Cloud Logic | Firebase Cloud Functions (untuk operasi sensitif: verifikasi pembayaran, agregasi laporan berat, notifikasi terjadwal) |
| Push Notification | Firebase Cloud Messaging (reminder hutang/piutang, stok menipis, jatuh tempo) |
| Model & Serialization | `freezed` + `json_serializable` |
| Local Cache Tambahan | Firestore offline persistence (native) — tidak menggunakan Hive/SQLite di MVP agar arsitektur tetap sederhana |
| Format Angka/Tanggal | `intl` |
| PDF | `pdf` + `printing` (Dart package, bukan Laravel dompdf karena project ini Flutter) |
| Excel/CSV | `excel` / `csv` package |
| Cetak Thermal | `esc_pos_bluetooth` atau `blue_thermal_printer` (fase lanjutan) |
| Barcode Scanner | `mobile_scanner` (fase lanjutan) |

Tidak menggunakan backend custom (Node.js/Laravel) di MVP. Semua logika bisnis kritikal (hitung stok, hitung laporan, verifikasi pembayaran) dijalankan lewat kombinasi **Cloud Functions** (untuk operasi yang butuh trust server-side) dan **Repository layer di client** (untuk operasi baca/tulis biasa yang diamankan oleh Security Rules).

> **Aturan kritikal:** Operasi yang mengubah saldo/stok/status pembayaran secara sensitif (verifikasi pembayaran, penyesuaian stok besar, penghapusan transaksi) sebaiknya melalui Cloud Function agar tidak bisa dimanipulasi dari client meski Security Rules bocor.

---

## 3. ARSITEKTUR APLIKASI (LAYERED ARCHITECTURE)

```
Presentation (Widgets, Screens)
        ↓  membaca/memanggil
State Management (Riverpod Providers / Notifiers)
        ↓  memanggil
Repository (abstraksi domain, tidak tahu Firestore secara langsung)
        ↓  memanggil
Data Source / Service (implementasi konkret Firestore, Storage, FCM)
        ↓
Firebase (Firestore, Storage, Auth, Functions, FCM)
```

Aturan tegas:

- **Widget tidak boleh memanggil Firestore langsung.** Semua akses data lewat Repository via Provider.
- **Repository tidak boleh mengetahui detail UI** (tidak boleh return `Widget`, tidak boleh melempar `SnackBar`, dsb).
- **Model (`data/models`) adalah representasi murni data**, tidak menyimpan logic UI.
- **Business logic (perhitungan stok, perhitungan laporan, validasi hutang) tinggal di Repository atau Use Case**, bukan di dalam `build()` widget.
- Setiap fitur di `features/<nama_fitur>/` memiliki sub-struktur: `presentation/`, `application/` (providers/notifiers), `domain/` (jika perlu use case terpisah untuk logic kompleks seperti kalkulasi laporan), dan cukup referensi ke `data/repositories` global.

---

## 4. STRUKTUR FOLDER PROJECT

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart          # nama app, versi, batas trial
│   │   ├── firestore_paths.dart        # nama koleksi terpusat, single source of truth
│   │   ├── business_types.dart         # enum jenis usaha
│   │   └── payment_constants.dart      # nominal harga, status pembayaran
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   └── app_theme.dart
│   ├── routes/
│   │   ├── app_router.dart             # konfigurasi go_router
│   │   ├── route_names.dart
│   │   └── route_guards.dart           # guard auth, guard isPaid, guard onboarding
│   ├── utils/
│   │   ├── currency_formatter.dart
│   │   ├── date_formatter.dart
│   │   ├── debouncer.dart
│   │   └── connectivity_helper.dart
│   ├── validators/
│   │   ├── auth_validators.dart
│   │   ├── product_validators.dart
│   │   └── transaction_validators.dart
│   ├── services/
│   │   ├── firebase_auth_service.dart
│   │   ├── firestore_service.dart
│   │   ├── storage_service.dart
│   │   ├── fcm_service.dart
│   │   ├── connectivity_service.dart
│   │   ├── pdf_export_service.dart
│   │   ├── excel_export_service.dart
│   │   └── print_service.dart
│   └── exceptions/
│       ├── app_exception.dart
│       ├── auth_exception.dart
│       ├── firestore_exception.dart
│       └── business_rule_exception.dart
│
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── business_model.dart
│   │   ├── product_model.dart
│   │   ├── service_model.dart
│   │   ├── category_model.dart
│   │   ├── customer_model.dart
│   │   ├── supplier_model.dart
│   │   ├── transaction_model.dart
│   │   ├── transaction_item_model.dart
│   │   ├── stock_movement_model.dart
│   │   ├── expense_model.dart
│   │   ├── debt_model.dart
│   │   ├── receivable_model.dart
│   │   ├── employee_model.dart
│   │   ├── payment_model.dart
│   │   ├── notification_model.dart
│   │   └── audit_log_model.dart
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── business_repository.dart
│   │   ├── product_repository.dart
│   │   ├── service_repository.dart
│   │   ├── category_repository.dart
│   │   ├── customer_repository.dart
│   │   ├── supplier_repository.dart
│   │   ├── transaction_repository.dart
│   │   ├── stock_repository.dart
│   │   ├── expense_repository.dart
│   │   ├── debt_repository.dart
│   │   ├── receivable_repository.dart
│   │   ├── employee_repository.dart
│   │   ├── payment_repository.dart
│   │   ├── report_repository.dart
│   │   └── audit_log_repository.dart
│   └── datasources/
│       ├── remote/                     # implementasi konkret akses Firestore/Storage
│       └── local/                      # (opsional fase lanjutan) cache lokal tambahan
│
├── features/
│   ├── auth/
│   │   ├── presentation/ (login_screen, register_screen, forgot_password_screen)
│   │   └── application/ (auth_provider.dart, auth_notifier.dart)
│   ├── onboarding/
│   │   ├── presentation/ (step1..step5 screens, onboarding_wrapper)
│   │   └── application/ (onboarding_notifier.dart)
│   ├── payment/
│   │   ├── presentation/ (payment_instruction_screen, upload_proof_screen, payment_status_screen)
│   │   └── application/ (payment_provider.dart)
│   ├── dashboard/
│   │   ├── presentation/
│   │   └── application/ (dashboard_provider.dart)
│   ├── business/
│   │   ├── presentation/ (business_profile_screen, business_settings_screen)
│   │   └── application/
│   ├── products/
│   ├── services/
│   ├── categories/
│   ├── sales/                          # modul POS
│   ├── customers/
│   ├── suppliers/
│   ├── inventory/
│   ├── expenses/
│   ├── debts/
│   ├── receivables/
│   ├── employees/
│   ├── reports/
│   └── settings/
│
├── shared/
│   ├── widgets/
│   │   ├── buku_button.dart
│   │   ├── buku_textfield.dart
│   │   ├── buku_card.dart
│   │   ├── empty_state_widget.dart
│   │   ├── error_state_widget.dart
│   │   ├── skeleton_loader.dart
│   │   └── currency_input_field.dart
│   ├── dialogs/
│   │   ├── confirmation_dialog.dart
│   │   ├── success_dialog.dart
│   │   └── payment_method_sheet.dart
│   ├── components/
│   │   ├── stat_card.dart
│   │   ├── sales_chart.dart
│   │   └── low_stock_badge.dart
│   └── extensions/
│       ├── context_extensions.dart
│       ├── num_extensions.dart          # x.toRupiah()
│       └── datetime_extensions.dart
│
└── main.dart
```

---

## 5. KONVENSI KODE & PENAMAAN

- Bahasa untuk **teks UI, pesan validasi, isi notifikasi** wajib Bahasa Indonesia. Istilah teknis (state, provider, repository, model) tetap Inggris.
- Komentar kode boleh Bahasa Indonesia, terutama untuk logika bisnis (perhitungan stok, hutang, laporan) agar mudah dipahami tim non-native English.
- Penamaan file: `snake_case.dart`. Penamaan class: `PascalCase`. Penamaan provider: `camelCaseProvider`.
- Setiap Repository memiliki interface abstrak (opsional untuk MVP kecil, wajib jika tim > 1 developer) agar mudah di-mock saat testing.
- Format uang selalu melalui `CurrencyFormatter.toRupiah()` — tidak ada hardcode format `Rp` di widget.
- Semua nominal disimpan sebagai `int` (dalam Rupiah, tanpa desimal) untuk menghindari floating point error pada uang.

---

## 6. SISTEM AKUN & AUTENTIKASI

### 6.1 Metode Login

- **Email & Password**
  - Register
  - Login
  - Forgot Password (kirim email reset via Firebase Auth)
  - Reset Password
- **Google Sign-In**
  - Login akun Google yang sudah pernah dipakai
  - Daftar otomatis jika akun Google belum pernah terdaftar (auto-create user document)

### 6.2 Alur Autentikasi

```
Splash Screen
     ↓
Cek status Firebase Auth
     ↓
┌─────────────┬───────────────┐
Belum Login    Sudah Login
     ↓                ↓
Login/Register    Cek dokumen users/{uid}
                        ↓
              ┌─────────┴─────────┐
        Belum onboarding      Sudah onboarding
              ↓                    ↓
        Onboarding Flow      Cek isPaid
                                   ↓
                        ┌──────────┴──────────┐
                     belum bayar          sudah bayar
                        ↓                     ↓
                Trial / Payment Screen     Dashboard
```

### 6.3 Auth Repository — Kontrak Fungsi

```dart
abstract class AuthRepository {
  Future<UserModel> signInWithEmail(String email, String password);
  Future<UserModel> registerWithEmail(String email, String password, String name);
  Future<UserModel> signInWithGoogle();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();
  Stream<User?> authStateChanges();
}
```

Setiap registrasi baru (baik email maupun Google) **wajib** memicu proses pembuatan `User` + `Business` sekaligus (lihat Bagian 7), dijalankan dalam satu **Firestore batch write** atau **transaction** agar tidak ada kondisi setengah-jadi (user ada tapi business tidak ada, atau sebaliknya).

---

## 7. ATURAN UTAMA: SATU AKUN — SATU USAHA — ISOLASI DATA

### 7.1 Alur Pembuatan Akun Baru

```
User Register (Email/Google)
        ↓
Firebase Authentication User dibuat
        ↓
[TRANSAKSI FIRESTORE - atomik]
   ├── Buat dokumen users/{uid}
   └── Buat dokumen businesses/{businessId}
        ↓
Update users/{uid}.businessId = businessId
        ↓
Arahkan ke Onboarding
```

### 7.2 Struktur Data Inti

```json
// users/{uid}
{
  "uid": "firebase_uid",
  "name": "Nama Pemilik",
  "email": "user@email.com",
  "photoUrl": "",
  "businessId": "business_id",
  "role": "owner",              // owner | staff | kasir
  "isPaid": false,
  "onboardingCompleted": false,
  "authProvider": "email",      // email | google
  "fcmToken": "",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

```json
// businesses/{businessId}
{
  "ownerId": "uid",
  "businessName": "Nama Usaha",
  "businessType": "retail",     // lihat enum BusinessType di 9.3
  "sellsProducts": true,
  "sellsServices": false,
  "phone": "",
  "address": "",
  "logoUrl": "",
  "currency": "IDR",
  "taxEnabled": false,
  "taxPercentage": 0,
  "operationalHours": { "open": "08:00", "close": "21:00" },
  "isActive": true,
  "members": ["uid_owner", "uid_staff_1"],   // dipakai Security Rules untuk cek akses karyawan
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 7.3 Aturan Isolasi Data (Wajib, Tidak Bisa Ditawar)

- **Setiap koleksi data bisnis disimpan sebagai subkoleksi dari `businesses/{businessId}`**, bukan sebagai koleksi top-level dengan field `businessId`. Ini pilihan arsitektur final untuk project ini (lihat Bagian 10) karena memberi isolasi paling tegas dan Security Rules paling sederhana.
- Repository layer **selalu** menerima `businessId` dari `currentBusinessProvider` (di-resolve dari sesi login), **tidak pernah** dari input manual/parameter yang bisa dimanipulasi UI.
- Tidak ada satu pun query di aplikasi yang boleh mengakses `businesses/{businessId}` lain selain milik sesi aktif — ini ditegakkan ganda: di level Repository (query selalu terikat path business aktif) dan di level Security Rules (server-side enforcement).

---

## 8. MODEL PEMBAYARAN SEKALI BAYAR

### 8.1 Konsep

```
Akun dibuat → status Trial (isPaid = false, trialExpiresAt = createdAt + 7 hari)
        ↓
User eksplorasi fitur (data yang dibuat selama trial tetap tersimpan, tidak hilang)
        ↓
User melakukan pembayaran Rp200.000
        ↓
Upload bukti pembayaran → status "pending"
        ↓
Verifikasi (manual oleh admin di MVP, otomatis via payment gateway di fase lanjutan)
        ↓
isPaid = true, paidAt = timestamp
        ↓
Seluruh fitur premium terbuka permanen (tidak ada perpanjangan)
```

Trial dibatasi bukan untuk mengunci fitur secara agresif, tapi untuk memberi user waktu mencoba sebelum membayar. Batas trial disarankan: **7 hari** atau **maksimum 30 transaksi**, mana yang tercapai lebih dulu (dikonfigurasi di `app_constants.dart`, bukan hardcode).

### 8.2 Struktur Data

```json
// businesses/{businessId}/payments/{paymentId}
{
  "userId": "uid",
  "businessId": "business_id",
  "amount": 200000,
  "status": "pending",              // pending | paid | rejected | expired
  "paymentMethod": "bank_transfer", // bank_transfer | qris | (gateway di fase lanjutan)
  "proofImageUrl": "",
  "paymentReference": "BL-20260727-0001",
  "rejectionReason": "",
  "paidAt": null,
  "verifiedBy": "",
  "createdAt": "timestamp"
}
```

### 8.3 Desain Fleksibel untuk Payment Gateway

`PaymentRepository` dibungkus di belakang interface `PaymentGatewayAdapter` agar integrasi Midtrans/Xendit di masa depan tidak mengubah kode fitur:

```dart
abstract class PaymentGatewayAdapter {
  Future<PaymentModel> createPaymentRequest(String businessId, int amount);
  Future<PaymentStatus> checkStatus(String paymentId);
}

class ManualBankTransferAdapter implements PaymentGatewayAdapter { ... } // MVP
class MidtransAdapter implements PaymentGatewayAdapter { ... }           // fase lanjutan
class XenditAdapter implements PaymentGatewayAdapter { ... }             // fase lanjutan
```

Verifikasi status `isPaid = true` **tidak boleh ditulis langsung dari client**. Client hanya boleh menulis status `pending` + upload bukti. Perubahan ke `paid` dilakukan oleh **Cloud Function** (dipicu admin panel manual atau webhook payment gateway) yang punya privilege khusus, agar user tidak bisa mengubah `isPaid` sendiri lewat manipulasi client.

---

## 9. ALUR ONBOARDING USAHA

### 9.1 Alur Layar

```
Step 1: Nama Pemilik Usaha
Step 2: Nama Usaha
Step 3: Jenis Usaha (pilih dari enum BusinessType)
Step 4: Model Penjualan → Barang / Jasa / Barang & Jasa
Step 5: Pengaturan Awal
   - Mata uang (default IDR, terkunci di MVP)
   - Format harga (contoh: Rp10.000 vs Rp10,000)
   - Satuan produk default
   - Pajak (aktif/nonaktif + persentase)
   - Jam operasional
        ↓
Simpan ke businesses/{businessId}
        ↓
users/{uid}.onboardingCompleted = true
        ↓
Arahkan ke Dashboard (atau Payment Screen jika trial sudah habis)
```

### 9.2 State Management Onboarding

Menggunakan satu `OnboardingNotifier` (StateNotifier/AsyncNotifier) yang menyimpan draft data di memory selama 5 step, baru melakukan satu kali write ke Firestore di step terakhir — bukan write per step, agar tidak ada dokumen `businesses` yang setengah terisi jika user keluar di tengah proses.

### 9.3 Enum Jenis Usaha

```dart
enum BusinessType {
  retail,            // Toko retail
  onlineShop,        // Toko online
  foodBeverage,       // Makanan & minuman
  workshop,           // Bengkel
  salon,              // Salon
  laundry,            // Laundry
  designService,      // Jasa desain
  digitalService,     // Jasa digital
  constructionService,// Jasa konstruksi
  repairService,      // Jasa servis
  livestock,          // Peternakan
  agriculture,        // Pertanian
  fashion,            // Fashion
  electronics,        // Elektronik
  other,              // Lainnya
}
```

`businessType` dipakai untuk **kustomisasi Dashboard** (lihat Bagian 13.3) dan untuk preset kategori/satuan default saat onboarding (misalnya salon → satuan default "sesi", bengkel → satuan default "unit").

---

## 10. STRUKTUR DATABASE CLOUD FIRESTORE

### 10.1 Keputusan Arsitektur: Subcollection per Business

Sesuai preferensi eksplisit, struktur final menggunakan **nested subcollection di bawah `businesses/{businessId}`**, bukan koleksi top-level dengan field `businessId`. Alasan:

- Isolasi data eksplisit di level path, bukan hanya di level query filter → mustahil query "tembus" ke bisnis lain secara tidak sengaja.
- Security Rules jauh lebih sederhana (cukup satu rule di level `businesses/{businessId}` yang otomatis berlaku ke semua subkoleksi di bawahnya).
- Menghapus satu usaha (jika suatu saat dibutuhkan) tinggal menghapus satu pohon dokumen.

### 10.2 Peta Struktur Lengkap

```
users/{uid}

businesses/{businessId}
 ├── (fields inti bisnis)
 ├── products/{productId}
 ├── services/{serviceId}
 ├── categories/{categoryId}
 ├── customers/{customerId}
 ├── suppliers/{supplierId}
 ├── transactions/{transactionId}
 │      └── items/{itemId}            # subkoleksi transaction_items
 ├── stock_movements/{movementId}
 ├── purchases/{purchaseId}           # pembelian ke supplier
 ├── expenses/{expenseId}
 ├── debts/{debtId}
 ├── receivables/{receivableId}
 ├── employees/{employeeId}
 ├── payments/{paymentId}
 ├── notifications/{notificationId}
 └── audit_logs/{logId}
```

### 10.3 Model Data per Koleksi

**Products**
```json
businesses/{businessId}/products/{productId}
{
  "name": "Produk A",
  "description": "",
  "categoryId": "",
  "sku": "SKU001",
  "barcode": "",
  "purchasePrice": 7000,
  "sellingPrice": 10000,
  "stock": 20,
  "minimumStock": 5,
  "unit": "pcs",
  "imageUrl": "",
  "isActive": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Services**
```json
businesses/{businessId}/services/{serviceId}
{
  "name": "Jasa Service Motor",
  "description": "",
  "categoryId": "",
  "price": 50000,
  "durationMinutes": 60,
  "isActive": true,
  "createdAt": "timestamp"
}
```

**Categories**
```json
businesses/{businessId}/categories/{categoryId}
{
  "name": "Minuman",
  "type": "product",   // product | service
  "createdAt": "timestamp"
}
```

**Customers**
```json
businesses/{businessId}/customers/{customerId}
{
  "name": "Nama Pelanggan",
  "phone": "",
  "address": "",
  "totalTransaction": 0,
  "totalSpent": 0,
  "totalDebt": 0,
  "createdAt": "timestamp"
}
```
> `totalTransaction`, `totalSpent`, `totalDebt` adalah **field agregat ter-denormalisasi**, diperbarui otomatis lewat Cloud Function trigger setiap ada transaksi baru — tidak dihitung ulang manual di client agar konsisten dan cepat ditampilkan.

**Suppliers**
```json
businesses/{businessId}/suppliers/{supplierId}
{
  "name": "Nama Supplier",
  "phone": "",
  "address": "",
  "totalPurchase": 0,
  "totalDebt": 0,
  "createdAt": "timestamp"
}
```

**Transactions (Penjualan / POS)**
```json
businesses/{businessId}/transactions/{transactionId}
{
  "transactionNumber": "TRX-20260727-0001",
  "customerId": "",           // boleh kosong = pelanggan umum
  "cashierId": "uid_kasir",
  "type": "sale",             // sale | return
  "subtotal": 100000,
  "discount": 5000,
  "tax": 0,
  "additionalFee": 0,
  "grandTotal": 95000,
  "paymentMethod": "cash",    // cash | transfer | qris | ewallet | debit | credit | debt
  "paymentStatus": "paid",    // paid | partial | unpaid
  "amountPaid": 95000,
  "changeAmount": 0,
  "note": "",
  "createdAt": "timestamp"
}
```

**Transaction Items**
```json
businesses/{businessId}/transactions/{transactionId}/items/{itemId}
{
  "itemType": "product",      // product | service
  "itemId": "product_id",
  "itemName": "Produk A",     // disimpan snapshot, agar histori tetap valid walau nama produk diubah
  "quantity": 2,
  "unitPrice": 10000,
  "subtotal": 20000
}
```

**Stock Movements**
```json
businesses/{businessId}/stock_movements/{movementId}
{
  "productId": "product_id",
  "type": "sale",   // purchase_in | sale | return | adjustment | damaged
  "quantity": -2,
  "stockBefore": 10,
  "stockAfter": 8,
  "referenceType": "transaction",  // transaction | purchase | manual
  "referenceId": "transaction_id",
  "note": "",
  "createdBy": "uid",
  "createdAt": "timestamp"
}
```

**Purchases (Pembelian dari Supplier)**
```json
businesses/{businessId}/purchases/{purchaseId}
{
  "supplierId": "supplier_id",
  "purchaseNumber": "PO-20260727-0001",
  "items": [ { "productId": "", "quantity": 10, "unitCost": 7000, "subtotal": 70000 } ],
  "totalAmount": 70000,
  "paymentStatus": "unpaid",  // paid | partial | unpaid
  "amountPaid": 0,
  "createdAt": "timestamp"
}
```

**Expenses**
```json
businesses/{businessId}/expenses/{expenseId}
{
  "category": "operasional",  // listrik | internet | gaji | transportasi | sewa | perlengkapan | operasional | lainnya
  "amount": 100000,
  "description": "Pembelian perlengkapan",
  "receiptImageUrl": "",
  "date": "timestamp",
  "createdBy": "uid",
  "createdAt": "timestamp"
}
```

**Debts (Hutang usaha ke supplier/pihak lain)**
```json
businesses/{businessId}/debts/{debtId}
{
  "creditorType": "supplier",   // supplier | other
  "creditorId": "supplier_id",
  "creditorName": "Nama Supplier",
  "referenceType": "purchase",
  "referenceId": "purchase_id",
  "totalAmount": 70000,
  "paidAmount": 0,
  "remainingAmount": 70000,
  "dueDate": "timestamp",
  "status": "unpaid",   // unpaid | partial | paid | overdue
  "createdAt": "timestamp"
}
```

**Receivables (Piutang dari pelanggan)**
```json
businesses/{businessId}/receivables/{receivableId}
{
  "customerId": "customer_id",
  "customerName": "Nama Pelanggan",
  "referenceType": "transaction",
  "referenceId": "transaction_id",
  "totalAmount": 95000,
  "paidAmount": 20000,
  "remainingAmount": 75000,
  "dueDate": "timestamp",
  "status": "partial",  // unpaid | partial | paid | overdue
  "createdAt": "timestamp"
}
```

**Employees**
```json
businesses/{businessId}/employees/{employeeId}
{
  "uid": "firebase_uid_karyawan",
  "name": "Nama Staff",
  "phone": "",
  "role": "kasir",       // staff | kasir
  "permissions": {
    "canViewProducts": true,
    "canCreateTransaction": true,
    "canEditProducts": false,
    "canViewReports": false,
    "canManageExpenses": false
  },
  "isActive": true,
  "invitedAt": "timestamp",
  "joinedAt": "timestamp"
}
```

**Notifications**
```json
businesses/{businessId}/notifications/{notificationId}
{
  "type": "low_stock",   // low_stock | debt_due | receivable_due | payment_verified | system
  "title": "Stok Menipis",
  "body": "Produk Minyak Goreng tersisa 3",
  "referenceId": "product_id",
  "isRead": false,
  "createdAt": "timestamp"
}
```

**Audit Logs**
```json
businesses/{businessId}/audit_logs/{logId}
{
  "actorId": "uid",
  "actorName": "Staff B",
  "action": "delete_product",
  "targetType": "product",
  "targetId": "product_id",
  "description": "Staff B menghapus produk Produk A",
  "createdAt": "timestamp"
}
```

---

## 11. FIRESTORE SECURITY RULES

Prinsip dasar: **tidak pernah** `allow read, write: if true;`. Semua akses harus tervalidasi terhadap kepemilikan bisnis (`ownerId`) atau keanggotaan (`members`).

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isBusinessMember(businessId) {
      return isSignedIn() &&
        request.auth.uid in get(/databases/$(database)/documents/businesses/$(businessId)).data.members;
    }

    function isBusinessOwner(businessId) {
      return isSignedIn() &&
        request.auth.uid == get(/databases/$(database)/documents/businesses/$(businessId)).data.ownerId;
    }

    match /users/{uid} {
      allow read, update: if isSignedIn() && request.auth.uid == uid;
      allow create: if isSignedIn() && request.auth.uid == uid;
      allow delete: if false;
    }

    match /businesses/{businessId} {
      allow read: if isBusinessMember(businessId);
      allow update: if isBusinessOwner(businessId);
      allow create: if isSignedIn();
      allow delete: if false;

      // Berlaku untuk seluruh subkoleksi (products, services, customers, dst.)
      match /{subcollection}/{docId} {
        allow read: if isBusinessMember(businessId);
        allow create, update: if isBusinessMember(businessId);
        // Hapus dibatasi hanya owner untuk data sensitif tertentu bisa diperketat per-koleksi jika perlu
        allow delete: if isBusinessMember(businessId);

        // Nested subcollection (contoh: transactions/{id}/items/{itemId})
        match /{nestedCollection}/{nestedDocId} {
          allow read, write: if isBusinessMember(businessId);
        }
      }

      // Field isPaid & payments/{paymentId}.status="paid" HANYA boleh diubah via Cloud Function
      // (Admin SDK bypass Security Rules), sehingga tidak ada rule "allow update" untuk field ini dari client.
    }
  }
}
```

Catatan penting:

- `members` di dokumen `businesses` berisi UID owner + UID seluruh karyawan aktif. Setiap kali karyawan ditambahkan/dinonaktifkan, field ini wajib disinkronkan (idealnya via Cloud Function trigger dari `employees/{employeeId}` agar tidak lupa update manual).
- Permission granular per karyawan (`canEditProducts`, dsb.) **tidak** ditegakkan di Security Rules (Firestore Rules tidak ideal untuk permission matrix kompleks), melainkan ditegakkan di **level UI (menyembunyikan aksi)** dan **level Repository (guard sebelum call Firestore)**. Untuk operasi yang benar-benar kritikal, tambahkan Cloud Function khusus yang mengecek permission dari dokumen `employees` sebelum eksekusi.
- Field `isPaid` di `users/{uid}` sebaiknya juga tidak bisa diubah langsung oleh client (`allow update` mengecualikan field ini menggunakan `request.resource.data.diff(resource.data).affectedKeys()`), hanya Cloud Function (Admin SDK) yang boleh mengubahnya.

---

## 12. STATE MANAGEMENT — POLA RIVERPOD

Setiap fitur mengikuti pola konsisten:

```dart
// 1. Provider untuk Repository (di data/repositories, di-provide lewat core/services)
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(firestore: ref.watch(firestoreServiceProvider));
});

// 2. Provider untuk stream/list data (AsyncNotifier / StreamProvider)
final productListProvider = StreamProvider.autoDispose<List<ProductModel>>((ref) {
  final businessId = ref.watch(currentBusinessIdProvider);
  final repo = ref.watch(productRepositoryProvider);
  return repo.watchProducts(businessId);
});

// 3. Notifier untuk aksi (create/update/delete) dengan state loading/error eksplisit
class ProductFormNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> saveProduct(ProductModel product) async {
    state = const AsyncLoading();
    final repo = ref.read(productRepositoryProvider);
    final businessId = ref.read(currentBusinessIdProvider);
    state = await AsyncValue.guard(() => repo.saveProduct(businessId, product));
  }
}
```

Provider global penting yang dipakai lintas fitur:

- `currentUserProvider` — data user login saat ini.
- `currentBusinessIdProvider` — businessId aktif, sumber tunggal untuk semua Repository.
- `currentBusinessProvider` — dokumen bisnis lengkap (untuk cek `businessType`, `taxEnabled`, dsb).
- `employeePermissionProvider` — permission karyawan yang sedang login (null jika owner = akses penuh).
- `connectivityProvider` — status online/offline untuk indikator UI.

Widget **hanya** boleh melakukan `ref.watch(...)` untuk baca dan `ref.read(...).method()` untuk aksi — tidak pernah menaruh `FirebaseFirestore.instance` langsung di dalam widget.

---

## 13. MODUL: DASHBOARD

### 13.1 Ringkasan Kartu Statistik

- Penjualan Hari Ini (jumlah Rupiah)
- Jumlah Transaksi Hari Ini
- Keuntungan Estimasi Hari Ini (`subtotal transaksi - total harga modal item terjual - pengeluaran hari ini`)
- Total Piutang Aktif
- Total Hutang Aktif
- Daftar Produk Stok Menipis (`stock <= minimumStock`)

### 13.2 Grafik Ringkasan Penjualan

Filter periode: Hari ini / 7 hari / 30 hari / Tahun ini. Data diagregasi dari `transactions` (di-cache per periode menggunakan `FutureProvider.family` agar tidak query ulang berlebihan saat berpindah tab).

### 13.3 Kustomisasi Dashboard Berdasarkan `businessType`

```dart
enum DashboardFocus { retail, service, mixed }

DashboardFocus resolveDashboardFocus(BusinessModel business) {
  if (business.sellsProducts && !business.sellsServices) return DashboardFocus.retail;
  if (!business.sellsProducts && business.sellsServices) return DashboardFocus.service;
  return DashboardFocus.mixed;
}
```

- **Fokus Retail:** kartu utama = Penjualan, Stok Menipis, Produk Terlaris, Supplier.
- **Fokus Jasa:** kartu utama = Pesanan Jasa Aktif, Pelanggan, Status Pekerjaan, Pendapatan Jasa.
- **Fokus Mixed:** kombinasi keduanya, produk & jasa terlaris ditampilkan berdampingan.

### 13.4 Produk/Jasa Terlaris

Dihitung dari agregasi `transaction_items` (di-*group by* `itemId`, di-sort `SUM(quantity)` descending) — untuk MVP dihitung on-demand di client dari data 30 hari terakhir; untuk skala lebih besar dipindah ke Cloud Function terjadwal yang menulis hasil agregasi ke dokumen `businesses/{businessId}/analytics/topProducts`.

---

## 14. MODUL: PRODUK

Fitur: tambah, edit, hapus (soft delete via `isActive=false`, bukan hard delete agar histori transaksi lama tidak rusak), lihat detail, upload foto ke Firebase Storage, atur harga modal & jual, atur stok awal, SKU, barcode, kategori, satuan.

Satuan default (bisa ditambah manual): `pcs`, `kg`, `liter`, `meter`, `box`, `paket`, `sesi`, `unit`.

Validasi wajib:
- `sellingPrice >= 0`, `purchasePrice >= 0`
- `sku` unik dalam satu bisnis (dicek di Repository sebelum create)
- `stock` tidak boleh negatif hasil input manual (perubahan negatif hanya boleh lewat alur `stock_movements`, lihat Bagian 20)

---

## 15. MODUL: JASA

Sama seperti produk namun tanpa konsep stok. Field tambahan: `durationMinutes` (estimasi waktu pengerjaan, ditampilkan di POS agar kasir tahu estimasi selesai). Jasa tidak memicu `stock_movements`.

---

## 16. MODUL: KATEGORI

Kategori bersifat generik untuk produk maupun jasa (`type: product | service`), dikelola di satu layar dengan tab. Kategori dipakai untuk filter di POS dan grouping di laporan.

---

## 17. MODUL: POS / TRANSAKSI PENJUALAN

### 17.1 Alur Transaksi

```
Pilih Produk/Jasa (search / scan barcode / browse kategori)
        ↓
Tambah ke Keranjang, atur quantity
        ↓
(opsional) Pilih Pelanggan
        ↓
Terapkan diskon / pajak / biaya tambahan / catatan
        ↓
Pilih metode pembayaran
        ↓
Jika "Hutang" dipilih → wajib pilih pelanggan (tidak boleh anonim)
        ↓
Hitung Grand Total
        ↓
Konfirmasi Bayar
        ↓
[TRANSAKSI FIRESTORE ATOMIK]
  ├── Buat dokumen transactions/{id} + subkoleksi items
  ├── Untuk setiap item produk: kurangi stock + buat stock_movements (type: sale)
  ├── Jika pembayaran sebagian/hutang: buat/update receivables/{id}
  └── Update agregat customers/{id}: totalTransaction, totalSpent, totalDebt
        ↓
Transaksi Selesai → cetak/bagikan struk (opsional)
```

Perhitungan total:

```
Subtotal        = Σ (unitPrice × quantity) semua item
Grand Total     = Subtotal − Discount + Tax + AdditionalFee
Sisa Bayar      = Grand Total − AmountPaid   (jika > 0 → paymentStatus = partial/unpaid, buat receivable)
Kembalian       = AmountPaid − Grand Total   (jika metode cash dan AmountPaid > Grand Total)
```

### 17.2 Metode Pembayaran

`cash`, `transfer`, `qris`, `ewallet`, `debit`, `kredit`, `hutang` (hutang = piutang bagi usaha, otomatis membuat entri `receivables`).

### 17.3 Integritas Data — Wajib Transaction/Batch Write

Karena satu transaksi POS menyentuh banyak koleksi sekaligus (transactions, items, stock_movements, receivables, customers), operasi ini **wajib** dibungkus Firestore `runTransaction` (bukan sekadar batch biasa) khususnya untuk pengurangan stok, agar tidak terjadi race condition ketika dua kasir menjual produk yang sama secara bersamaan (stok tidak boleh minus akibat concurrent write).

```dart
Future<void> checkout(TransactionModel trx, List<TransactionItemModel> items) async {
  await firestore.runTransaction((tx) async {
    for (final item in items.where((i) => i.itemType == 'product')) {
      final productRef = productDocRef(item.itemId);
      final snapshot = await tx.get(productRef);
      final currentStock = snapshot['stock'] as int;
      if (currentStock < item.quantity) {
        throw InsufficientStockException(item.itemName);
      }
      tx.update(productRef, {'stock': currentStock - item.quantity});
      tx.set(stockMovementDocRef(), buildStockMovement(item, currentStock));
    }
    tx.set(transactionDocRef(trx.id), trx.toJson());
    // ... items, receivable, customer aggregate update
  });
}
```

---

## 18. MODUL: PELANGGAN

CRUD pelanggan + tampilan detail berisi: total transaksi, total belanja, sisa piutang aktif, riwayat transaksi (list `transactions` yang difilter `customerId`). Field agregat (`totalTransaction`, `totalSpent`, `totalDebt`) diperbarui otomatis setiap transaksi baru — bukan dihitung ulang setiap buka layar, demi performa.

---

## 19. MODUL: SUPPLIER & PEMBELIAN

```
Tambah Supplier
     ↓
Buat Purchase Order (pembelian barang dari supplier)
     ↓
Stok produk terkait bertambah + stock_movements (type: purchase_in)
     ↓
Jika belum lunas → buat/ update debts/{id} (hutang ke supplier)
```

CRUD supplier: nama, telepon, alamat, daftar produk yang biasa disuplai (opsional), total pembelian & hutang berjalan (agregat).

---

## 20. MODUL: INVENTORY / MANAJEMEN STOK

**Prinsip wajib:** stok **tidak pernah** diubah langsung (`update stock: X`) tanpa mencatat `stock_movements`. Semua perubahan stok — dari mana pun sumbernya (penjualan, pembelian, retur, penyesuaian manual, barang rusak) — wajib melewati satu fungsi terpusat `StockRepository.adjustStock()` yang selalu menulis dua hal sekaligus dalam satu transaction: update `products/{id}.stock` **dan** insert dokumen `stock_movements`.

Jenis pergerakan stok (`type`): `purchase_in`, `sale`, `return`, `adjustment`, `damaged`.

Layar "Riwayat Stok" per produk menampilkan seluruh `stock_movements` terkait produk tersebut secara kronologis — berfungsi sebagai kartu stok digital.

---

## 21. MODUL: PENGELUARAN

CRUD pengeluaran dengan kategori: `listrik`, `internet`, `gaji`, `transportasi`, `sewa`, `perlengkapan`, `operasional`, `lainnya`. Mendukung upload foto struk/bukti. Filter berdasarkan tanggal & kategori, ditotal per periode untuk kebutuhan Laporan Keuntungan (Bagian 23).

---

## 22. MODUL: HUTANG & PIUTANG

### 22.1 Hutang (Debts)

Sumber: pembelian ke supplier yang belum lunas, atau hutang manual ke pihak lain. Status: `unpaid`, `partial`, `paid`, `overdue` (dihitung otomatis: `overdue` jika `dueDate < now && status != paid`).

### 22.2 Piutang (Receivables)

Sumber: transaksi penjualan dengan metode `hutang` atau pembayaran sebagian. Setiap pembayaran cicilan piutang dicatat sebagai sub-entri (`payments_log` di dalam dokumen receivable atau subkoleksi `receivables/{id}/installments`) agar riwayat pelunasan bertahap tetap terlacak, bukan hanya angka akhir.

```json
businesses/{businessId}/receivables/{id}/installments/{installmentId}
{
  "amount": 20000,
  "paymentMethod": "cash",
  "paidAt": "timestamp",
  "recordedBy": "uid"
}
```

### 22.3 Kalkulasi Status

```
remainingAmount = totalAmount − paidAmount
status = paidAmount == 0 ? "unpaid"
       : remainingAmount == 0 ? "paid"
       : (dueDate < now ? "overdue" : "partial")
```

---

## 23. MODUL: LAPORAN & ANALITIK

| Laporan | Isi |
|---|---|
| Laporan Penjualan | Harian / Mingguan / Bulanan / Tahunan — total omzet, jumlah transaksi, rata-rata nilai transaksi |
| Laporan Keuntungan | `Penjualan − Harga Modal Terjual − Pengeluaran = Keuntungan Bersih` |
| Laporan Produk | Produk terlaris, produk paling tidak laku, produk stok menipis |
| Laporan Pelanggan | Pelanggan paling sering bertransaksi, pelanggan dengan piutang terbesar |
| Laporan Hutang | Total hutang aktif, daftar jatuh tempo, riwayat hutang terbayar |
| Laporan Keuangan Sederhana | Pendapatan, pengeluaran, keuntungan, hutang, piutang dalam satu ringkasan periode |

Semua laporan dibangun dari data mentah (`transactions`, `expenses`, `stock_movements`, `debts`, `receivables`) yang sudah ada — **tidak ada duplikasi tabel laporan terpisah** di MVP. Untuk periode panjang (misal laporan tahunan pada bisnis dengan ribuan transaksi), agregasi dipindahkan ke Cloud Function terjadwal yang menulis snapshot bulanan ke `businesses/{businessId}/report_snapshots/{yyyyMM}` agar layar laporan tidak perlu menghitung ulang seluruh histori setiap dibuka.

---

## 24. MODUL: KARYAWAN & ROLE-BASED ACCESS CONTROL

### 24.1 Role

- **Owner** — akses penuh, satu-satunya yang bisa mengelola karyawan, melihat semua laporan, dan mengatur pembayaran/langganan.
- **Staff** — akses dibatasi sesuai `permissions`.
- **Kasir** — default hanya `canCreateTransaction` + `canViewProducts`.

### 24.2 Alur Undang Karyawan

```
Owner memasukkan email calon karyawan
        ↓
Sistem cek apakah email sudah punya akun Firebase Auth
        ↓
┌───────────────┬────────────────────┐
Sudah punya akun     Belum punya akun
        ↓                    ↓
Tautkan uid ke      Kirim link undangan
employees/{id}      (buat akun dulu via app)
        ↓                    ↓
Tambahkan uid ke businesses/{businessId}.members
        ↓
users/{uid_karyawan}.businessId = businessId milik owner
users/{uid_karyawan}.role = "staff" / "kasir"
```

> Catatan penting: karyawan **tidak** membuat `businesses` baru saat register — alur register karyawan berbeda dari alur register owner biasa (lihat Bagian 7.1), dan harus dibedakan lewat context "user diundang" (misal via deep link/kode undangan) sebelum proses pembuatan dokumen `users`.

### 24.3 Permission Matrix (default)

| Permission | Owner | Staff | Kasir |
|---|:---:|:---:|:---:|
| canViewProducts | ✔ | ✔ (bisa diatur) | ✔ |
| canCreateTransaction | ✔ | ✔ (bisa diatur) | ✔ |
| canEditProducts | ✔ | opsional | ✘ |
| canViewReports | ✔ | opsional | ✘ |
| canManageExpenses | ✔ | opsional | ✘ |
| canManageEmployees | ✔ | ✘ | ✘ |
| canManagePayment | ✔ | ✘ | ✘ |

UI menyembunyikan menu yang tidak diizinkan (bukan sekadar disable) agar tampilan kasir tetap sederhana sesuai prinsip *Simple*.

---

## 25. SISTEM NOTIFIKASI (FCM + IN-APP)

Jenis notifikasi & pemicu:

| Trigger | Contoh Pesan |
|---|---|
| Stok produk ≤ minimumStock | "Stok Minyak Goreng hampir habis, sisa 3" |
| Hutang jatuh tempo H-3 | "Hutang ke Supplier X jatuh tempo 3 hari lagi" |
| Piutang menumpuk / jatuh tempo | "Pelanggan A memiliki piutang Rp500.000" |
| Pembayaran terverifikasi | "Pembayaran kamu berhasil diverifikasi, selamat menggunakan Buku Laris!" |

Alur teknis: Cloud Function `onWrite`/scheduled function mengecek kondisi (stok, jatuh tempo) → menulis dokumen ke `notifications` subkoleksi → mengirim push via FCM ke `fcmToken` seluruh member bisnis yang relevan (owner selalu menerima; karyawan hanya jika permission terkait aktif). Layar "Notifikasi" di app membaca subkoleksi `notifications` secara realtime dan menandai `isRead`.

---

## 26. SISTEM OFFLINE & SINKRONISASI DATA

Memanfaatkan **Firestore offline persistence bawaan** (`FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true)`), sehingga read/write tetap berfungsi saat offline dan otomatis sinkron saat online kembali.

```
User transaksi saat offline
        ↓
Firestore SDK menulis ke cache lokal + antrian pending write
        ↓
UI langsung update optimistic (data tampil seolah tersimpan)
        ↓
Internet kembali
        ↓
SDK otomatis mengirim antrian ke server
        ↓
Jika terjadi konflik (mis. stok sudah berubah di device lain) →
   `runTransaction` di server-side memvalidasi ulang saat sinkron
```

**Area rawan konflik yang perlu penanganan khusus:**

- **Stok** — karena `checkout()` menggunakan `runTransaction`, saat dua device offline melakukan penjualan produk sama lalu sinkron bersamaan, transaksi yang sinkron lebih dulu akan berhasil; transaksi kedua bisa gagal jika stok jadi tidak cukup. UI harus menangani exception ini dengan pesan jelas ("Stok tidak mencukupi, transaksi perlu disesuaikan") — bukan silent fail.
- **Transaksi ganda** — `transactionNumber` sebaiknya di-generate di client dengan kombinasi timestamp + random suffix (bukan auto-increment sekuensial) agar tidak bentrok saat beberapa device offline membuat nomor transaksi bersamaan.
- **Pembayaran** — status `isPaid`/`paid` tidak pernah ditentukan dari write offline client (lihat Bagian 11), sehingga tidak ada risiko konflik pada data finansial paling sensitif ini.

UI wajib menampilkan indikator status koneksi (`connectivityProvider`) dan badge kecil pada data yang masih "menunggu sinkron" (`hasPendingWrites` dari `SnapshotMetadata`).

---

## 27. EXPORT, CETAK STRUK, & SHARE

- **Export Laporan:** PDF (`pdf` + `printing` package), Excel (`excel` package), CSV (`csv` package) — tersedia di setiap layar Laporan.
- **Cetak Struk:** Thermal printer via Bluetooth (fase lanjutan, `esc_pos_bluetooth`) atau cetak sebagai PDF di MVP.
- **Share Invoice/Struk:** via `share_plus` — target WhatsApp, Email, atau share sheet umum.

Semua fungsi export dipusatkan di `core/services/pdf_export_service.dart` & `excel_export_service.dart` agar format struk/laporan konsisten di seluruh modul, tidak diimplementasikan ulang per fitur.

---

## 28. AUDIT LOG

Setiap aksi sensitif (hapus produk, hapus transaksi, ubah harga signifikan, nonaktifkan karyawan, ubah permission) dicatat ke `audit_logs` lewat satu helper terpusat:

```dart
Future<void> logAudit({
  required String action,
  required String targetType,
  required String targetId,
  required String description,
}) async {
  final actor = ref.read(currentUserProvider);
  await auditLogRepository.create(
    businessId: currentBusinessId,
    actorId: actor.uid,
    actorName: actor.name,
    action: action,
    targetType: targetType,
    targetId: targetId,
    description: description,
  );
}
```

Log hanya bisa dibaca oleh **Owner** (diatur baik lewat UI — menu Audit Log tidak tampil untuk staff/kasir — maupun opsional diperketat lebih lanjut di Security Rules bila diperlukan).

---

## 29. EXCEPTION HANDLING & ERROR STRATEGY

Hierarki exception kustom di `core/exceptions/`:

```dart
abstract class AppException implements Exception {
  final String message;
  AppException(this.message);
}

class AuthException extends AppException { AuthException(super.message); }
class FirestoreException extends AppException { FirestoreException(super.message); }
class InsufficientStockException extends AppException {
  InsufficientStockException(String productName)
      : super('Stok "$productName" tidak mencukupi');
}
class BusinessRuleException extends AppException { BusinessRuleException(super.message); }
```

Setiap Repository menangkap exception Firebase mentah (`FirebaseException`, `FirebaseAuthException`) dan melempar ulang sebagai `AppException` turunan dengan pesan Bahasa Indonesia yang ramah pengguna — widget presentation **tidak pernah** menampilkan pesan error Firebase mentah ke layar.

Global error UI: `error_state_widget.dart` dipakai konsisten di semua layar untuk state gagal-muat, lengkap dengan tombol "Coba Lagi".

---

## 30. ROUTING (GO_ROUTER) & NAVIGASI

Struktur route utama dengan guard berlapis:

```
/splash
/login
/register
/forgot-password
/onboarding (guard: authenticated, !onboardingCompleted)
/payment (guard: authenticated, onboardingCompleted, !isPaid && trialExpired)
/dashboard (guard: authenticated, onboardingCompleted)
  /products
  /products/:id
  /services
  /pos
  /customers
  /suppliers
  /inventory
  /expenses
  /debts
  /receivables
  /reports
  /employees        (guard tambahan: role == owner)
  /settings
```

`route_guards.dart` membaca provider auth/business state dan melakukan redirect di `GoRouter.redirect`, sehingga logic proteksi terpusat, tidak tersebar sebagai `if` di setiap screen.

Bottom Navigation utama: **Dashboard, Transaksi (POS), Produk, Laporan, Lainnya**. FAB di layar Dashboard/Transaksi mengarah langsung ke `/pos` (tambah transaksi cepat).

---

## 31. TESTING STRATEGY

- **Unit test** wajib untuk logic perhitungan kritikal: total POS (subtotal, diskon, pajak, grand total), status hutang/piutang (`unpaid/partial/paid/overdue`), dan agregasi stok.
- **Repository test** menggunakan `fake_cloud_firestore` untuk mensimulasikan Firestore tanpa koneksi nyata, khususnya untuk memvalidasi `runTransaction` pada `checkout()` (skenario stok cukup vs tidak cukup vs race condition).
- **Widget test** untuk form validasi (produk, transaksi, pengeluaran) memastikan pesan error Bahasa Indonesia muncul sesuai kondisi.
- Tidak wajib 100% coverage di MVP — prioritaskan modul **POS, Stok, dan Pembayaran** karena paling berisiko terhadap kerugian finansial jika ada bug.

---

## 32. ROADMAP PENGEMBANGAN

### Fase 1 — MVP (wajib rilis pertama)

1. Auth (Email & Password, Google Sign-In, Forgot Password)
2. Onboarding Usaha (5 step)
3. Dashboard (kustomisasi dasar per `businessType`)
4. Produk (CRUD + stok awal)
5. Jasa (CRUD)
6. POS / Transaksi Penjualan (lengkap dengan diskon, pajak, metode bayar, hutang)
7. Pelanggan (CRUD + histori transaksi)
8. Stok / Inventory (stock_movements lengkap)
9. Pengeluaran (CRUD)
10. Hutang & Piutang (dasar, tanpa cicilan bertahap kompleks)
11. Laporan (Penjualan, Keuntungan, Produk, Keuangan Sederhana)
12. Pembayaran Sekali Bayar (manual transfer + verifikasi manual admin)

### Fase 2 — Setelah MVP Stabil

- Modul Karyawan penuh (undangan, permission granular, audit log)
- Barcode scanner terintegrasi POS
- Cetak struk thermal printer
- Share invoice ke WhatsApp
- Reminder otomatis (FCM) untuk stok, hutang, piutang jatuh tempo
- Modul Supplier & Purchase Order lengkap
- Snapshot laporan bulanan otomatis (Cloud Function)

### Fase 3 — Analisis Bisnis Lanjutan

- Payment gateway otomatis (Midtrans/Xendit) menggantikan verifikasi manual
- Analisis bisnis otomatis (insight/rekomendasi berbasis data — misal "Produk X berpotensi kehabisan stok minggu depan")
- Export laporan terjadwal otomatis (kirim ke email pemilik setiap akhir bulan)
- Multi-cabang (opsional, jika suatu saat model "satu akun satu usaha" diperluas menjadi "satu usaha banyak cabang" — perubahan besar pada struktur data, dipertimbangkan matang sebelum dikerjakan)

---

## 33. PRINSIP NON-NEGOSIASI ARSITEKTUR

Checklist yang wajib dipatuhi oleh siapa pun yang mengembangkan aplikasi ini:

- [ ] Tidak ada akses Firestore langsung dari widget — selalu lewat Repository via Riverpod Provider.
- [ ] Semua data bisnis berada di subkoleksi `businesses/{businessId}/...` — tidak ada koleksi top-level baru dengan field `businessId` manual.
- [ ] `businessId` yang dipakai query **selalu** berasal dari sesi login aktif (`currentBusinessIdProvider`), tidak pernah dari parameter yang bisa dimanipulasi.
- [ ] Perubahan stok **selalu** melalui `StockRepository.adjustStock()` yang mencatat `stock_movements` — tidak ada `update({'stock': x})` langsung di tempat lain.
- [ ] Checkout POS **selalu** memakai `runTransaction`, tidak pernah batch write biasa, untuk mencegah stok minus akibat race condition.
- [ ] Status `isPaid` dan status pembayaran `"paid"` **tidak pernah** ditulis dari client — hanya via Cloud Function (Admin SDK).
- [ ] Tidak ada `allow read, write: if true;` di Security Rules dalam kondisi apa pun, termasuk saat development.
- [ ] Seluruh teks UI, pesan validasi, dan notifikasi menggunakan Bahasa Indonesia yang jelas dan ramah UMKM.
- [ ] Nominal uang selalu disimpan sebagai `int` (bukan `double`) untuk menghindari galat pembulatan.
- [ ] Setiap aksi sensitif (hapus, ubah harga besar, nonaktifkan karyawan) tercatat di `audit_logs`.
- [ ] UI menyembunyikan (bukan sekadar menonaktifkan) menu yang tidak diizinkan sesuai permission karyawan, demi menjaga kesederhanaan tampilan sesuai prinsip produk.

---

*Dokumen ini adalah rujukan arsitektur & logika sistem untuk Buku Laris. Spesifikasi tampilan, komponen visual, design token warna/tipografi, dan detail interaksi UI akan dijabarkan pada dokumen pasangan `design-buku-laris.md`.*
