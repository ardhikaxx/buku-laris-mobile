import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/enums.dart';
import '../../models/sale_model.dart';
import 'formatters.dart';

class ReceiptPrinter {
  ReceiptPrinter._();

  /// Mencetak atau menampilkan pratinjau struk thermal (58mm / 80mm)
  static Future<void> printReceipt({
    required Sale sale,
    required String storeName,
    String? cashierName,
    bool is80mm = false,
  }) async {
    final doc = pw.Document();

    final pageFormat = is80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
    final fontSizeSmall = is80mm ? 8.5 : 7.0;
    final fontSizeNormal = is80mm ? 10.0 : 8.5;
    final fontSizeTitle = is80mm ? 14.0 : 12.0;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header Toko
              pw.Center(
                child: pw.Text(
                  storeName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: fontSizeTitle,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 3),
              _pwDivider(),

              // Info Transaksi
              _pwRow('No. Struk', sale.transactionNumber, fontSizeSmall),
              _pwRow('Tanggal', dateTimeShort(sale.createdAt), fontSizeSmall),
              if (cashierName != null && cashierName.trim().isNotEmpty)
                _pwRow('Kasir', cashierName, fontSizeSmall),
              if (sale.customerName.trim().isNotEmpty)
                _pwRow('Pelanggan', sale.customerName, fontSizeSmall),
              if (sale.notes.trim().isNotEmpty)
                _pwRow('Catatan', sale.notes, fontSizeSmall),

              _pwDivider(),

              // Rincian Item Belanja
              for (final item in sale.items) ...[
                pw.Text(
                  item.productName,
                  style: pw.TextStyle(
                    fontSize: fontSizeNormal,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '  x ',
                      style: pw.TextStyle(fontSize: fontSizeSmall),
                    ),
                    pw.Text(
                      money(item.lineTotal),
                      style: pw.TextStyle(
                        fontSize: fontSizeNormal,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
              ],

              _pwDivider(),

              // Rincian Nominal
              if (sale.discountAmount > 0)
                _pwRow('Diskon', '-', fontSizeSmall),
              if (sale.taxAmount > 0)
                _pwRow('Pajak', money(sale.taxAmount), fontSizeSmall),
              if (sale.shippingCost > 0)
                _pwRow('Ongkir', money(sale.shippingCost), fontSizeSmall),

              // Total Utama
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: fontSizeNormal + 2,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    money(sale.grandTotal),
                    style: pw.TextStyle(
                      fontSize: fontSizeNormal + 2,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),

              _pwRow('Metode', sale.paymentMethodName.isEmpty ? 'Tunai' : sale.paymentMethodName, fontSizeSmall),
              _pwRow('Dibayar', money(sale.paidAmount), fontSizeSmall),

              if (sale.paidAmount > sale.grandTotal)
                _pwRow('Kembalian', money(sale.paidAmount - sale.grandTotal), fontSizeNormal, bold: true)
              else if (sale.remainingAmount > 0)
                _pwRow('Sisa Tagihan', money(sale.remainingAmount), fontSizeNormal, bold: true),

              _pwDivider(),

              // Footer Struk
              pw.Center(
                child: pw.Text(
                  sale.paymentStatus == PaymentStatus.paid ||
                          sale.paidAmount >= sale.grandTotal
                      ? 'LUNAS'
                      : 'BELUM LUNAS',
                  style: pw.TextStyle(
                    fontSize: fontSizeNormal,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Terima kasih telah berbelanja!',
                  style: pw.TextStyle(fontSize: fontSizeSmall),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 6),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Struk_',
    );
  }

  static pw.Widget _pwDivider() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        '------------------------------------------------',
        maxLines: 1,
        style: const pw.TextStyle(fontSize: 7),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _pwRow(String label, String value, double fontSize,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
