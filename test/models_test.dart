import 'package:flutter_test/flutter_test.dart';
import 'package:buku_laris/models/cash_transaction_model.dart';
import 'package:buku_laris/models/customer_model.dart';
import 'package:buku_laris/models/daily_summary_model.dart';
import 'package:buku_laris/models/enums.dart';
import 'package:buku_laris/models/product_model.dart';
import 'package:buku_laris/models/sale_model.dart';
import 'package:buku_laris/core/constants/catalogs.dart';

void main() {
  group('SaleItem serialization', () {
    test('round trips through map with null-safe cost', () {
      const item = SaleItem(
        productId: 'p1',
        productName: 'Keripik',
        type: ProductType.physicalProduct,
        categoryId: 'c1',
        categoryName: 'Makanan',
        qty: 3,
        unitPrice: 12000,
        costPrice: 8000,
      );
      final map = item.toMap();
      final restored = SaleItem.fromMap(map);
      expect(restored.productId, 'p1');
      expect(restored.qty, 3);
      expect(restored.costPrice, 8000);
      expect(restored.lineTotal, 36000);
      expect(restored.lineCost, 24000);
    });

    test('missing cost price stays null and flags unknown costs', () {
      final item = SaleItem.fromMap({
        'productId': 'x',
        'productName': 'Jasa Desain',
        'type': 'service',
        'qty': 1,
        'unitPrice': 250000,
      });
      expect(item.costPrice, isNull);
      expect(item.hasKnownCost, isFalse);
      expect(item.lineCost, 0);
    });
  });

  group('Sale status logic', () {
    test('active orders and revenue flags', () {
      expect(SaleStatus.processing.isActiveOrder, isTrue);
      expect(SaleStatus.ready.isActiveOrder, isTrue);
      expect(SaleStatus.completed.isActiveOrder, isFalse);
      expect(SaleStatus.completed.countsRevenue, isTrue);
      expect(SaleStatus.pending.countsRevenue, isFalse);
      expect(SaleStatus.cancelled.color, isNotNull);
    });
  });

  group('Product rules', () {
    test('low stock detection only for tracked physical items', () {
      const low = Product(
        id: 'a',
        name: 'A',
        type: ProductType.physicalProduct,
        stock: 2,
        minStock: 5,
      );
      const service = Product(
        id: 'b',
        name: 'B',
        type: ProductType.service,
        stock: 0,
        minStock: 5,
      );
      const unlimited = Product(
        id: 'c',
        name: 'C',
        type: ProductType.digitalProduct,
        unlimitedStock: true,
        stock: 0,
      );
      expect(low.isLowStock, isTrue);
      expect(service.isLowStock, isFalse);
      expect(unlimited.isLowStock, isFalse);
    });

    test('canSell blocks overselling when disabled', () {
      const p = Product(id: 'd', name: 'D', stock: 5, minStock: 1);
      expect(p.canSell(3), isTrue);
      expect(p.canSell(6), isFalse);
      expect(p.canSell(6, allowOverselling: true), isTrue);
    });
  });

  group('CashTransaction', () {
    test('create map includes workspace scoping and timestamps', () {
      final t = CashTransaction(
        workspaceId: 'ws1',
        type: CashTransactionType.expense,
        category: 'Transportasi',
        amount: 25000,
        occurredAt: DateTime(2026, 8, 25),
        createdBy: 'u1',
      );
      expect(t.id, '');
      expect(t.type.label, 'Uang Keluar');
      expect(t.type.color, isNotNull);
    });
  });

  group('Customer', () {
    test('update map normalizes email', () async {
      final map = const Customer(
        id: 'c1',
        name: ' Budi ',
        whatsapp: '081234567890',
        email: 'Budi@Usaha.ID ',
      ).toUpdateMap();
      expect(map['name'], 'Budi');
      expect(map['email'], 'budi@usaha.id');
    });
  });

  group('DailySummary', () {
    test('dayKey zero-pads month and day', () {
      expect(DailySummary.dayKey(DateTime(2026, 3, 5)), '2026-03-05');
      expect(DailySummary.dayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('Catalogs', () {
    test('cash categories cover required sources', () {
      for (final expected in ['Penjualan', 'Pembayaran DP', 'Modal Masuk']) {
        expect(CashCategories.income.contains(expected), isTrue,
            reason: 'income missing $expected');
      }
      for (final expected in [
        'Pembelian Stok',
        'Biaya Operasional',
        'Gaji Karyawan',
        'Sewa Tempat',
        'Marketing',
      ]) {
        expect(CashCategories.expense.contains(expected), isTrue,
            reason: 'expense missing $expected');
      }
    });
  });
}
