import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/enums.dart';
import '../../models/sale_model.dart';
import '../../services/logger.dart';
import 'formatters.dart';

class ReceiptPrinter {
  ReceiptPrinter._();

  /// Menghasilkan bytes PDF struk thermal (58mm / 80mm)
  static Future<Uint8List> generateReceiptPdf({
    required Sale sale,
    required String storeName,
    String? cashierName,
    bool is80mm = false,
  }) async {
    final doc = pw.Document();

    final pageFormat = is80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
    final fontSizeSmall = is80mm ? 8.5 : 7.0;
    final fontSizeNormal = is80mm ? 10.0 : 8.0;
    final fontSizeTitle = is80mm ? 13.0 : 11.0;

    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      fontRegular = await PdfGoogleFonts.robotoMonoRegular();
      fontBold = await PdfGoogleFonts.robotoMonoBold();
    } catch (_) {
      fontRegular = pw.Font.courier();
      fontBold = pw.Font.courierBold();
    }

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header Nama Toko
              pw.Center(
                child: pw.Text(
                  storeName.toUpperCase().trim(),
                  style: pw.TextStyle(
                    fontSize: fontSizeTitle,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 2),
              _pwDivider(),

              // Metadata Transaksi
              _pwRow('No. Struk', sale.transactionNumber, fontSizeSmall),
              _pwRow('Tanggal', dateTimeShort(sale.createdAt), fontSizeSmall),
              if (cashierName != null && cashierName.trim().isNotEmpty)
                _pwRow('Kasir', cashierName.trim(), fontSizeSmall),
              if (sale.customerName.trim().isNotEmpty)
                _pwRow('Pelanggan', sale.customerName.trim(), fontSizeSmall),
              if (sale.notes.trim().isNotEmpty)
                _pwRow('Catatan', sale.notes.trim(), fontSizeSmall),

              _pwDivider(),

              // Daftar Item Belanja
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
                      '${number(item.qty)} ${item.unit} x ${money(item.unitPrice)}',
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

              // Subtotal & Kalkulasi
              if (sale.discountAmount > 0)
                _pwRow('Diskon', '-${money(sale.discountAmount)}', fontSizeSmall),
              if (sale.taxAmount > 0)
                _pwRow('Pajak', money(sale.taxAmount), fontSizeSmall),
              if (sale.shippingCost > 0)
                _pwRow('Ongkir', money(sale.shippingCost), fontSizeSmall),

              // Total Tagihan
              pw.SizedBox(height: 2),
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

              _pwRow(
                'Metode',
                sale.paymentMethodName.isEmpty ? 'Tunai' : sale.paymentMethodName,
                fontSizeSmall,
              ),
              _pwRow('Dibayar', money(sale.paidAmount), fontSizeSmall),

              if (sale.paidAmount > sale.grandTotal)
                _pwRow(
                  'Kembalian',
                  money(sale.paidAmount - sale.grandTotal),
                  fontSizeNormal,
                  bold: true,
                )
              else if (sale.remainingAmount > 0)
                _pwRow(
                  'Sisa Tagihan',
                  money(sale.remainingAmount),
                  fontSizeNormal,
                  bold: true,
                ),

              _pwDivider(),

              // Footer Status & Ucapan
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

    return doc.save();
  }

  /// Mencetak atau menampilkan dialog cetak struk thermal (58mm / 80mm)
  static Future<void> printReceipt({
    required Sale sale,
    required String storeName,
    String? cashierName,
    bool is80mm = false,
  }) async {
    try {
      final pdfBytes = await generateReceiptPdf(
        sale: sale,
        storeName: storeName,
        cashierName: cashierName,
        is80mm: is80mm,
      );

      await Printing.layoutPdf(
        name: 'Struk_${sale.transactionNumber}',
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      Logger.e('Print receipt failed', e);
      rethrow;
    }
  }

  static pw.Widget _pwDivider() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(
        '------------------------------------------',
        maxLines: 1,
        style: const pw.TextStyle(fontSize: 6.5),
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
