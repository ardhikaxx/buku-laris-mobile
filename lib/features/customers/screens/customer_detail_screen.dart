import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../models/enums.dart';
import '../../../models/customer_model.dart';
import '../../../models/sale_model.dart';
import '../screens/customers_screen.dart' show showCustomerForm;

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsId = ref.watch(gateProvider).activeWorkspaceId;
    final canManage =
        ref.watch(activeWorkspaceProvider).can(Permission.customersManage);
    if (wsId == null) return const SizedBox.shrink();

    return StreamBuilder<Customer?>(
      stream:
          ref.read(customerRepositoryProvider).watchById(wsId, customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final customer = snapshot.data;
        if (customer == null) {
          return const Scaffold(
            appBar: FloatingCapsuleAppBar(
              showBackButton: true,
              titleText: 'Detail Pelanggan',
            ),
            body: EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Pelanggan tidak ditemukan',
              message: 'Data mungkin telah dihapus.',
            ),
          );
        }

        return Scaffold(
          appBar: FloatingCapsuleAppBar(
            showBackButton: true,
            titleText: customer.name,
            subtitleText: customer.whatsapp.isNotEmpty
                ? customer.whatsapp
                : (customer.email.isNotEmpty ? customer.email : 'Pelanggan'),
            actions: [
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.all(7),
                    minimumSize: const Size(36, 36),
                  ),
                  tooltip: 'Ubah Data',
                  onPressed: () =>
                      showCustomerForm(context, ref, existing: customer),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chat_rounded, size: 19),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.all(7),
                  minimumSize: const Size(36, 36),
                ),
                tooltip: 'Chat WhatsApp',
                onPressed: customer.whatsapp.isEmpty
                    ? null
                    : () {
                        launchUrl(
                          Uri.parse(formatWhatsappLink(customer.whatsapp)),
                          mode: LaunchMode.externalApplication,
                        );
                      },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: colorFromString(customer.name)
                            .withValues(alpha: 0.14),
                        child: Text(
                          customer.name.isNotEmpty
                              ? customer.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: colorFromString(customer.name)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customer.name,
                                style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800)),
                            if (customer.whatsapp.isNotEmpty)
                              Text(customer.whatsapp,
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Total Belanja',
                      value: compactMoney(customer.totalSpent),
                      icon: Icons.shopping_bag_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'Jumlah Transaksi',
                      value: number(customer.totalTransactions),
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              if (customer.address.isNotEmpty ||
                  customer.email.isNotEmpty ||
                  customer.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (customer.address.isNotEmpty)
                          InfoRow(label: 'Alamat', value: customer.address),
                        if (customer.email.isNotEmpty)
                          InfoRow(label: 'Email', value: customer.email),
                        if (customer.notes.isNotEmpty)
                          InfoRow(label: 'Catatan', value: customer.notes),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const SectionHeader('Histori Transaksi'),
              PagedListView<Sale>(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildQuery: () => ref
                    .read(saleRepositoryProvider)
                    .listQuery(wsId, customerId: customerId),
                mapper: Sale.fromDoc,
                emptyState: const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'Belum ada transaksi',
                  message:
                      'Riwayat belanja pelanggan ini akan tampil di sini.',
                ),
                itemBuilder: (context, sale, index) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 4),
                    onTap: () => context.push('/sales/${sale.id}'),
                    title: Text(sale.transactionNumber,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text(dateTimeShort(sale.createdAt),
                        style:
                            TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                    trailing: Text(money(sale.grandTotal),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
