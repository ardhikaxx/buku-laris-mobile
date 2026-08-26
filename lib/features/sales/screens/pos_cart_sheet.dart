import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common.dart';
import '../../../models/customer_model.dart';
import '../../../models/enums.dart';
import '../../../models/payment_method_model.dart';
import '../../../models/sale_model.dart';
import '../../../repositories/sale_repository.dart';
import '../../../services/logger.dart';
import 'pos_screen.dart';

class PosCartSheet extends ConsumerStatefulWidget {
  final PosScreenState pos;

  const PosCartSheet({super.key, required this.pos});

  @override
  ConsumerState<PosCartSheet> createState() => _PosCartSheetState();
}

class _PosCartSheetState extends ConsumerState<PosCartSheet> {
  final _discountController = TextEditingController();
  final _shippingController = TextEditingController();
  final _paidController = TextEditingController();
  final _notesController = TextEditingController();
  List<PaymentMethodModel> _methods = [];
  PaymentMethodModel? _selectedMethod;
  bool _saving = false;
  String? _error;

  PosScreenState get _pos => widget.pos;

  @override
  void initState() {
    super.initState();
    final pos = widget.pos;
    if (pos.discountAmount > 0) {
      _discountController.text = number(pos.discountAmount);
    }
    if (pos.shippingCost > 0) {
      _shippingController.text = number(pos.shippingCost);
    }
    if (pos.paidOverride >= 0) {
      _paidController.text = number(pos.paidOverride);
    }
    _notesController.text = pos.notesController.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMethods());
  }

  @override
  void dispose() {
    _discountController.dispose();
    _shippingController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMethods() async {
    final wsId = ref.read(gateProvider).activeWorkspaceId;
    final defaults = DefaultPaymentMethods.defaults();
    if (wsId == null) {
      setState(() {
        _methods = defaults;
        _selectedMethod = defaults.first;
      });
      return;
    }
    try {
      final methods = await ref
          .read(workspaceRepositoryProvider)
          .listPaymentMethods(wsId, onlyActive: true);
      if (!mounted) return;
      setState(() {
        if (methods.isEmpty) {
          _methods = defaults;
        } else {
          _methods = methods;
        }
        _selectedMethod = _methods.firstWhere(
          (m) => m.type == 'CASH' || m.name.toLowerCase().contains('tunai'),
          orElse: () => _methods.first,
        );
      });
    } catch (e) {
      Logger.e('cart load payment methods failed', e);
      if (mounted) {
        setState(() {
          _methods = defaults;
          _selectedMethod = defaults.first;
        });
      }
    }
  }

  IconData _paymentMethodIcon(String type, String name) {
    final t = type.toUpperCase();
    final n = name.toLowerCase();
    if (t == 'CASH' || n.contains('tunai') || n.contains('cash')) {
      return Icons.payments_rounded;
    }
    if (t == 'BANK_TRANSFER' || n.contains('transfer') || n.contains('bank')) {
      return Icons.account_balance_rounded;
    }
    if (t == 'QRIS' || n.contains('qris')) {
      return Icons.qr_code_2_rounded;
    }
    if (t == 'EWALLET' ||
        n.contains('gopay') ||
        n.contains('ovo') ||
        n.contains('dana') ||
        n.contains('shopee')) {
      return Icons.wallet_rounded;
    }
    if (t == 'CARD' ||
        n.contains('debit') ||
        n.contains('kredit') ||
        n.contains('kartu')) {
      return Icons.credit_card_rounded;
    }
    return Icons.payment_rounded;
  }

  List<int> _getQuickAmounts(int total) {
    if (total <= 0) return [10000, 20000, 50000, 100000];
    final set = <int>{};
    set.add(total); // Uang Pas

    // Next nearest roundups
    if (total % 5000 != 0) {
      final round5k = ((total / 5000).ceil()) * 5000;
      if (round5k > total) set.add(round5k);
    }
    if (total % 10000 != 0) {
      final round10k = ((total / 10000).ceil()) * 10000;
      if (round10k > total) set.add(round10k);
    }
    if (total % 20000 != 0) {
      final round20k = ((total / 20000).ceil()) * 20000;
      if (round20k > total) set.add(round20k);
    }
    if (total % 50000 != 0) {
      final round50k = ((total / 50000).ceil()) * 50000;
      if (round50k > total) set.add(round50k);
    }
    if (total % 100000 != 0) {
      final round100k = ((total / 100000).ceil()) * 100000;
      if (round100k > total) set.add(round100k);
    }

    // Standard Indonesian Banknotes
    for (final nom in [10000, 20000, 50000, 100000, 200000, 500000]) {
      if (nom > total && set.length < 6) set.add(nom);
    }

    final list = set.toList()..sort();
    return list;
  }

  Widget _buildPaymentMethodChip(PaymentMethodModel m) {
    final isSelected = _selectedMethod?.id == m.id ||
        (_selectedMethod?.name == m.name) ||
        (_selectedMethod == null &&
            (m.type == 'CASH' || m.name.toLowerCase() == 'tunai'));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = m),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _paymentMethodIcon(m.type, m.name),
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                m.name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomer() async {
    final result = await showDialog<Customer>(
      context: context,
      builder: (_) => const _CustomerPickerDialog(),
    );
    if (result != null) {
      setState(() {
        _pos.customerId = result.id;
        _pos.customerName = result.name;
        _pos.customerWhatsapp = result.whatsapp;
      });
    }
  }

  Future<void> _quickAddCustomer() async {
    final nameController = TextEditingController();
    final waController = TextEditingController();
    final created = await showDialog<Customer>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pelanggan Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Nama pelanggan *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: waController,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Nomor WhatsApp'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                final wsId = ref.read(gateProvider).activeWorkspaceId!;
                final refDoc =
                    await ref.read(customerRepositoryProvider).create(
                          wsId,
                          Customer(
                            id: '',
                            name: nameController.text.trim(),
                            whatsapp: waController.text.trim(),
                          ),
                        );
                if (ctx.mounted) {
                  Navigator.pop(
                    ctx,
                    Customer(id: refDoc.id, name: nameController.text.trim(), whatsapp: waController.text.trim()),
                  );
                }
              } catch (e) {
                Logger.e('quick add customer failed', e);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (created != null) {
      setState(() {
        _pos.customerId = created.id;
        _pos.customerName = created.name;
        _pos.customerWhatsapp = created.whatsapp;
      });
    }
  }

  Future<void> _submit() async {
    final pos = _pos;
    if (pos.itemCount == 0) return;
    final ws = ref.read(activeWorkspaceProvider).workspace;
    setState(() {
      _saving = true;
      _error = null;
    });

    pos.discountAmount = Validators.parseAmount(_discountController.text);
    pos.shippingCost = Validators.parseAmount(_shippingController.text);
    pos.notesController.text = _notesController.text.trim();

    final grandTotal = pos.grandTotal;
    var paid = Validators.parseAmount(_paidController.text);
    if (_paidController.text.isEmpty && pos.orderType == OrderType.readyStock) {
      paid = grandTotal;
    }
    if (paid > grandTotal) paid = grandTotal;

    try {
      final gate = ref.read(gateProvider);
      final wsId = gate.activeWorkspaceId!;
      final user = ref.read(authServiceProvider).currentUser!;
      final requireEstDate = ws?.settings.preOrderRequireEstDate ?? false;
      if (pos.orderType == OrderType.preOrder &&
          requireEstDate &&
          pos.estimatedDate == null) {
        throw const AppException(
            'Estimasi tanggal selesai wajib diisi untuk pre-order.');
      }
      if ((ws?.settings.requireCustomerForSale ?? false) &&
          (pos.customerId == null || pos.customerId!.isEmpty)) {
        throw const AppException(
            'Pengaturan workspace mewajibkan data pelanggan pada setiap transaksi.');
      }

      final catList = await ref.read(categoryRepositoryProvider).list(wsId);
      final catMap = {for (final c in catList) c.id: c.name};

      final draft = SaleDraft(
        orderType: pos.orderType,
        items: [
          for (final p in pos.cartProducts.values)
            SaleItem(
              productId: p.id,
              productName: p.name,
              type: p.type,
              categoryId: p.categoryId,
              categoryName: catMap[p.categoryId] ?? '',
              qty: pos.qtyInCart[p.id] ?? 0,
              unit: p.unit,
              unitPrice: p.sellingPrice,
              costPrice: p.costPrice,
            ),
        ],
        discountAmount: pos.discountAmount,
        shippingCost: pos.shippingCost,
        taxPercent: ws?.settings.taxPercent ?? 0,
        customerId: pos.customerId,
        customerName: pos.customerName,
        customerWhatsapp: pos.customerWhatsapp,
        paymentMethodId: _selectedMethod?.id ?? '',
        paymentMethodName: _selectedMethod?.name ?? '',
        paidAmount: paid,
        notes: _notesController.text.trim(),
        estimatedCompletionDate: pos.estimatedDate,
      );

      final result = await ref.read(saleRepositoryProvider).createSale(
            wsId: wsId,
            workspaceName: ws?.name ?? '',
            draft: draft,
            sellerId: user.uid,
            sellerName: gate.profile?.displayName ?? '',
            settings: WorkspaceSettingsSnapshot(
              allowOverselling: ws?.settings.allowOverselling ?? false,
              requireCustomerForSale:
                  ws?.settings.requireCustomerForSale ?? false,
              taxPercent: ws?.settings.taxPercent ?? 0,
              preOrderEnabled: ws?.supportsPreOrder ?? false,
            ),
            allowOverselling: ws?.settings.allowOverselling ?? false,
            requireEstimatedDateForPreorder: requireEstDate,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      if (result.savedOffline) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tersimpan saat offline'),
            content: const Text(
                'Koneksi internet tidak stabil. Transaksi disimpan sebagai DRAFT dan stok belum dikurangi. Buka detail transaksi lalu tekan "Proses Stok" setelah koneksi normal.'),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Mengerti')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Penjualan ${result.transactionNumber} berhasil dicatat'),
          backgroundColor: AppColors.income,
        ));
      }
      if (mounted) context.go('/sales/${result.saleId}');
    } catch (e) {
      if (mounted) setState(() => _error = mapToAppException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = _pos;
    final isPreOrder = pos.orderType == OrderType.preOrder;
    final grandTotal = pos.grandTotal;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.94,
        maxChildSize: 0.96,
        builder: (context, scrollController) => Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isPreOrder ? 'Ringkasan Pre-Order' : 'Keranjang',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        IconButton(
                            onPressed: () {
                              _pos.discountAmount =
                                  Validators.parseAmount(_discountController.text);
                              _pos.shippingCost =
                                  Validators.parseAmount(_shippingController.text);
                              _pos.notesController.text =
                                  _notesController.text.trim();
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.close_rounded, size: 20)),
                      ],
                    ),
                    ...pos.cartProducts.values.map((p) {
                      final qty = pos.qtyInCart[p.id] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600)),
                                  Text(money(p.sellingPrice),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            QtyStepper(
                              qty: qty,
                              onChanged: (q) {
                                pos.setQty(p, q);
                                setState(() {});
                              },
                            ),
                            SizedBox(
                              width: 86,
                              child: Text(
                                money(p.sellingPrice * qty),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _discountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [AmountInputFormatter()],
                            decoration: const InputDecoration(
                              labelText: 'Diskon',
                              prefixText: 'Rp ',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _shippingController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [AmountInputFormatter()],
                            decoration: const InputDecoration(
                              labelText: 'Ongkir',
                              prefixText: 'Rp ',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (isPreOrder)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                pos.estimatedDate ?? DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            locale: const Locale('id', 'ID'),
                          );
                          if (picked != null) {
                            setState(() => pos.estimatedDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Estimasi Selesai',
                            suffixIcon: Icon(pos.estimatedDate != null
                                ? Icons.event_available_rounded
                                : Icons.event_busy_rounded,
                                size: 18),
                          ),
                          child: Text(
                            pos.estimatedDate == null
                                ? 'Pilih tanggal estimasi'
                                : dateFull(pos.estimatedDate),
                            style: TextStyle(
                                fontSize: 13.5,
                                color: pos.estimatedDate == null
                                    ? Colors.grey[500]
                                    : const Color(0xFF111827)),
                          ),
                        ),
                      ),
                    if (isPreOrder) const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickCustomer,
                            icon: const Icon(Icons.person_search_rounded,
                                size: 18),
                            label: Text(
                              pos.customerName.isEmpty
                                  ? 'Pilih Pelanggan'
                                  : pos.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tambah pelanggan baru',
                          onPressed: _quickAddCustomer,
                          icon: const Icon(Icons.person_add_alt_rounded,
                              size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.payments_rounded,
                            size: 17, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Metode Pembayaran',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (final m in _methods)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildPaymentMethodChip(m),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _paidController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [AmountInputFormatter()],
                      decoration: InputDecoration(
                        labelText: isPreOrder
                            ? 'Uang Muka / DP (opsional)'
                            : 'Nominal Pembayaran / Uang Diterima',
                        prefixText: 'Rp ',
                        hintText: number(grandTotal),
                        suffixIcon: _paidController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () =>
                                    setState(() => _paidController.clear()),
                              )
                            : TextButton(
                                onPressed: () => setState(() =>
                                    _paidController.text = number(grandTotal)),
                                child: const Text('Uang Pas',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),

                    // Quick Cash Preset Buttons
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (final amount in _getQuickAmounts(grandTotal))
                            Builder(builder: (context) {
                              final currentPaid =
                                  Validators.parseAmount(_paidController.text);
                              final isUangPas = amount == grandTotal;
                              final isSelected = currentPaid == amount;

                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _paidController.text = number(amount);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isUangPas
                                              ? const Color(0xFF16A34A)
                                              : AppColors.primary)
                                          : (isUangPas
                                              ? const Color(0xFFF0FDF4)
                                              : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? (isUangPas
                                                ? const Color(0xFF16A34A)
                                                : AppColors.primary)
                                            : (isUangPas
                                                ? const Color(0xFF86EFAC)
                                                : const Color(0xFFCBD5E1)),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: (isUangPas
                                                        ? const Color(0xFF16A34A)
                                                        : AppColors.primary)
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isUangPas) ...[
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 13,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF16A34A),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          isUangPas
                                              ? 'Uang Pas (${compactMoney(amount)})'
                                              : compactMoney(amount),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: isSelected || isUangPas
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : (isUangPas
                                                    ? const Color(0xFF166534)
                                                    : const Color(0xFF334155)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final enteredAmount =
                            Validators.parseAmount(_paidController.text);
                        if (enteredAmount > grandTotal) {
                          final change = enteredAmount - grandTotal;
                          return Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF86EFAC), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.income
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons.currency_exchange_rounded,
                                      color: AppColors.income,
                                      size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Kembalian',
                                          style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF166534))),
                                      Text('Uang kembali ke pelanggan',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF15803D))),
                                    ],
                                  ),
                                ),
                                Text(
                                  money(change),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.income,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else if (enteredAmount > 0 &&
                            enteredAmount < grandTotal) {
                          final remaining = grandTotal - enteredAmount;
                          return Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFFCD34D)),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Sisa Tagihan (Belum Lunas)',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF92400E))),
                                Text(
                                  money(remaining),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      minLines: 1,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan / Catatan (opsional)',
                        hintText: 'Contoh: Titip di pos satpam, meja 3, req pedas...',
                        prefixIcon: Icon(Icons.description_outlined, size: 20),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        _pos.notesController.text = v.trim();
                      },
                    ),
                    const Divider(height: 24),
                    _row('Subtotal', money(pos.subtotal - pos.taxAmount + pos.discountAmount)),
                    if (pos.discountAmount > 0 || _discountController.text.isNotEmpty)
                      _row('Diskon', '-${money(Validators.parseAmount(_discountController.text))}'),
                    if (pos.taxPercent > 0)
                      _row('Pajak (${number(pos.taxPercent)}%)', money(pos.taxAmount)),
                    if (_shippingController.text.isNotEmpty)
                      _row('Ongkir', money(Validators.parseAmount(_shippingController.text))),
                    _row('Total', money(grandTotal), bold: true),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 12.5, color: Color(0xFFB91C1C))),
                        ),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary),
                          onPressed: _saving ? null : _submit,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2, color: Colors.white))
                              : Text(
                                  isPreOrder
                                      ? 'Buat Pre-Order • ${money(grandTotal)}'
                                      : 'Selesaikan Penjualan • ${money(grandTotal)}',
                                  style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey[600],
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: bold ? AppColors.primaryDark : const Color(0xFF374151))),
        ],
      ),
    );
  }
}

class _CustomerPickerDialog extends ConsumerStatefulWidget {
  const _CustomerPickerDialog();

  @override
  ConsumerState<_CustomerPickerDialog> createState() =>
      _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends ConsumerState<_CustomerPickerDialog> {
  List<Customer> _results = [];
  bool _loading = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String term) async {
    final wsId = ref.read(gateProvider).activeWorkspaceId!;
    setState(() => _loading = true);
    try {
      final results = term.trim().isEmpty
          ? await ref.read(customerRepositoryProvider).topCustomers(wsId, limit: 20)
          : await ref.read(customerRepositoryProvider).searchByName(wsId, term, limit: 20);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search(''));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Pilih Pelanggan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Cari nama pelanggan...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
                onSubmitted: _search,
                onChanged: (v) {
                  if (v.length >= 3) _search(v);
                },
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Tidak ada pelanggan. Gunakan tombol tambah (+) untuk membuat pelanggan baru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final c = _results[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 17,
                          backgroundColor: colorFromString(c.name)
                              .withValues(alpha: 0.15),
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colorFromString(c.name)),
                          ),
                        ),
                        title: Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5)),
                        subtitle: Text(
                          c.whatsapp.isEmpty
                              ? '${c.totalTransactions} transaksi'
                              : '${c.whatsapp} • ${c.totalTransactions} transaksi',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                        ),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
