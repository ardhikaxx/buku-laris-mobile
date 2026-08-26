import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common.dart';
import '../../../models/enums.dart';
import '../../../models/payment_method_model.dart';
import '../../../models/sale_model.dart';
import '../../../core/utils/receipt_printer.dart';

class SaleDetailScreen extends ConsumerStatefulWidget {
  final String saleId;

  const SaleDetailScreen({super.key, required this.saleId});

  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  bool _busy = false;

  Future<void> _changeStatus(Sale sale, SaleStatus newStatus,
      {bool destructive = false}) async {
    final confirmed = await confirmAction(
      context,
      title: 'Ubah status ke "${newStatus.label}"?',
      message: switch (newStatus) {
        SaleStatus.cancelled =>
          'Stok akan dikembalikan dan pembayaran yang diterima dicatat sebagai pengembalian dana.',
        SaleStatus.refunded =>
          'Penjualan dibatalkan sepenuhnya, stok dikembalikan, dan dana pelanggan dicatat sebagai pengeluaran refund.',
        SaleStatus.processing =>
          sale.isPreOrder
              ? 'Stok item fisik pada pre-order ini akan mulai dikurangi.'
              : 'Pesanan akan ditandai sedang diproses.',
        _ => 'Lanjutkan perubahan status pesanan?',
      },
      destructive: destructive,
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      final gate = ref.read(gateProvider);
      final wsId = gate.activeWorkspaceId!;
      final user = ref.read(authServiceProvider).currentUser!;
      final ws = ref.read(activeWorkspaceProvider).workspace;
      await ref.read(saleRepositoryProvider).changeStatus(
            wsId: wsId,
            sale: sale,
            newStatus: newStatus,
            actorId: user.uid,
            actorName: gate.profile?.displayName ?? '',
            deductOnConfirm: ws?.settings.preOrderDeductOnConfirm ?? false,
            allowOverselling: ws?.settings.allowOverselling ?? false,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordPayment(Sale sale) async {
    final controller = TextEditingController();
    final methods = await ref
        .read(workspaceRepositoryProvider)
        .listPaymentMethods(sale.workspaceId, onlyActive: true);
    if (!mounted) return;
    PaymentMethodModel? method =
        methods.isEmpty ? null : methods.first;

    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Catat Pembayaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sisa tagihan: ${money(sale.remainingAmount)}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [AmountInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Nominal bayar',
                  prefixText: 'Rp ',
                  suffixIcon: TextButton(
                    onPressed: () => setState(() =>
                        controller.text = number(sale.remainingAmount)),
                    child: const Text('Sisa', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<PaymentMethodModel>(
                isExpanded: true,
                initialValue: method,
                decoration:
                    const InputDecoration(labelText: 'Metode pembayaran'),
                items: methods
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                    .toList(),
                onChanged: (m) => setState(() => method = m),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final value = Validators.parseAmount(controller.text);
                Navigator.pop(ctx, value > 0 ? value : null);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (amount == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final user = ref.read(authServiceProvider).currentUser!;
      await ref.read(saleRepositoryProvider).addPayment(
            wsId: sale.workspaceId,
            sale: sale,
            amount: amount,
            actorId: user.uid,
            actorName:
                ref.read(gateProvider).profile?.displayName ?? '',
            paymentMethodId: method?.id ?? sale.paymentMethodId,
            paymentMethodName: method?.name ?? sale.paymentMethodName,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalizeOffline(Sale sale) async {
    final confirmed = await confirmAction(
      context,
      title: 'Proses stok transaksi offline?',
      message:
          'Transaksi ini dibuat saat offline. Stok akan dikurangi sekarang setelah koneksi tersedia.',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      final ws = ref.read(activeWorkspaceProvider).workspace;
      final user = ref.read(authServiceProvider).currentUser!;
      await ref.read(saleRepositoryProvider).finalizeOfflineSale(
            wsId: sale.workspaceId,
            sale: sale,
            allowOverselling: ws?.settings.allowOverselling ?? false,
            actorId: user.uid,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printThermalReceipt(Sale sale, String storeName) async {
    setState(() => _busy = true);
    try {
      final gate = ref.read(gateProvider);
      final cashierName = gate.profile?.displayName ?? '';
      await ReceiptPrinter.printReceipt(
        sale: sale,
        storeName: storeName.isEmpty ? 'BUKU LARIS POS' : storeName,
        cashierName: cashierName,
      );
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mencetak struk: $msg'),
          backgroundColor: AppColors.expense,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _shareInvoice(Sale sale, String workspaceName) {
    final buffer = StringBuffer();
    buffer.writeln('=== $workspaceName ===');
    buffer.writeln('No: ${sale.transactionNumber}');
    buffer.writeln(
        'Tanggal: ${dateTimeShort(sale.createdAt)}');
    if (sale.customerName.isNotEmpty) {
      buffer.writeln('Pelanggan: ${sale.customerName}');
    }
    buffer.writeln('------------------------------');
    for (final item in sale.items) {
      buffer.writeln(item.productName);
      buffer.writeln(
          '${item.qty} ${item.unit} x ${money(item.unitPrice)} = ${money(item.lineTotal)}');
    }
    buffer.writeln('------------------------------');
    if (sale.discountAmount > 0) buffer.writeln('Diskon: -${money(sale.discountAmount)}');
    if (sale.taxAmount > 0) buffer.writeln('Pajak: ${money(sale.taxAmount)}');
    if (sale.shippingCost > 0) buffer.writeln('Ongkir: ${money(sale.shippingCost)}');
    buffer.writeln('TOTAL: ${money(sale.grandTotal)}');
    buffer.writeln('Dibayar: ${money(sale.paidAmount)}');
    if (sale.remainingAmount > 0) {
      buffer.writeln('SISA: ${money(sale.remainingAmount)}');
    }
    buffer.writeln('Status: ${sale.status.label}');
    buffer.writeln('Metode: ${sale.paymentMethodName}');
    buffer.writeln('');
    buffer.writeln('Terima kasih telah berbelanja!');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Struk disalin ke clipboard')),
    );

    if (sale.customerWhatsapp.isNotEmpty) {
      final url =
          'https://wa.me/${formatWhatsappLink(sale.customerWhatsapp).split('/').last}?text=${Uri.encodeComponent(buffer.toString())}';
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
          .catchError((_) => false);
    }
  }

  Future<void> _editNotes(Sale sale) async {
    final controller = TextEditingController(text: sale.notes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Keterangan'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          minLines: 1,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Keterangan / Catatan',
            hintText: 'Contoh: Tambahan catatan pesanan...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final wsId = ref.read(gateProvider).activeWorkspaceId!;
      await ref
          .read(saleRepositoryProvider)
          .updateNotes(wsId, sale.id, controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Keterangan berhasil diperbarui'),
          backgroundColor: AppColors.income,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wsId = ref.watch(gateProvider).activeWorkspaceId;
    if (wsId == null) return const SizedBox.shrink();

    final canEditStatus = ref.watch(activeWorkspaceProvider).can(Permission.salesEditStatus);
    final canRecordPayment = ref.watch(activeWorkspaceProvider).can(Permission.salesRecordPayment);

    return StreamBuilder<Sale?>(
      stream: ref.read(saleRepositoryProvider).watchById(wsId, widget.saleId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final sale = snapshot.data;
        if (sale == null) {
          return const Scaffold(
            appBar: FloatingCapsuleAppBar(
              showBackButton: true,
              titleText: 'Detail Penjualan',
            ),
            body: ErrorStateView(
                error: AppException('Transaksi tidak ditemukan.')),
          );
        }
        final workspaceName =
            ref.watch(activeWorkspaceProvider).workspace?.name ?? '';

        return Scaffold(
          appBar: FloatingCapsuleAppBar(
            showBackButton: true,
            onBackPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/sales');
              }
            },
            titleText: sale.transactionNumber,
            subtitleText: dateTimeShort(sale.createdAt),
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              StatusChip(sale.status.label, sale.status.color),
                              StatusChip(_paymentLabel(sale.paymentStatus),
                                  _paymentColor(sale.paymentStatus)),
                            ],
                          ),
                          if (sale.offlineCreated) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.cloud_off_rounded,
                                      size: 16, color: Color(0xFFB45309)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Dibuat saat offline — stok belum diproses. Tekan "Proses Stok" saat koneksi normal.',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.45,
                                          color: Colors.amber[900]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SectionHeader('Item'),
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < sale.items.length; i++) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(sale.items[i].productName,
                                          style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${number(sale.items[i].qty)} ${sale.items[i].unit} x ${money(sale.items[i].unitPrice)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(money(sale.items[i].lineTotal),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          if (i < sale.items.length - 1)
                            const Divider(indent: 14, endIndent: 14),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SectionHeader('Rincian Pembayaran'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          InfoRow(label: 'Subtotal', value: money(sale.subtotal)),
                          if (sale.discountAmount > 0)
                            InfoRow(label: 'Diskon', value: '-${money(sale.discountAmount)}'),
                          if (sale.taxAmount > 0)
                            InfoRow(
                                label: 'Pajak (${number(sale.taxPercent)}%)',
                                value: money(sale.taxAmount)),
                          if (sale.shippingCost > 0)
                            InfoRow(label: 'Ongkir', value: money(sale.shippingCost)),
                          const Divider(height: 18),
                          InfoRow(
                            label: 'Total',
                            value: money(sale.grandTotal),
                            valueColor: AppColors.primaryDark,
                          ),
                          InfoRow(label: 'Dibayar', value: money(sale.paidAmount)),
                          if (sale.remainingAmount > 0)
                            InfoRow(
                              label: 'Sisa',
                              value: money(sale.remainingAmount),
                              valueColor: AppColors.warning,
                            ),
                          InfoRow(label: 'Metode', value: sale.paymentMethodName),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SectionHeader('Informasi'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          InfoRow(
                              label: 'Jenis',
                              value: sale.orderType.label),
                          InfoRow(
                              label: 'Kasir',
                              value: sale.sellerName.isEmpty
                                  ? '-'
                                  : sale.sellerName),
                          if (sale.customerName.isNotEmpty)
                            InfoRow(
                                label: 'Pelanggan',
                                value: sale.customerWhatsapp.isEmpty
                                    ? sale.customerName
                                    : '${sale.customerName} (${sale.customerWhatsapp})'),
                          if (sale.estimatedCompletionDate != null)
                            InfoRow(
                                label: 'Estimasi Selesai',
                                value: dateFull(sale.estimatedCompletionDate)),
                          InkWell(
                            onTap: () => _editNotes(sale),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Text('Keterangan',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  Flexible(
                                    child: Text(
                                      sale.notes.isEmpty
                                          ? '+ Tambah catatan'
                                          : sale.notes,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: sale.notes.isEmpty
                                            ? AppColors.primary
                                            : const Color(0xFF111827),
                                        fontStyle: sale.notes.isEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit_outlined,
                                      size: 14, color: Colors.grey[400]),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SectionHeader('Struk & Cetak Nota'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                  onPressed: () => _printThermalReceipt(
                                      sale, workspaceName),
                                  icon: const Icon(Icons.print_rounded,
                                      size: 18),
                                  label: const Text(
                                    'Cetak Struk Thermal',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                tooltip: 'Kirim / Bagikan Struk Digital',
                                icon: const Icon(Icons.share_outlined,
                                    size: 18, color: AppColors.primary),
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  side: BorderSide(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.3)),
                                ),
                                onPressed: () =>
                                    _shareInvoice(sale, workspaceName),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Format struk kasir Bluetooth & USB (kertas 58mm / 80mm)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SectionHeader('Histori Status'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          for (var i = 0; i < sale.statusHistory.length; i++)
                            _HistoryTile(
                              event: sale.statusHistory[i],
                              isLast: i == sale.statusHistory.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_busy)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(sale, canEditStatus, canRecordPayment),
        );
      },
    );
  }

  Widget _buildBottomBar(
      Sale sale, bool canEditStatus, bool canRecordPayment) {
    final actions = <Widget>[];
    if (sale.offlineCreated) {
      actions.add(FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        onPressed: () => _finalizeOffline(sale),
        icon: const Icon(Icons.sync_rounded, size: 18),
        label: const Text('Proses Stok'),
      ));
    } else {
      if (canRecordPayment &&
          sale.remainingAmount > 0 &&
          sale.paymentStatus != PaymentStatus.refunded) {
        actions.add(OutlinedButton.icon(
          onPressed: () => _recordPayment(sale),
          icon: const Icon(Icons.payments_outlined, size: 17),
          label: const Text('Bayar'),
        ));
      }
      if (canEditStatus && !sale.status.isActiveOrder && sale.status != SaleStatus.completed) {
        // no transitions available
      }
      if (canEditStatus) {
        for (final next in _nextStatuses(sale)) {
          actions.add(FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  next == SaleStatus.cancelled || next == SaleStatus.refunded
                      ? AppColors.expense
                      : AppColors.primary,
            ),
            onPressed: () => _changeStatus(sale, next,
                destructive:
                    next == SaleStatus.cancelled || next == SaleStatus.refunded),
            child: Text(_actionLabel(next), style: const TextStyle(fontSize: 13)),
          ));
        }
      }
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: actions[i]),
            ],
          ],
        ),
      ),
    );
  }

  List<SaleStatus> _nextStatuses(Sale sale) {
    switch (sale.status) {
      case SaleStatus.draft:
        return [SaleStatus.confirmed, SaleStatus.cancelled];
      case SaleStatus.pending:
        return [SaleStatus.confirmed, SaleStatus.cancelled];
      case SaleStatus.confirmed:
        return [SaleStatus.processing, SaleStatus.cancelled];
      case SaleStatus.processing:
        return [SaleStatus.ready, SaleStatus.cancelled];
      case SaleStatus.ready:
        return [SaleStatus.completed];
      case SaleStatus.completed:
        return [SaleStatus.refunded];
      default:
        return [];
    }
  }

  String _actionLabel(SaleStatus status) => switch (status) {
        SaleStatus.confirmed => 'Konfirmasi',
        SaleStatus.processing => 'Proses',
        SaleStatus.ready => 'Siap',
        SaleStatus.completed => 'Selesai',
        SaleStatus.cancelled => 'Batalkan',
        SaleStatus.refunded => 'Refund',
        _ => status.label,
      };

  String _paymentLabel(PaymentStatus s) => s.label;

  Color _paymentColor(PaymentStatus s) => switch (s) {
        PaymentStatus.paid => AppColors.income,
        PaymentStatus.partial => AppColors.warning,
        PaymentStatus.unpaid => AppColors.expense,
        PaymentStatus.refunded => const Color(0xFFB45309),
      };
}

class _HistoryTile extends StatelessWidget {
  final SaleStatusEvent event;
  final bool isLast;

  const _HistoryTile({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: event.status.color,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1.5, color: const Color(0xFFE5E7EB)),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.status.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: event.status.color)),
                  Text(dateTimeShort(event.at),
                      style:
                          TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
