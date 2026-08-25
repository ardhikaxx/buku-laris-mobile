import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';

class LowStockScreen extends ConsumerStatefulWidget {
  const LowStockScreen({super.key});

  @override
  ConsumerState<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends ConsumerState<LowStockScreen> {
  List<_LowStockItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final wsId = ref.read(gateProvider).activeWorkspaceId;
    if (wsId == null) return;
    setState(() => _error = null);
    try {
      final products = await ref.read(productRepositoryProvider).listAll(wsId);
      final filtered = products
          .where((p) =>
              p.type.tracksStock &&
              p.trackStock &&
              !p.unlimitedStock &&
              p.stock <= p.minStock &&
              p.availableForSale)
          .toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));
      if (!mounted) return;
      setState(() => _items = filtered
          .map((p) => _LowStockItem(
                productId: p.id,
                name: p.name,
                stock: p.stock,
                minStock: p.minStock,
              ))
          .toList());
    } catch (e) {
      if (mounted) setState(() => _error = mapToAppException(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stok Menipis')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _items == null) {
      return ErrorStateView(error: _error!, onRetry: _load);
    }
    if (_items == null) return const ListSkeleton();
    if (_items!.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'Semua stok aman',
        message: 'Tidak ada produk yang berada di bawah batas minimum.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items![index];
        return Card(
          child: ListTile(
            onTap: () => context.push('/products/detail/${item.productId}'),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            title: Text(item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              item.outOfStock
                  ? 'Stok habis'
                  : 'Sisa ${item.stock} dari minimum ${item.minStock}',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: item.outOfStock ? AppColors.expense : AppColors.warning),
            ),
            trailing: item.outOfStock
                ? StatusChip('Habis', AppColors.expense)
                : StatusChip('${item.stock}', AppColors.warning),
          ),
        );
      },
    );
  }
}

class _LowStockItem {
  final String productId;
  final String name;
  final int stock;
  final int minStock;

  bool get outOfStock => stock <= 0;

  const _LowStockItem({
    required this.productId,
    required this.name,
    required this.stock,
    required this.minStock,
  });
}
