import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/cash_transaction_model.dart';
import '../models/daily_summary_model.dart';
import '../models/enums.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../repositories/sale_repository.dart';
import 'logger.dart';

enum DemoTemplate {
  physicalStore('Toko Barang Fisik'),
  digitalProducts('Penjual Produk Digital'),
  serviceBusiness('Jasa Servis'),
  hybrid('Kombinasi');

  final String label;
  const DemoTemplate(this.label);
}

class DemoDataService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final _random = Random(42);

  Future<void> clearDemoData(String wsId) async {
    for (final name in [
      Collections.sales,
      Collections.cashTransactions,
      Collections.stockMovements,
      Collections.customers,
      Collections.products,
      Collections.dailySummaries,
    ]) {
      var more = true;
      while (more) {
        final snap =
            await _sub(wsId, name).limit(AppConstants.cascadeBatchSize).get();
        if (snap.docs.isEmpty) {
          more = false;
          break;
        }
        final batch = _fs.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snap.docs.length < AppConstants.cascadeBatchSize) more = false;
      }
    }
    await _sub(wsId, Collections.counters).doc('sales').set({'seq': 0});
  }

  Future<int> seed({
    required String wsId,
    required String workspaceName,
    required String ownerId,
    required DemoTemplate template,
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Membuat produk & kategori...');
    _categoryNamesCache = {};
    final productsByCat = await _seedProducts(wsId, template);
    onProgress?.call('Membuat pelanggan...');
    final customers = await _seedCustomers(wsId);

    onProgress?.call('Menyusun transaksi penjualan...');
    var seq = 0;
    final now = DateTime.now();
    var createdSales = 0;

    for (var dayOffset = 59; dayOffset >= 0; dayOffset--) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: dayOffset));
      final salesToday = day.weekday == 7
          ? _random.nextInt(2)
          : 1 + _random.nextInt(4);

      for (var i = 0; i < salesToday; i++) {
        seq++;
        createdSales += await _createHistoricalSale(
          wsId: wsId,
          workspaceName: workspaceName,
          ownerId: ownerId,
          day: day,
          seq: seq,
          productsByCat: productsByCat,
          customers: customers,
          template: template,
        );
      }
    }

    onProgress?.call('Mencatat kas operasional...');
    await _seedExpenses(wsId, ownerId);

    onProgress?.call('Selesai.');
    return createdSales;
  }

  Future<int> _createHistoricalSale({
    required String wsId,
    required String workspaceName,
    required String ownerId,
    required DateTime day,
    required int seq,
    required Map<String, List<Product>> productsByCat,
    required List<Map<String, dynamic>> customers,
    required DemoTemplate template,
  }) async {
    try {
      final isPreOrder = template != DemoTemplate.digitalProducts &&
          _random.nextInt(10) == 0;
      final itemCount = 1 + _random.nextInt(template == DemoTemplate.serviceBusiness ? 2 : 3);
      final items = <SaleItem>[];
      final allProducts =
          productsByCat.values.expand((x) => x).toList();

      for (var i = 0; i < itemCount && allProducts.isNotEmpty; i++) {
        final product = allProducts[_random.nextInt(allProducts.length)];
        final alreadyIn = items.any((it) => it.productId == product.id);
        if (alreadyIn) continue;
        items.add(SaleItem(
          productId: product.id,
          productName: product.name,
          type: product.type,
          categoryId: product.categoryId,
          categoryName: _categoryNamesCache[product.categoryId] ?? '',
          qty: 1 + _random.nextInt(product.sellingPrice > 500000 ? 1 : 3),
          unit: product.unit,
          unitPrice: product.sellingPrice,
          costPrice: product.costPrice,
        ));
      }
      if (items.isEmpty) return 0;

      final customerData = customers[_random.nextInt(customers.length)];
      final withCustomer = _random.nextInt(100) < 60;

      final subtotal = items.fold(0, (s, it) => s + it.lineTotal);
      final grandTotal = subtotal;
      final paidFull = !isPreOrder || _random.nextInt(2) == 0;
      final dpPercent = [30, 50][_random.nextInt(2)];
      final paidAmount =
          paidFull ? grandTotal : (grandTotal * dpPercent / 100).round();

      final draft = SaleDraft(
        orderType:
            isPreOrder ? OrderType.preOrder : OrderType.readyStock,
        items: items,
        customerId: withCustomer
            ? customerData['id'] as String?
            : null,
        customerName: withCustomer ? customerData['name'] as String : '',
        customerWhatsapp:
            withCustomer ? customerData['whatsapp'] as String : '',
        paymentMethodName: ['Tunai', 'Transfer Bank', 'QRIS'][_random.nextInt(3)],
        paidAmount: paidAmount,
        estimatedCompletionDate: isPreOrder
            ? day.add(Duration(days: 3 + _random.nextInt(14)))
            : null,
        notes: '',
      );

      final saleRef = _sub(wsId, Collections.sales).doc();
      final createdAt = Timestamp.fromDate(day.add(Duration(hours: 8 + _random.nextInt(9), minutes: _random.nextInt(60))));
      final completedStatus = SaleStatus.completed.name;

      final batch = _fs.batch();
      batch.set(saleRef, {
        'workspaceId': wsId,
        'transactionNumber':
            'TRX-${DailySummary.dayKey(day).replaceAll('-', '')}-${seq.toString().padLeft(4, '0')}',
        'sellerId': ownerId,
        'sellerName': 'Pemilik',
        'customerId': draft.customerId,
        'customerName': draft.customerName,
        'customerWhatsapp': draft.customerWhatsapp,
        'transactionType': TransactionType.SALE.name,
        'orderType': draft.orderType.name,
        'items': items.map((e) => e.toMap()).toList(),
        'subtotal': subtotal,
        'discountAmount': 0,
        'taxPercent': 0,
        'taxAmount': 0,
        'shippingCost': 0,
        'grandTotal': grandTotal,
        'paidAmount': paidAmount,
        'remainingAmount': grandTotal - paidAmount,
        'paymentMethodId': '',
        'paymentMethodName': draft.paymentMethodName,
        'paymentStatus': paidAmount >= grandTotal
            ? PaymentStatus.paid.name
            : PaymentStatus.partial.name,
        'status': isPreOrder &&
                day.isAfter(DateTime.now().subtract(const Duration(days: 5)))
            ? SaleStatus.processing.name
            : completedStatus,
        'countsRevenue': !(isPreOrder &&
            day.isAfter(DateTime.now().subtract(const Duration(days: 5)))),
        'estimatedCompletionDate': draft.estimatedCompletionDate == null
            ? null
            : Timestamp.fromDate(draft.estimatedCompletionDate!),
        'notes': '',
        'statusHistory': [
          {
            'status': completedStatus,
            'at': createdAt,
            'byUserId': ownerId,
            'note': ''
          }
        ],
        'stockDeducted': true,
        'offlineCreated': false,
        'createdAt': createdAt,
        'updatedAt': createdAt,
        'completedAt': createdAt,
      });

      if (paidAmount > 0) {
        batch.set(
          _sub(wsId, Collections.cashTransactions).doc(),
          CashTransaction(
            workspaceId: wsId,
            type: CashTransactionType.income,
            category:
                paidAmount < grandTotal ? 'Pembayaran DP' : 'Penjualan',
            amount: paidAmount,
            occurredAt: day.add(const Duration(hours: 9)),
            paymentMethodName: draft.paymentMethodName,
            sourceSaleId: saleRef.id,
            sourceType: 'SALE',
            description: 'Pembayaran penjualan',
            createdBy: ownerId,
          ).toCreateMap(occurredAt: day),
        );
      }

      batch.set(
        _sub(wsId, Collections.dailySummaries).doc(DailySummary.dayKey(day)),
        DailySummary.incrementMap(
          revenueDelta: grandTotal,
          orderDelta: 1,
          profitDelta: subtotal -
              items.fold(
                  0, (s, it) => s + ((it.costPrice ?? 0) * it.qty)),
          hasUnknownCosts: items.any((i) => i.costPrice == null),
        ),
        SetOptions(merge: true),
      );

      if (draft.customerId != null) {
        batch.update(
          _sub(wsId, Collections.customers).doc(draft.customerId),
          {
            'totalSpent': FieldValue.increment(grandTotal),
            'totalTransactions': FieldValue.increment(1),
          },
        );
      }

      await batch.commit();
      return 1;
    } catch (e) {
      Logger.e('demo sale failed', e);
      return 0;
    }
  }

  Future<Map<String, List<Product>>> _seedProducts(
      String wsId, DemoTemplate template) async {
    final result = <String, List<Product>>{};
    final categoryNames = <String, String>{};

    final catalog = switch (template) {
      DemoTemplate.physicalStore => [
        ('Makanan', [
          ('Keripik Singkong Original', 8000, 12000, 'pcs', 120, 20, true),
          ('Keripik Balado', 8500, 13000, 'pcs', 90, 15, true),
          ('Abon Ikan 250gr', 28000, 40000, 'pack', 35, 10, true),
          ('Sambal Homemade', 12000, 20000, 'toples', 40, 8, true),
          ('Kopi Bubuk Robusta', 35000, 55000, 'pack', 25, 5, true),
        ]),
        ('Minuman', [
          ('Es Teh Jumbo', 2000, 5000, 'cup', 200, 50, true),
          ('Es Jeruk Peras', 3000, 7000, 'cup', 150, 30, true),
        ]),
      ],
      DemoTemplate.digitalProducts => [
        ('E-Book', [
          ('Panduan UMKM Digital (PDF)', 15000, 75000, 'lisensi', 999, 0, false),
          ('Template Invoice Excel', 10000, 45000, 'lisensi', 999, 0, false),
          ('Ebook Resep Andalan', 12000, 50000, 'lisensi', 999, 0, false),
        ]),
        ('Kelas Online', [
          ('Kelas Desain Canva', 50000, 199000, 'akses', 999, 0, false),
          ('Kelas Marketing WhatsApp', 60000, 249000, 'akses', 999, 0, false),
        ]),
        ('Lisensi Aset', [
          ('Font Kustom Lisensi Komersial', 40000, 150000, 'lisensi', 50, 0, false),
        ]),
      ],
      DemoTemplate.serviceBusiness => [
        ('Servis Ringan', [
          ('Servis Rutin Motor', 20000, 45000, 'unit', 0, 0, false),
          ('Ganti Oli + Filter', 35000, 65000, 'unit', 0, 0, false),
          ('Servis Rem Depan', 25000, 55000, 'unit', 0, 0, false),
        ]),
        ('Servis Berat', [
          ('Overhaul Mesin', 350000, 750000, 'unit', 0, 0, false),
          ('Perbaikan Rangka', 200000, 400000, 'unit', 0, 0, false),
        ]),
        ('Sparepart', [
          ('Oli Mesin 1L', 45000, 65000, 'botol', 30, 8, true),
          ('Kampas Rem', 35000, 55000, 'pasang', 18, 5, true),
          ('Busi Iridium', 40000, 60000, 'pcs', 22, 6, true),
        ]),
      ],
      DemoTemplate.hybrid => [
        ('Kue Basah', [
          ('Bolu Pandan', 15000, 25000, 'box', 40, 10, true),
          ('Brownies Klasik', 25000, 40000, 'box', 30, 8, true),
        ]),
        ('Hampers', [
          ('Hampers Lebaran Standard', 85000, 150000, 'set', 25, 5, true),
          ('Hampers Premium', 150000, 275000, 'set', 12, 3, true),
        ]),
        ('Kelas Baking', [
          ('Kelas Buttercream Offline', 100000, 350000, 'kursi', 999, 0, false),
        ]),
        ('Jasa Dekorasi', [
          ('Dekorasi Birthday Simple', 150000, 400000, 'acara', 0, 0, false),
        ]),
      ],
    };

    for (final entry in catalog) {
      final catName = entry.$1;
      final catRef = await _sub(wsId, Collections.categories).add({
        'name': catName,
        'description': '',
        'parentId': null,
        'productType': null,
        'archived': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      categoryNames[catRef.id] = catName;
      final products = <Product>[];
      for (final p in entry.$2) {
        final isPhysical = p.$7;
        final isServiceLike =
            !isPhysical && p.$5 == 0 && template != DemoTemplate.digitalProducts;
        final ref = await _sub(wsId, Collections.products).add({
          'name': p.$1,
          'sku': 'SKU-${_random.nextInt(90000) + 10000}',
          'barcode': '',
          'categoryId': catRef.id,
          'type': isPhysical
              ? ProductType.physicalProduct.name
              : (isServiceLike
                  ? ProductType.service.name
                  : ProductType.digitalProduct.name),
          'costPrice': p.$2,
          'sellingPrice': p.$3,
          'unit': p.$4,
          'trackStock': isPhysical,
          'unlimitedStock':
              !isPhysical && !isServiceLike && p.$5 >= 999,
          'stock': isPhysical ? p.$5 : 0,
          'minStock': p.$6,
          'licenseCount':
              (!isPhysical && !isServiceLike && p.$5 > 0 && p.$5 < 999)
                  ? p.$5
                  : null,
          'imageUrl': null,
          'description': '',
          'isActive': true,
          'archived': false,
          'soldCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final snap = await ref.get();
        products.add(Product.fromDoc(snap));
      }
      result[catRef.id] = products;
    }
    _categoryNamesCache = categoryNames;
    return result;
  }

  Map<String, String> _categoryNamesCache = {};

  Future<List<Map<String, dynamic>>> _seedCustomers(String wsId) async {
    final names = [
      ('Ibu Sari', '081234567001'),
      ('Pak Budi', '081234567002'),
      ('Warung Mbak Yuli', '081234567003'),
      ('Andi Prasetyo', '081234567004'),
      ('Kantin Sekolah Harapan', '081234567005'),
      ('Rina Katering', '081234567006'),
      ('Toko Berkah', '081234567007'),
      ('Mas Dedi', '081234567008'),
      ('Bu Ratna', '081234567009'),
      ('Koperasi Sejahtera', '081234567010'),
    ];
    final result = <Map<String, dynamic>>[];
    for (final n in names) {
      final ref = await _sub(wsId, Collections.customers).add({
        'name': n.$1,
        'whatsapp': n.$2,
        'email': '',
        'address': '',
        'notes': '',
        'totalTransactions': 0,
        'totalSpent': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      result.add({'id': ref.id, 'name': n.$1, 'whatsapp': n.$2});
    }
    return result;
  }

  Future<void> _seedExpenses(String wsId, String ownerId) async {
    final expenses = [
      ('Biaya Operasional', 150000, 12),
      ('Transportasi', 75000, 8),
      ('Listrik & Air', 320000, 5),
      ('Internet', 150000, 3),
      ('Marketing', 200000, 10),
      ('Pembelian Stok', 500000, 20),
      ('Sewa Tempat', 750000, 1),
    ];
    final now = DateTime.now();
    for (final e in expenses) {
      for (var monthBack = 1; monthBack >= 0; monthBack--) {
        final occurredAt = DateTime(now.year, now.month - monthBack, min(e.$3, 28), 10);
        await _sub(wsId, Collections.cashTransactions).add(
          CashTransaction(
            workspaceId: wsId,
            type: CashTransactionType.expense,
            category: e.$1,
            amount: e.$2 + _random.nextInt(50000),
            occurredAt: occurredAt.isBefore(now) ? occurredAt : now,
            description: '${e.$1} bulanan',
            createdBy: ownerId,
          ).toCreateMap(occurredAt: occurredAt.isBefore(now) ? occurredAt : now),
        );
      }
    }
  }

  CollectionReference<Map<String, dynamic>> _sub(String wsId, String name) =>
      _fs.collection(Collections.workspaces).doc(wsId).collection(name);
}
