import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../models/product_model.dart';

class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsId = ref.watch(gateProvider).activeWorkspaceId;
    if (wsId == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: const FloatingCapsuleAppBar(
        showBackButton: true,
        titleText: 'Stok Menipis',
        subtitleText: 'Produk mendekati batas minimum',
      ),
      body: StreamBuilder<List<Product>>(
        stream: ref.read(productRepositoryProvider).watchAll(wsId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
          }
          if (snapshot.hasError) {
            return ErrorStateView(
              error: snapshot.error!,
              onRetry: () {},
            );
          }
          final products = snapshot.data ?? [];
          final lowStockList = products
              .where((p) =>
                  p.type.tracksStock &&
                  p.trackStock &&
                  !p.unlimitedStock &&
                  p.stock <= p.minStock &&
                  p.availableForSale)
              .toList()
            ..sort((a, b) => a.stock.compareTo(b.stock));

          if (lowStockList.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Semua stok aman',
              message: 'Tidak ada produk yang berada di bawah batas minimum.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lowStockList.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = lowStockList[index];
              final outOfStock = item.stock <= 0;
              return Card(
                child: ListTile(
                  onTap: () => context.push('/products/detail/${item.id}'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: Text(item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    outOfStock
                        ? 'Stok habis'
                        : 'Sisa ${item.stock} dari minimum ${item.minStock}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: outOfStock
                            ? AppColors.expense
                            : AppColors.warning),
                  ),
                  trailing: outOfStock
                      ? const StatusChip('Habis', AppColors.expense)
                      : StatusChip('${item.stock}', AppColors.warning),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

