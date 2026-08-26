import 'package:flutter/material.dart';

enum UserRole {
  OWNER('Pemilik'),
  EMPLOYEE('Karyawan');

  final String label;
  const UserRole(this.label);
}

enum Permission {
  dashboardView('Melihat dashboard'),
  productsView('Melihat produk & harga'),
  productsManage('Kelola produk'),
  categoriesManage('Kelola kategori'),
  stockAdjust('Sesuaikan stok'),
  preorderManage('Kelola pre-order'),
  salesCreate('Buat penjualan'),
  salesEditStatus('Ubah status pesanan'),
  salesRecordPayment('Catat pembayaran'),
  customersManage('Kelola pelanggan'),
  cashflowManage('Catat kas masuk/keluar'),
  reportsSalesView('Laporan penjualan'),
  reportsFinanceView('Laporan keuangan lengkap');

  final String label;
  const Permission(this.label);
}

class DefaultPermissions {
  DefaultPermissions._();

  static const Set<Permission> employeeDefault = {
    Permission.dashboardView,
    Permission.productsView,
    Permission.salesCreate,
    Permission.salesEditStatus,
    Permission.salesRecordPayment,
    Permission.customersManage,
    Permission.reportsSalesView,
    Permission.preorderManage,
  };
}

enum WorkspaceStatus { ACTIVE, ARCHIVED }

enum BusinessModel {
  physicalProduct('Produk Fisik', Icons.inventory_2_outlined),
  digitalProduct('Produk Digital', Icons.cloud_outlined),
  service('Jasa', Icons.handyman_outlined),
  layanan('Layanan', Icons.spa_outlined),
  preOrder('Pre-Order', Icons.schedule_outlined);

  final String label;
  final IconData icon;
  const BusinessModel(this.label, this.icon);
}

enum ProductType {
  physicalProduct('Produk Fisik'),
  digitalProduct('Produk Digital'),
  service('Jasa'),
  otherService('Layanan Lain');

  final String label;
  const ProductType(this.label);

  bool get tracksStock => this == ProductType.physicalProduct;
}

enum OrderType {
  readyStock('Stok Siap'),
  preOrder('Pre-Order');

  final String label;
  const OrderType(this.label);
}

enum PaymentStatus {
  unpaid('Belum Bayar'),
  partial('Bayar Sebagian'),
  paid('Lunas'),
  refunded('Dana Dikembalikan');

  final String label;
  const PaymentStatus(this.label);
}

enum SaleStatus {
  draft('Draft'),
  pending('Menunggu Konfirmasi'),
  confirmed('Dikonfirmasi'),
  processing('Diproses'),
  ready('Siap Diambil/Dikirim'),
  completed('Selesai'),
  cancelled('Dibatalkan'),
  refunded('Refund');

  final String label;
  const SaleStatus(this.label);

  bool get isActiveOrder =>
      this == pending || this == confirmed || this == processing || this == ready;

  bool get countsRevenue => this == completed;

  Color get color => switch (this) {
        draft => const Color(0xFF64748B),
        pending => const Color(0xFFF59E0B),
        confirmed => const Color(0xFF00529C),
        processing => const Color(0xFF0066AE),
        ready => const Color(0xFF0D9488),
        completed => const Color(0xFF10B981),
        cancelled => const Color(0xFFEF4444),
        refunded => const Color(0xFFF37021),
      };
}

enum InvitationStatus {
  pending('Menunggu Respons'),
  accepted('Diterima'),
  rejected('Ditolak'),
  expired('Kedaluwarsa'),
  revoked('Dibatalkan');

  final String label;
  const InvitationStatus(this.label);
}

enum CashTransactionType {
  income('Uang Masuk'),
  expense('Uang Keluar');

  final String label;
  const CashTransactionType(this.label);

  Color get color => this == income ? const Color(0xFF10B981) : const Color(0xFFEF4444);
}

enum StockDirection { masuk, keluar, penyesuaian }

extension StockDirectionX on StockDirection {
  String get label => switch (this) {
        StockDirection.masuk => 'Masuk',
        StockDirection.keluar => 'Keluar',
        StockDirection.penyesuaian => 'Penyesuaian',
      };

  static StockDirection fromReason(StockReason reason) =>
      reason.increasesStock ? StockDirection.masuk : StockDirection.keluar;
}

enum StockReason {
  initialStock('Stok Awal'),
  restock('Pembelian Stok'),
  sale('Penjualan'),
  saleCancelled('Pembatalan Penjualan'),
  customerReturn('Retur Pelanggan'),
  returnToSupplier('Retur ke Supplier'),
  damaged('Stok Rusak'),
  lost('Stok Hilang'),
  manualCorrection('Koreksi Manual'),
  preorderFulfillment('Pemenuhan Pre-Order');

  final String label;
  const StockReason(this.label);

  bool get increasesStock =>
      this == initialStock || this == restock || this == customerReturn;
}
