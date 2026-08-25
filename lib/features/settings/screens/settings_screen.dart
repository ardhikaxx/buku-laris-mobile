import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/constants/catalogs.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debug_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common.dart';
import '../../../models/enums.dart';
import '../../../models/payment_method_model.dart';
import '../../../models/workspace_model.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/demo_data_service.dart';
import '../../../services/image_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeWorkspaceProvider);
    final ws = state.workspace;
    if (ws == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pengaturan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final gate = ref.watch(gateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Usaha')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _WorkspaceSection(workspace: ws),
          const SizedBox(height: 14),
          _BusinessModelSection(workspace: ws),
          const SizedBox(height: 14),
          const _PaymentMethodsSection(),
          const SizedBox(height: 14),
          _SaleConfigSection(workspace: ws),
          const SizedBox(height: 14),
          _PreOrderConfigSection(workspace: ws),
          const SizedBox(height: 14),
          _AccountSection(profile: gate.profile),
          const SizedBox(height: 14),
          const _DangerZoneSection(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _WorkspaceSection extends ConsumerStatefulWidget {
  final Workspace workspace;

  const _WorkspaceSection({required this.workspace});

  @override
  ConsumerState<_WorkspaceSection> createState() => _WorkspaceSectionState();
}

class _WorkspaceSectionState extends ConsumerState<_WorkspaceSection> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _whatsapp;
  late final TextEditingController _address;
  String? _businessType;
  String _timezone = 'Asia/Jakarta';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.workspace.name);
    _desc = TextEditingController(text: widget.workspace.description);
    _whatsapp = TextEditingController(text: widget.workspace.whatsappNumber);
    _address = TextEditingController(text: widget.workspace.address);
    _businessType =
        widget.workspace.businessType.isEmpty ? null : widget.workspace.businessType;
    _timezone = widget.workspace.timezone;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _whatsapp.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final dataUri = await ImageService.instance.pickAndCompress(
        maxDimension: 256,
        quality: 80,
        maxBytes: 120000,
      );
      if (!mounted) return;
      if (dataUri == null) return;
      await ref
          .read(workspaceRepositoryProvider)
          .updateBasics(widget.workspace.id, {'logoUrl': dataUri});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(mapToAppException(e).message),
            backgroundColor: AppColors.expense));
      }
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nama usaha tidak boleh kosong')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(workspaceRepositoryProvider).updateBasics(
            widget.workspace.id,
            {
              'name': _name.text.trim(),
              'businessType': _businessType ?? '',
              'description': _desc.text.trim(),
              'whatsappNumber': _whatsapp.text.trim(),
              'address': _address.text.trim(),
              'timezone': _timezone,
            },
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Informasi usaha tersimpan')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Stack(children: [
                      Center(
                        child: widget.workspace.logoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(widget.workspace.logoUrl!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.storefront_rounded)),
                              )
                            : const Icon(Icons.storefront_rounded,
                                size: 26, color: Colors.grey),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.edit_rounded,
                              size: 10, color: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Informasi Usaha',
                      style: TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama Usaha'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _businessType,
              hint: const Text('Jenis usaha'),
              items: BusinessCatalogs.businessTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _businessType = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor WhatsApp'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Alamat'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Deskripsi usaha'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _timezone,
              items: BusinessCatalogs.timezones
                  .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _timezone = v ?? 'Asia/Jakarta'),
              decoration: const InputDecoration(labelText: 'Zona Waktu'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white))
                  : const Text('Simpan Informasi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessModelSection extends ConsumerWidget {
  final Workspace workspace;

  const _BusinessModelSection({required this.workspace});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var selected = Set<BusinessModel>.from(workspace.businessModels);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Model Bisnis',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            Text(
              'Menentukan fitur yang ditampilkan (stok fisik, pre-order, dll).',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            StatefulBuilder(builder: (context, setInner) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final model in BusinessModel.values)
                    FilterChip(
                      avatar: Icon(model.icon, size: 16),
                      label: Text(model.label, style: const TextStyle(fontSize: 12.5)),
                      selected: selected.contains(model),
                      onSelected: (v) {
                        setInner(() {
                          if (v) {
                            selected.add(model);
                          } else {
                            selected.remove(model);
                            if (selected.isEmpty) selected.add(model);
                          }
                        });
                      },
                    ),
                ],
              );
            }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(workspaceRepositoryProvider).updateBasics(
                      workspace.id,
                      {'businessModels': selected.map((m) => m.name).toList()},
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Model bisnis diperbarui')));
                }
              },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Terapkan Model Bisnis'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodsSection extends ConsumerWidget {
  const _PaymentMethodsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsId = ref.watch(gateProvider).activeWorkspaceId;
    if (wsId == null) return const SizedBox.shrink();

    return Card(
      child: StreamBuilder<List<PaymentMethodModel>>(
        stream: ref
            .read(workspaceRepositoryProvider)
            .watchPaymentMethods(wsId),
        builder: (context, snapshot) {
          final methods = snapshot.data ?? [];
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Metode Pembayaran',
                          style: TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      tooltip: 'Tambah metode',
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          size: 22, color: AppColors.primary),
                      onPressed: () => _addMethodDialog(context, ref, wsId),
                    ),
                  ],
                ),
                if (methods.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Belum ada metode pembayaran.',
                        style:
                            TextStyle(fontSize: 12.5, color: Colors.grey[500])),
                  )
                else
                  for (final m in methods)
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: m.isActive,
                      title: Text(m.name, style: const TextStyle(fontSize: 13.5)),
                      subtitle: Text(m.type.replaceAll('_', ' '),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) => ref
                          .read(workspaceRepositoryProvider)
                          .setPaymentMethodActive(wsId, m.id, v),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addMethodDialog(
      BuildContext context, WidgetRef ref, String wsId) async {
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Metode Baru'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Nama', hintText: 'Contoh: BCA a/n Toko Jaya'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Tambah')),
        ],
      ),
    );
    if (confirmed != true || nameController.text.trim().isEmpty) return;

    final order = DateTime.now().millisecondsSinceEpoch % 100000;
    await ref.read(workspaceRepositoryProvider).savePaymentMethod(
          wsId,
          PaymentMethodModel(
            id: '',
            name: nameController.text.trim(),
            type: 'OTHER',
            sortOrder: order,
          ),
        );
  }
}

class _SaleConfigSection extends ConsumerWidget {
  final Workspace workspace;

  const _SaleConfigSection({required this.workspace});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Konfigurasi Penjualan',
                  style: TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: workspace.settings.allowOverselling,
              title: const Text('Izinkan overselling',
                  style: TextStyle(fontSize: 13.5)),
              subtitle: Text(
                  'Penjualan tetap bisa diproses walau stok kurang',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
              activeThumbColor: AppColors.primary,
              onChanged: (v) => ref
                  .read(workspaceRepositoryProvider)
                  .updateSettings(
                    workspace.id,
                    _copyWith(workspace, allowOverselling: v),
                  ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: workspace.settings.requireCustomerForSale,
              title: const Text('Wajib cantumkan pelanggan',
                  style: TextStyle(fontSize: 13.5)),
              subtitle: Text('Setiap transaksi harus memilih data pelanggan',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
              activeThumbColor: AppColors.primary,
              onChanged: (v) => ref
                  .read(workspaceRepositoryProvider)
                  .updateSettings(
                    workspace.id,
                    _copyWith(workspace, requireCustomer: v),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  static WorkspaceSettings _copyWith(Workspace ws,
      {bool? allowOverselling, bool? requireCustomer}) {
    return WorkspaceSettings(
      allowOverselling: allowOverselling ?? ws.settings.allowOverselling,
      requireCustomerForSale:
          requireCustomer ?? ws.settings.requireCustomerForSale,
      taxPercent: ws.settings.taxPercent,
      preOrderEnabled: ws.settings.preOrderEnabled,
      preOrderRequireEstDate: ws.settings.preOrderRequireEstDate,
      preOrderDeductOnConfirm: ws.settings.preOrderDeductOnConfirm,
      invoiceFooterNote: ws.settings.invoiceFooterNote,
    );
  }
}

class _PreOrderConfigSection extends ConsumerWidget {
  final Workspace workspace;

  const _PreOrderConfigSection({required this.workspace});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Konfigurasi Pre-Order',
                  style: TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: workspace.settings.preOrderEnabled,
              title: const Text('Aktifkan fitur pre-order',
                  style: TextStyle(fontSize: 13.5)),
              activeThumbColor: AppColors.primary,
              onChanged: (v) => ref
                  .read(workspaceRepositoryProvider)
                  .updateSettings(workspace.id, _copy(workspace, enabled: v)),
            ),
            if (workspace.settings.preOrderEnabled) ...[
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: workspace.settings.preOrderRequireEstDate,
                title: const Text('Wajib estimasi tanggal selesai',
                    style: TextStyle(fontSize: 13.5)),
                activeThumbColor: AppColors.primary,
                onChanged: (v) => ref
                    .read(workspaceRepositoryProvider)
                    .updateSettings(
                        workspace.id, _copy(workspace, requireEst: v)),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: workspace.settings.preOrderDeductOnConfirm,
                title: const Text('Kurangi stok saat dikonfirmasi',
                    style: TextStyle(fontSize: 13.5)),
                subtitle: Text(
                    'Nonaktif: stok berkurang saat pesanan diproses/selesai',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                activeThumbColor: AppColors.primary,
                onChanged: (v) => ref
                    .read(workspaceRepositoryProvider)
                    .updateSettings(
                        workspace.id, _copy(workspace, deductOnConfirm: v)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static WorkspaceSettings _copy(Workspace ws,
      {bool? enabled, bool? requireEst, bool? deductOnConfirm}) {
    return WorkspaceSettings(
      allowOverselling: ws.settings.allowOverselling,
      requireCustomerForSale: ws.settings.requireCustomerForSale,
      taxPercent: ws.settings.taxPercent,
      preOrderEnabled: enabled ?? ws.settings.preOrderEnabled,
      preOrderRequireEstDate: requireEst ?? ws.settings.preOrderRequireEstDate,
      preOrderDeductOnConfirm:
          deductOnConfirm ?? ws.settings.preOrderDeductOnConfirm,
      invoiceFooterNote: ws.settings.invoiceFooterNote,
    );
  }
}

class _AccountSection extends ConsumerWidget {
  final dynamic profile;

  const _AccountSection({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(gateProvider).user;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 21,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
          child: user?.photoURL == null
              ? Icon(Icons.person_outline_rounded, color: AppColors.primary)
              : null,
        ),
        title: Text(ref.watch(gateProvider).profile?.displayName ?? '-',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: Text(user?.email ?? '',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: TextButton(
          onPressed: () => _deleteAccount(context, ref),
          child: Text('Hapus Akun',
              style: TextStyle(fontSize: 12.5, color: AppColors.expense)),
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final firstConfirm = await confirmAction(
      context,
      title: 'Hapus akun secara permanen?',
      message:
          'Profil akun akan dihapus dari aplikasi dan Anda akan keluar. Workspace yang Anda miliki tidak ikut terhapus — hapus workspace terlebih dahulu jika diinginkan.',
      confirmLabel: 'Lanjutkan',
      destructive: true,
    );
    if (!firstConfirm) return;

    final typedOk = await confirmTyped(
      context,
      title: 'Konfirmasi akhir',
      message:
          'Tindakan ini tidak dapat dibatalkan. Ketik HAPUS untuk melanjutkan.',
      expectedPhrase: 'HAPUS',
    );
    if (!typedOk) return;

    try {
      final auth = ref.read(authServiceProvider);
      final isGoogleUser = auth.currentUser?.providerData
              .any((p) => p.providerId == 'google.com') ??
          false;
      String? password;
      if (!isGoogleUser && context.mounted) {
        password = await _promptPassword(context);
        if (password == null) return;
      }
      await auth.deleteAccount(password: password);
      if (context.mounted) context.go('/login');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    }
  }

  Future<String?> _promptPassword(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verifikasi Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Untuk keamanan, masukkan password akun Anda untuk mengonfirmasi penghapusan.',
                style: TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Password saat ini'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
  }
}

class _DangerZoneSection extends ConsumerWidget {
  const _DangerZoneSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(gateProvider).myMembership?.isOwner ?? false;
    if (!isOwner) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.expense.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.expense, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Zona Berbahaya',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.expense)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Menghapus workspace menghapus SEMUA data usaha secara permanen: produk, stok, transaksi, kas, pelanggan, karyawan, dan undangan.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.55, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.expense),
              onPressed: () => _deleteWorkspaceFlow(context, ref),
              icon: const Icon(Icons.delete_forever_rounded, size: 19),
              label: const Text('Hapus Workspace Permanen'),
            ),
            if (kDebugModeSafe) ...[
              const Divider(height: 24),
              OutlinedButton.icon(
                onPressed: () => _seedDemoData(context, ref),
                icon: const Icon(Icons.dataset_outlined, size: 19),
                label: const Text('Isi Data Contoh (Dev)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteWorkspaceFlow(
      BuildContext context, WidgetRef ref) async {
    final gate = ref.read(gateProvider);
    final wsId = gate.activeWorkspaceId!;
    final wsName = ref.read(activeWorkspaceProvider).workspace?.name ?? '';

    final firstConfirm = await confirmAction(
      context,
      title: 'Hapus "$wsName"?',
      message:
          'Seluruh data usaha akan hilang permanen dan tidak dapat dikembalikan.',
      confirmLabel: 'Lanjutkan',
      destructive: true,
    );
    if (!firstConfirm || !context.mounted) return;

    final typedOk = await confirmTyped(
      context,
      title: 'Verifikasi nama usaha',
      message:
          'Untuk memastikan, ketik nama usaha "$wsName" dengan benar untuk membuka tombol hapus.',
      expectedPhrase: wsName,
      confirmLabel: 'Hapus Permanen',
    );
    if (!typedOk || !context.mounted) return;

    final progressController = ShowProgressController(context);
    try {
      final deleted = await _runCascadeDelete(ref, wsId, gate.user!.uid, wsName,
          progressController.update);
      progressController.close();
      await ref.read(userRepositoryProvider).removeWorkspaceFromUser(
            ref.read(authServiceProvider).currentUser!.uid,
            wsId,
          );
      ref.read(gateProvider.notifier).refreshAfterInvitationResolved();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Workspace "$wsName" telah dihapus ($deleted dokumen dibersihkan).'),
        ));
      }
    } catch (e) {
      progressController.close();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    }
  }

  Future<int> _runCascadeDelete(WidgetRef ref, String wsId, String ownerUid,
      String wsName, void Function(String status) onProgress) async {
    final repo = ref.read(workspaceRepositoryProvider);
    var total = 0;
    await for (final count in repo.cascadeDelete(wsId: wsId, ownerUid: ownerUid)) {
      total = count;
      onProgress('Menghapus data... $count');
    }
    return total;
  }

  Future<void> _seedDemoData(BuildContext context, WidgetRef ref) async {
    final template = await showDialog<DemoTemplate>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pilih jenis usaha demo'),
        children: [
          for (final t in DemoTemplate.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.label),
              ),
            ),
        ],
      ),
    );
    if (template == null || !context.mounted) return;

    final gate = ref.read(gateProvider);
    final progressController = ShowProgressController(context);
    try {
      final service = DemoDataService();
      await service.clearDemoData(gate.activeWorkspaceId!);
      final created = await service.seed(
        wsId: gate.activeWorkspaceId!,
        workspaceName:
            ref.read(activeWorkspaceProvider).workspace?.name ?? 'Demo',
        ownerId: ref.read(authServiceProvider).currentUser!.uid,
        template: template,
        onProgress: (status) => progressController.update(status),
      );
      progressController.close();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$created transaksi demo berhasil dibuat'),
          backgroundColor: AppColors.income,
        ));
      }
    } catch (e) {
      progressController.close();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    }
  }
}

class ShowProgressController {
  final BuildContext context;
  OverlayEntry? _entry;

  ShowProgressController(this.context) {
    _entry = OverlayEntry(
      builder: (_) => PopScope(
        canPop: false,
        child: Container(
          color: Colors.black38,
          alignment: Alignment.center,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (context, value, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2.4),
                    const SizedBox(height: 14),
                    Text(value.isEmpty ? 'Memproses...' : value,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  final status = ValueNotifier<String>('');

  void update(String s) => status.value = s;

  void close() {
    _entry?.remove();
    _entry = null;
  }
}
