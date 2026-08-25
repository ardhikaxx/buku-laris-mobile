import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../models/enums.dart';
import '../../../models/product_model.dart';
import '../../shared/widgets/navigation.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  ProductType? _typeFilter;
  String? _categoryFilter;
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    final wsId = ref.watch(gateProvider).activeWorkspaceId;
    final canManage = ref.watch(activeWorkspaceProvider).can(Permission.productsManage);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: TextField(
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama produk...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                suffixIcon: _searchTerm.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _searchTerm = ''),
                      ),
              ),
              onSubmitted: (v) => setState(() => _searchTerm = v.trim()),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: _typeFilter == null && _categoryFilter == null,
                    onSelected: (_) => setState(() {
                      _typeFilter = null;
                      _categoryFilter = null;
                    }),
                  ),
                  ...ProductType.values.map((t) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(t.label),
                          selected: _typeFilter == t,
                          onSelected: (_) =>
                              setState(() => _typeFilter = t),
                        ),
                      )),
                ],
              ),
            ),
          ),
          Expanded(
            child: wsId == null
                ? const SizedBox.shrink()
                : PagedListView<Product>(
                    key: ValueKey('$_searchTerm-$_typeFilter-$_categoryFilter'),
                    buildQuery: () {
                      var q = ref
                          .read(productRepositoryProvider)
                          .baseQuery(wsId, type: _typeFilter)
                          .orderBy('name');
                      if (_searchTerm.isNotEmpty) {
                        q = q.where('name',
                            isGreaterThanOrEqualTo: _searchTerm);
                        q = q.where('name',
                            isLessThanOrEqualTo: '$_searchTerm\uf8ff');
                      }
                      return q;
                    },
                    mapper: Product.fromDoc,
                    emptyState: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Belum ada produk',
                      message:
                          'Tambahkan produk pertama Anda untuk mulai berjualan.',
                      action: canManage
                          ? ElevatedButton.icon(
                              onPressed: () => context.push('/products/new'),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Tambah Produk'))
                          : null,
                    ),
                    itemBuilder: (context, product, index) =>
                        _ProductCard(product: product),
                  ),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              heroTag: 'products-fab',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/products/new'),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage =
        ref.watch(activeWorkspaceProvider).can(Permission.productsManage);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          onTap: () => context.push('/products/detail/${product.id}'),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              switch (product.type) {
                ProductType.physicalProduct => Icons.inventory_2_outlined,
                ProductType.digitalProduct => Icons.cloud_outlined,
                ProductType.service => Icons.handyman_outlined,
                ProductType.otherService => Icons.spa_outlined,
              },
              color: AppColors.primary,
              size: 21,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: product.isActive
                            ? const Color(0xFF111827)
                            : Colors.grey[500])),
              ),
              if (!product.isActive) StatusChip('Nonaktif', Colors.grey),
              if (product.isLowStock) ...[
                const SizedBox(width: 6),
                StatusChip('Stok menipis', AppColors.expense),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              switch (product.type) {
                ProductType.physicalProduct when product.unlimitedStock =>
                  '${money(product.sellingPrice)} • unlimited',
                ProductType.physicalProduct when !product.trackStock =>
                  '${money(product.sellingPrice)} • tanpa stok',
                ProductType.physicalProduct =>
                  '${money(product.sellingPrice)} • stok ${product.stock} ${product.unit}',
                ProductType.digitalProduct when product.unlimitedStock =>
                  '${money(product.sellingPrice)} • unlimited',
                ProductType.digitalProduct =>
                  '${money(product.sellingPrice)} • lisensi ${product.licenseCount ?? '-'}',
                _ => money(product.sellingPrice),
              },
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            ),
          ),
          trailing: canManage
              ? PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (value) async {
                    final repo = ref.read(productRepositoryProvider);
                    final wsId = ref.read(gateProvider).activeWorkspaceId!;
                    if (value == 'edit') {
                      context.push('/products/edit/${product.id}');
                    } else if (value == 'toggle') {
                      await repo.setActive(wsId, product.id, !product.isActive);
                    } else if (value == 'archive') {
                      final confirmed = await confirmAction(
                        context,
                        title: 'Arsipkan produk?',
                        message:
                            '"${product.name}" disembunyikan dari daftar namun riwayat transaksi tetap aman.',
                        destructive: true,
                      );
                      if (confirmed) await repo.archive(wsId, product.id);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('Ubah Produk')),
                    PopupMenuItem(
                        value: 'toggle',
                        child: Text(product.isActive
                            ? 'Nonaktifkan'
                            : 'Aktifkan')),
                    const PopupMenuItem(
                        value: 'archive', child: Text('Arsipkan')),
                  ],
                )
              : const Icon(Icons.chevron_right_rounded,
                  size: 22, color: Color(0xFFD1D5DB)),
        ),
      ),
    );
  }
}
