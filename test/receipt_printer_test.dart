import 'package:flutter_test/flutter_test.dart';
import 'package:buku_laris/core/utils/receipt_printer.dart';
import 'package:buku_laris/models/enums.dart';
import 'package:buku_laris/models/sale_model.dart';
import 'package:buku_laris/core/utils/formatters.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initLocale();
  });

  group('ReceiptPrinter PDF Generation', () {
    final testSale = Sale(
      id: 'sale_1',
      workspaceId: 'ws_1',
      transactionNumber: 'TRX-20260826-0001',
      sellerId: 'user_1',
      sellerName: 'Kasir Utama',
      customerName: 'Budi Santoso',
      orderType: OrderType.readyStock,
      items: const [
        SaleItem(
          productId: 'p1',
          productName: 'Kopi Susu Gula Aren',
          type: ProductType.physicalProduct,
          qty: 2,
          unit: 'cup',
          unitPrice: 18000,
        ),
        SaleItem(
          productId: 'p2',
          productName: 'Roti Bakar Coklat Keju',
          type: ProductType.physicalProduct,
          qty: 1,
          unit: 'porsi',
          unitPrice: 20000,
        ),
      ],
      subtotal: 56000,
      discountAmount: 6000,
      grandTotal: 50000,
      paidAmount: 50000,
      paymentMethodName: 'QRIS',
      paymentStatus: PaymentStatus.paid,
      status: SaleStatus.completed,
      createdAt: DateTime.now(),
    );

    test('generates valid 58mm thermal receipt PDF bytes', () async {
      final bytes = await ReceiptPrinter.generateReceiptPdf(
        sale: testSale,
        storeName: 'Kopi Berkah Jaya',
        cashierName: 'Kasir Utama',
        is80mm: false,
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });

    test('generates valid 80mm thermal receipt PDF bytes', () async {
      final bytes = await ReceiptPrinter.generateReceiptPdf(
        sale: testSale,
        storeName: 'Kopi Berkah Jaya',
        cashierName: 'Kasir Utama',
        is80mm: true,
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });
  });
}
