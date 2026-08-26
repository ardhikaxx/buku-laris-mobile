import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../models/payment_method_model.dart';
import '../../../services/logger.dart';

class CashTransferSheet extends ConsumerStatefulWidget {
  const CashTransferSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CashTransferSheet(),
    );
  }

  @override
  ConsumerState<CashTransferSheet> createState() => _CashTransferSheetState();
}

class _CashTransferSheetState extends ConsumerState<CashTransferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  List<PaymentMethodModel> _methods = [];
  PaymentMethodModel? _fromMethod;
  PaymentMethodModel? _toMethod;
  DateTime _occurredAt = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMethods());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMethods() async {
    final wsId = ref.read(gateProvider).activeWorkspaceId;
    final defaults = DefaultPaymentMethods.defaults();
    if (wsId == null) {
      _applyMethods(defaults);
      return;
    }
    try {
      final list = await ref
          .read(workspaceRepositoryProvider)
          .listPaymentMethods(wsId, onlyActive: true);
      if (!mounted) return;
      _applyMethods(list.isEmpty ? defaults : list);
    } catch (e) {
      Logger.e('load payment methods in transfer sheet failed', e);
      if (mounted) _applyMethods(defaults);
    }
  }

  void _applyMethods(List<PaymentMethodModel> methods) {
    setState(() {
      _methods = methods;
      if (methods.isNotEmpty) {
        _fromMethod = methods.firstWhere(
          (m) => m.type == 'CASH' || m.name.toLowerCase().contains('tunai'),
          orElse: () => methods.first,
        );
        _toMethod = methods.firstWhere(
          (m) =>
              (m.type == 'BANK_TRANSFER' ||
                  m.name.toLowerCase().contains('bri') ||
                  m.name.toLowerCase().contains('bank')) &&
              m.id != _fromMethod?.id,
          orElse: () => methods.length > 1 ? methods[1] : methods.first,
        );
      }
    });
  }

  void _swapMethods() {
    setState(() {
      final temp = _fromMethod;
      _fromMethod = _toMethod;
      _toMethod = temp;
    });
  }

  IconData _walletIcon(String type, String name) {
    final lower = name.toLowerCase();
    if (type == 'CASH' || lower.contains('tunai') || lower.contains('cash')) {
      return Icons.payments_rounded;
    }
    if (type == 'BANK_TRANSFER' ||
        lower.contains('bri') ||
        lower.contains('bank') ||
        lower.contains('transfer') ||
        lower.contains('bca')) {
      return Icons.account_balance_rounded;
    }
    if (type == 'QRIS' || lower.contains('qris')) {
      return Icons.qr_code_2_rounded;
    }
    return Icons.phone_android_rounded;
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('id', 'ID'),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _occurredAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromMethod == null || _toMethod == null) {
      setState(() => _error = 'Pilih akun asal dan akun tujuan transfer.');
      return;
    }

    if (_fromMethod!.name.toLowerCase().trim() ==
        _toMethod!.name.toLowerCase().trim()) {
      setState(() => _error = 'Akun asal dan akun tujuan tidak boleh sama.');
      return;
    }

    final amount = Validators.parseAmount(_amountController.text);
    if (amount <= 0) {
      setState(() => _error = 'Nominal transfer harus lebih dari Rp 0.');
      return;
    }

    final wsId = ref.read(gateProvider).activeWorkspaceId;
    final user = ref.read(authServiceProvider).currentUser;
    if (wsId == null || user == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(cashflowRepositoryProvider).transfer(
            wsId: wsId,
            fromMethodId: _fromMethod!.id,
            fromMethodName: _fromMethod!.name,
            toMethodId: _toMethod!.id,
            toMethodName: _toMethod!.name,
            amount: amount,
            occurredAt: _occurredAt,
            notes: _notesController.text.trim(),
            createdBy: user.uid,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pindah dana ${money(amount)} dari ${_fromMethod!.name} ke ${_toMethod!.name} berhasil',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = mapToAppException(e).message);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFE6F0FA),
                          child: Icon(Icons.swap_horiz_rounded,
                              color: AppColors.primary, size: 22),
                        ),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pindah Dana / Transfer Kas',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Transfer saldo antar akun & dompet usaha',
                              style: TextStyle(
                                  fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.expense.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: AppColors.expense),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.expense),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Akun Asal & Akun Tujuan
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Dari Akun
                      DropdownButtonFormField<PaymentMethodModel>(
                        isExpanded: true,
                        initialValue: _fromMethod,
                        decoration: const InputDecoration(
                          labelText: 'Dari Akun (Sumber Dana)',
                          prefixIcon: Icon(Icons.upload_rounded,
                              size: 18, color: AppColors.expense),
                          isDense: true,
                        ),
                        items: _methods
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Row(
                                    children: [
                                      Icon(_walletIcon(m.type, m.name),
                                          size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(m.name,
                                          style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _fromMethod = v),
                      ),
                      const SizedBox(height: 8),

                      // Swap Button
                      Center(
                        child: InkWell(
                          onTap: _swapMethods,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swap_vert_rounded,
                                    size: 16, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Tukar Posisi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Ke Akun
                      DropdownButtonFormField<PaymentMethodModel>(
                        isExpanded: true,
                        initialValue: _toMethod,
                        decoration: const InputDecoration(
                          labelText: 'Ke Akun (Tujuan Transfer)',
                          prefixIcon: Icon(Icons.download_rounded,
                              size: 18, color: AppColors.income),
                          isDense: true,
                        ),
                        items: _methods
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Row(
                                    children: [
                                      Icon(_walletIcon(m.type, m.name),
                                          size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(m.name,
                                          style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _toMethod = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Nominal Transfer
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [AmountInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Nominal Transfer (Rp) *',
                    prefixText: 'Rp ',
                    prefixIcon:
                        Icon(Icons.attach_money_rounded, size: 20),
                    isDense: true,
                  ),
                  validator: (v) =>
                      Validators.positiveAmount(v, field: 'Nominal transfer'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),

                // Quick Presets
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final nom in [50000, 100000, 200000, 500000, 1000000])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(
                              '+${compactMoney(nom)}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              final curr =
                                  Validators.parseAmount(_amountController.text);
                              _amountController.text = number(curr + nom);
                              setState(() {});
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Tanggal & Waktu
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Waktu Transfer',
                      prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                      isDense: true,
                    ),
                    child: Text(
                      dateTimeShort(_occurredAt),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Catatan
                TextFormField(
                  controller: _notesController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan / Catatan (opsional)',
                    hintText: 'Contoh: Setor omzet tunai ke rekening BRI...',
                    prefixIcon: Icon(Icons.notes_rounded, size: 18),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 20),

                // Tombol Simpan
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(_saving ? 'Menyimpan...' : 'Simpan Pindah Dana'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
