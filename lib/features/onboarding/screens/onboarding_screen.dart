import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/providers.dart';
import '../../../../core/constants/catalogs.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/debug_utils.dart';
import '../../../../models/enums.dart';
import '../../../../models/workspace_model.dart';
import '../../../../services/demo_data_service.dart';
import '../../../../services/image_service.dart';
import '../../../../services/logger.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _addressController = TextEditingController();

  String? _businessType;
  String _businessScale = 'Mikro';
  String _timezone = 'Asia/Jakarta';
  String _currency = 'IDR';
  final Set<BusinessModel> _models = {BusinessModel.physicalProduct};
  final Set<String> _paymentTypes = {'CASH'};
  String? _logoDataUri;
  bool _creating = false;
  bool _seedDemo = false;
  int _step = 0;
  String? _error;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && (_nameController.text.trim().isEmpty)) {
      setState(() => _error = 'Nama usaha wajib diisi sebelum melanjutkan.');
      return;
    }
    if (_step == 1 && _models.isEmpty) {
      setState(() => _error = 'Pilih minimal satu model bisnis.');
      return;
    }
    setState(() {
      _error = null;
      _step++;
    });
    _pageController.nextPage(
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  Future<void> _pickLogo() async {
    try {
      final dataUri = await ImageService.instance.pickAndCompress(
        maxDimension: 256,
        quality: 80,
        maxBytes: 120000,
      );
      if (dataUri != null) setState(() => _logoDataUri = dataUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Gagal memuat gambar. Coba gambar lain.')),
        );
      }
    }
  }

  Future<void> _createWorkspace() async {
    if (_nameController.text.trim().isEmpty) {
      _goToStep(0);
      setState(() => _error = 'Nama usaha wajib diisi.');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) {
        throw const AppException('Sesi berakhir. Silakan login kembali.');
      }

      final models = _models.toList();

      final workspace = Workspace(
        id: '',
        ownerId: user.uid,
        name: _nameController.text.trim(),
        businessType: _businessType ?? '',
        businessCategory: _businessScale,
        description: _descController.text.trim(),
        businessModels: models,
        whatsappNumber: _whatsappController.text.trim(),
        address: _addressController.text.trim(),
        logoUrl: _logoDataUri,
        currency: _currency,
        timezone: _timezone,
        settings: WorkspaceSettings(
          allowOverselling: false,
          requireCustomerForSale: false,
          taxPercent: 0,
          preOrderEnabled: models.contains(BusinessModel.preOrder),
        ),
      );

      final result =
          await ref.read(workspaceRepositoryProvider).createWorkspace(
                workspace: workspace,
                ownerUid: user.uid,
                ownerName:
                    (user.displayName ?? _nameController.text.trim()).trim(),
                ownerEmail: (user.email ?? '').toLowerCase(),
              );

      if (!mounted) return;

      if (_seedDemo && kDebugModeSafe) {
        await DemoDataService().seed(
          wsId: result.workspaceId,
          workspaceName: workspace.name,
          ownerId: user.uid,
          template: _demoTemplateFor(models),
          onProgress: (status) => Logger.d(status),
        );
      }

      if (mounted) context.go('/home');
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      Logger.e('workspace creation failed', e);
      if (mounted) setState(() => _error = mapToAppException(e).message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _goToStep(int index) {
    setState(() => _step = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Setup Usaha (${_step + 1}/3)'),
          backgroundColor: Colors.white,
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: (_step + 1) / 3,
              backgroundColor: Colors.grey[200],
              color: AppColors.primary,
              minHeight: 3,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _businessInfoStep(),
                  _businessModelStep(),
                  _paymentAndReviewStep(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, Platform.isIOS ? 4 : 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12.5, color: Color(0xFFB91C1C))),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed:
                        _creating ? null : (_step == 2 ? _createWorkspace : _next),
                    child: _creating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white))
                        : Text(_step == 2
                            ? 'Buat Workspace & Mulai'
                            : 'Lanjut'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _businessInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Informasi Usaha',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          Text('Ceritakan sedikit tentang usaha Anda.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 18),
          Center(
            child: GestureDetector(
              onTap: _pickLogo,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: _logoDataUri != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Image.network(_logoDataUri!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.storefront_rounded)),
                      )
                    : const Icon(Icons.add_a_photo_outlined,
                        size: 26, color: Color(0xFF9CA3AF)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Logo usaha (opsional)',
                style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama Usaha *',
              hintText: 'Contoh: Toko Berkah Jaya',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _businessType,
            decoration: const InputDecoration(labelText: 'Jenis Usaha'),
            hint: const Text('Pilih jenis usaha'),
            items: BusinessCatalogs.businessTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _businessType = v),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _businessScale,
                  decoration: const InputDecoration(labelText: 'Skala'),
                  items: BusinessCatalogs.businessScales
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _businessScale = v ?? 'Mikro'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _timezone,
                  decoration: const InputDecoration(labelText: 'Zona Waktu'),
                  items: BusinessCatalogs.timezones
                      .map((t) =>
                          DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _timezone = v ?? 'Asia/Jakarta'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Nomor WhatsApp',
              hintText: '081234567890',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Alamat Usaha',
              hintText: 'Jl. Merdeka No. 123, Bandung',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Deskripsi Usaha',
              hintText: 'Usaha kuliner rumahan dengan cita rasa khas...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _businessModelStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Model Bisnis',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih satu atau lebih model yang sesuai dengan usaha Anda.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 18),
          ...BusinessModel.values.map((m) {
            final selected = _models.contains(m);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    if (selected) {
                      _models.remove(m);
                      if (_models.isEmpty) _models.add(m);
                    } else {
                      _models.add(m);
                    }
                    _error = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.06)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFFE5E7EB),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(m.icon,
                          size: 24,
                          color:
                              selected ? AppColors.primary : Colors.grey[500]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(m.label,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppColors.primaryDark
                                  : const Color(0xFF374151),
                            )),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color:
                            selected ? AppColors.primary : Colors.grey[400],
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _paymentAndReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Metode Pembayaran',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          Text(
              'Pilih metode pembayaran yang Anda terima. Bisa diubah kapan saja di Pengaturan.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ('Tunai', 'CASH'),
              ('Transfer Bank', 'BANK_TRANSFER'),
              ('QRIS', 'QRIS'),
              ('E-Wallet', 'EWALLET'),
              ('Kartu Debit/Kredit', 'CARD'),
            ].map((pm) {
              final selected = _paymentTypes.contains(pm.$2);
              return FilterChip(
                label: Text(pm.$1),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _paymentTypes.add(pm.$2);
                    } else {
                      if (pm.$2 == 'CASH') return;
                      _paymentTypes.remove(pm.$2);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ringkasan',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _summaryRow('Nama Usaha', _nameController.text),
                  _summaryRow('Jenis Usaha', _businessType ?? '-'),
                  _summaryRow('Skala', _businessScale),
                  _summaryRow('Zona Waktu', _timezone),
                  _summaryRow('Mata Uang', _currency),
                  _summaryRow(
                      'Model Bisnis', _models.map((m) => m.label).join(', ')),
                  _summaryRow('Metode Bayar', '${_paymentTypes.length} metode'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Mata Uang'),
            items: const [
              DropdownMenuItem(value: 'IDR', child: Text('Rupiah (IDR)')),
            ],
            onChanged: (v) => setState(() => _currency = v ?? 'IDR'),
          ),
          if (kDebugModeSafe) ...[
            const SizedBox(height: 14),
            CheckboxListTile(
              value: _seedDemo,
              onChanged: (v) => setState(() => _seedDemo = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Isi dengan data contoh (development)',
                  style: TextStyle(fontSize: 13.5)),
              subtitle: Text('Produk, pelanggan & transaksi 60 hari terakhir',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

DemoTemplate _demoTemplateFor(List<BusinessModel> models) {
  if (models.contains(BusinessModel.digitalProduct) &&
      models.contains(BusinessModel.service)) {
    return DemoTemplate.hybrid;
  }
  if (models.contains(BusinessModel.digitalProduct)) {
    return DemoTemplate.digitalProducts;
  }
  if (models.contains(BusinessModel.service) ||
      models.contains(BusinessModel.layanan)) {
    return DemoTemplate.serviceBusiness;
  }
  return DemoTemplate.physicalStore;
}
