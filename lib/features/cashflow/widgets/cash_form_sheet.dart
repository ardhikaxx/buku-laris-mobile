import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/gate.dart';
import '../../../../config/providers.dart';
import '../../../../core/constants/catalogs.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../models/cash_transaction_model.dart';
import '../../../../models/enums.dart';

class CashFormSheet extends ConsumerStatefulWidget {
  final bool isIncome;
  final CashTransaction? existing;

  const CashFormSheet({super.key, required this.isIncome, this.existing});

  static Future<bool?> show(BuildContext context,
      {required bool isIncome, CashTransaction? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CashFormSheet(isIncome: isIncome, existing: existing),
      ),
    );
  }

  @override
  ConsumerState<CashFormSheet> createState() => _CashFormSheetState();
}

class _CashFormSheetState extends ConsumerState<CashFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descController;
  late final TextEditingController _noteController;
  late String _category;
  late DateTime _date;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final categories = widget.isIncome
        ? CashCategories.income
        : CashCategories.expense;
    _category = existing?.category ?? categories.first;
    _amountController = TextEditingController(
      text: existing == null ? '' : number(existing.amount),
    );
    _descController = TextEditingController(text: existing?.description ?? '');
    _noteController = TextEditingController(text: existing?.notes ?? '');
    _date = existing?.occurredAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final gate = ref.read(gateProvider);
      final wsId = gate.activeWorkspaceId;
      if (wsId == null) throw const AppException('Workspace tidak ditemukan.');
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw const AppException('Sesi berakhir.');

      final amount = Validators.parseAmount(_amountController.text);
      final repo = ref.read(cashflowRepositoryProvider);

      if (widget.existing != null) {
        await repo.update(
          CashTransaction(
            id: widget.existing!.id,
            workspaceId: wsId,
            type: widget.existing!.type,
            category: _category,
            amount: amount,
            occurredAt: _date,
            paymentMethodId: widget.existing!.paymentMethodId,
            paymentMethodName: widget.existing!.paymentMethodName,
            sourceSaleId: widget.existing!.sourceSaleId,
            sourceType: widget.existing!.sourceType,
            description: _descController.text,
            notes: _noteController.text,
            createdBy: widget.existing!.createdBy,
          ),
          _date,
        );
      } else {
        await repo.add(
          CashTransaction(
            workspaceId: wsId,
            type: widget.isIncome
                ? CashTransactionType.income
                : CashTransactionType.expense,
            category: _category,
            amount: amount,
            occurredAt: _date,
            description: _descController.text,
            notes: _noteController.text,
            createdBy: user.uid,
          ),
          _date,
        );
        ref.read(auditRepositoryProvider).log(
              workspaceId: wsId,
              actorId: user.uid,
              actorName: gate.profile?.displayName ?? '',
              action: widget.isIncome ? 'cash.income_added' : 'cash.expense_added',
              entityType: 'cashTransaction',
              entityId: '',
              metadata: {'amount': amount, 'category': _category},
            );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = mapToAppException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        widget.isIncome ? CashCategories.income : CashCategories.expense;
    final allCategories = [
      ...categories,
      if (!categories.contains(_category) && _category.isNotEmpty) _category,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    widget.isIncome
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    color: widget.isIncome ? AppColors.income : AppColors.expense,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.existing != null
                        ? 'Ubah Catatan Kas'
                        : (widget.isIncome ? 'Catat Uang Masuk' : 'Catat Uang Keluar'),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[800]),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [AmountInputFormatter()],
                autofocus: widget.existing == null,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: widget.isIncome ? AppColors.income : AppColors.expense,
                ),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: widget.isIncome ? AppColors.income : AppColors.expense),
                  hintText: '0',
                  fillColor: const Color(0xFFF9FAFB),
                ),
                validator: (v) => Validators.positiveAmount(v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: Icon(Icons.sell_rounded, size: 18),
                ),
                items: allCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    locale: const Locale('id', 'ID'),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal',
                    suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                  ),
                  child: Text(dateShort(_date), style: const TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  hintText: 'Contoh: beli stok gula pasir',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white))
                      : const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
