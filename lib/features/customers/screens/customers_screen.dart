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
import '../../../models/enums.dart';
import '../../../models/customer_model.dart';
import '../../shared/widgets/navigation.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final wsId = ref.watch(gateProvider).activeWorkspaceId;
    final canManage =
        ref.watch(activeWorkspaceProvider).can(Permission.customersManage);

    return Scaffold(
      appBar: FloatingCapsuleAppBar(
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.people_alt_rounded,
              color: AppColors.primary, size: 20),
        ),
        titleText: 'Data Pelanggan',
        subtitleText: 'Daftar kontak & riwayat belanja',
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.all(7),
                minimumSize: const Size(36, 36),
              ),
              tooltip: 'Tambah Pelanggan',
              onPressed: () => showCustomerForm(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: TextField(
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama pelanggan...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _search = ''),
                      ),
              ),
              onSubmitted: (v) => setState(() => _search = v.trim()),
            ),
          ),
          Expanded(
            child: wsId == null
                ? const SizedBox.shrink()
                : PagedListView<Customer>(
                    key: ValueKey('customers-$_search'),
                    buildQuery: () {
                      var q = ref
                          .read(customerRepositoryProvider)
                          .listQuery(wsId);
                      if (_search.isNotEmpty) {
                        q = q.where('name', isGreaterThanOrEqualTo: _search);
                        q = q.where('name',
                            isLessThanOrEqualTo: '$_search\uf8ff');
                      }
                      return q.orderBy('name');
                    },
                    mapper: Customer.fromDoc,
                    emptyState: EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'Belum ada pelanggan',
                      message:
                          'Data pelanggan membantu Anda mengenali pembeli setia dan riwayat belanjanya.',
                      action: canManage
                          ? ElevatedButton.icon(
                              onPressed: () =>
                                  showCustomerForm(context, ref),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Tambah Pelanggan'))
                          : null,
                    ),
                    itemBuilder: (context, customer, index) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () =>
                            context.push('/customers/${customer.id}'),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 5),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: colorFromString(customer.name)
                              .withValues(alpha: 0.14),
                          child: Text(
                            customer.name.isNotEmpty
                                ? customer.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: colorFromString(customer.name)),
                          ),
                        ),
                        title: Text(customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              if (customer.whatsapp.isNotEmpty) ...[
                                Icon(Icons.chat_bubble_outline_rounded,
                                    size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(customer.whatsapp,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Text('${customer.totalTransactions} transaksi',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey[500])),
                            ],
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(compactMoney(customer.totalSpent),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark)),
                            Text('total belanja',
                                style: TextStyle(
                                    fontSize: 10.5, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'customers-fab',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => showCustomerForm(context, ref),
              icon: const Icon(Icons.person_add_alt_rounded, size: 20),
              label: const Text('Pelanggan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            )
          : null,
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }
}

Future<void> showCustomerForm(BuildContext context, WidgetRef ref,
    {Customer? existing}) async {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final waController = TextEditingController(text: existing?.whatsapp ?? '');
  final emailController = TextEditingController(text: existing?.email ?? '');
  final addressController =
      TextEditingController(text: existing?.address ?? '');
  final notesController = TextEditingController(text: existing?.notes ?? '');
  final formKey = GlobalKey<FormState>();
  var saving = false;

  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? 'Pelanggan Baru' : 'Ubah Pelanggan',
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: nameController,
                  autofocus: existing == null,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Nama pelanggan *'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: waController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'WhatsApp'),
                  validator: Validators.whatsapp,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Alamat'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setSheet(() => saving = true);
                          try {
                            final wsId =
                                ref.read(gateProvider).activeWorkspaceId!;
                            final repo =
                                ref.read(customerRepositoryProvider);
                            final data = Customer(
                              id: existing?.id ?? '',
                              name: nameController.text,
                              whatsapp: waController.text,
                              email: emailController.text,
                              address: addressController.text,
                              notes: notesController.text,
                            );
                            if (existing == null) {
                              await repo.create(wsId, data);
                            } else {
                              await repo.update(wsId, data);
                            }
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setSheet(() => saving = false);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text(mapToAppException(e).message),
                                backgroundColor: AppColors.expense,
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white))
                      : const Text('Simpan'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
