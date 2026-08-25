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
import '../../../models/product_model.dart';
import '../../../models/stock_movement_model.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  Future<void> _adjustStock(
      BuildContext context, WidgetRef ref, Product product) async {
    final reason = await showModalBottomSheet<StockReason>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Pilih alasan perubahan stok',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            for (final stockReason in [
              StockReason.restock,
              StockReason.customerReturn,
              StockReason.returnToSupplier,
              StockReason.damaged,
              StockReason.lost,
              StockReason.manualCorrection,
            ])
              ListTile(
                dense: true,
                leading: Icon(
                  stockReason.increasesStock
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: stockReason.increasesStock ? AppColors.income : AppColors.expense,
                ),
                title: Text(stockReason.label),
                onTap: () => Navigator.pop(ctx, stockReason),
              ),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;

    final controller = TextEditingController();
    final noteController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(reason.label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Stok saat ini: ${product.stock} ${product.unit}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [AmountInputFormatter()],
                  decoration:
                      const InputDecoration(labelText: 'Jumlah perubahan'),
                  onChanged: (_) => setSheetState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  decoration:
                      const InputDecoration(labelText: 'Catatan (opsional)'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor:
                          reason.increasesStock ? AppColors.income : AppColors.expense),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(controller.text.isEmpty
                      ? 'Lanjutkan'
                      : '${reason.increasesStock ? '+' : '-'}${number(Validators.parseAmount(controller.text))} ${product.unit}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final qty = Validators.parseAmount(controller.text);
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Jumlah perubahan harus lebih dari 0'),
        backgroundColor: AppColors.expense,
      ));
      return;
    }
    try {
      final wsId = ref.read(gateProvider).activeWorkspaceId!;
      final user = ref.read(authServiceProvider).currentUser!;
      await ref.read(stockRepositoryProvider).adjustStock(
            wsId: wsId,
            productId: product.id,
            reason: reason,
            qtyChange: reason.increasesStock ? qty : -qty,
            note: noteController.text.trim(),
            actorId: user.uid,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Stok diperbarui: ${reason.increasesStock ? '+' : '-'}$qty')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsId = ref.watch(gateProvider).activeWorkspaceId;
    if (wsId == null) return const SizedBox.shrink();

    final canManage =
        ref.watch(activeWorkspaceProvider).can(Permission.productsManage);
    final canAdjust =
        ref.watch(activeWorkspaceProvider).can(Permission.stockAdjust);

    return StreamBuilder<Product?>(
      stream: ref.read(productRepositoryProvider).watchById(wsId, productId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final product = snapshot.data;
        if (product == null) {
          return const Scaffold(
            appBar: FloatingCapsuleAppBar(
              showBackButton: true,
              titleText: 'Detail Produk',
            ),
            body: ErrorStateView(error: AppException('Produk tidak ditemukan.')),
          );
        }

        final margin = product.costPrice != null && product.costPrice! > 0
            ? ((product.sellingPrice - product.costPrice!) /
                    product.sellingPrice *
                    100)
                .round()
            : null;

        return Scaffold(
          appBar: FloatingCapsuleAppBar(
            showBackButton: true,
            titleText: product.name,
            subtitleText: product.type.label,
            actions: [
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.all(7),
                    minimumSize: const Size(36, 36),
                  ),
                  tooltip: 'Ubah Produk',
                  onPressed: () =>
                      context.push('/products/edit/${product.id}'),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatusChip(
                              product.type.label, AppColors.primary),
                          if (!product.isActive)
                            StatusChip('Nonaktif', Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(money(product.sellingPrice),
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark)),
                      ),
                      if (margin != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'margin $margin% • modal ${money(product.costPrice)}',
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.grey[600]),
                          ),
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'harga modal belum diisi — laba tidak dapat dihitung',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.amber[800]),
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
                      label: product.type.tracksStock && !product.unlimitedStock
                          ? 'Stok Saat Ini'
                          : 'Tersedia',
                      value: product.unlimitedStock
                          ? 'Tanpa batas'
                          : product.type.tracksStock && product.trackStock
                              ? number(product.stock)
                              : product.type == ProductType.digitalProduct
                                  ? (product.licenseCount == null
                                      ? 'Tanpa batas'
                                      : number(product.licenseCount))
                                  : 'Jasa',
                      icon: Icons.inventory_2_outlined,
                      color: product.isLowStock
                          ? AppColors.expense
                          : AppColors.info,
                      sublabel: product.minStock > 0 &&
                              product.type.tracksStock
                          ? 'min ${product.minStock}'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'Terjual',
                      value: number(product.soldCount),
                      icon: Icons.sell_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (canAdjust &&
                  product.trackStock &&
                  product.type.tracksStock &&
                  !product.unlimitedStock) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => _adjustStock(context, ref, product),
                    icon: const Icon(Icons.tune_rounded, size: 19),
                    label: const Text('Sesuaikan Stok'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SectionHeader('Histori Perubahan Stok'),
              PagedListView<StockMovement>(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildQuery: () => ref
                    .read(stockRepositoryProvider)
                    .movementsQuery(wsId, productId: productId),
                mapper: StockMovement.fromDoc,
                emptyState: const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'Belum ada riwayat stok',
                  message:
                      'Setiap perubahan stok akan tercatat di sini beserta alasannya.',
                ),
                itemBuilder: (context, movement, index) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 5),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          (movement.qtyChange >= 0 ? AppColors.income : AppColors.expense)
                              .withValues(alpha: 0.11),
                      child: Text(
                        '${movement.qtyChange > 0 ? '+' : ''}${movement.qtyChange}',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: movement.qtyChange >= 0
                                ? AppColors.income
                                : AppColors.expense),
                      ),
                    ),
                    title: Text(movement.reason.label,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${dateTimeShort(movement.createdAt)} • ${movement.stockBefore}→${movement.stockAfter}'
                      '${movement.note.isEmpty ? '' : ' • ${movement.note}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
