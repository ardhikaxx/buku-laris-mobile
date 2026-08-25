import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../models/enums.dart';
import '../../../models/product_model.dart';
import '../../../services/logger.dart';
import 'pos_cart_sheet.dart';

class PosScreen extends ConsumerStatefulWidget {
  final bool initialPreOrder;

  const PosScreen({super.key, this.initialPreOrder = false});

  @override
  ConsumerState<PosScreen> createState() => PosScreenState();
}

class PosScreenState extends ConsumerState<PosScreen> {
  OrderType orderType = OrderType.readyStock;
  String _searchTerm = '';
  List<Product> _products = [];
  bool _loadingProducts = true;
  String? _loadError;
  final Map<String, int> qtyInCart = {};
  final Map<String, Product> cartProducts = {};
  int discountAmount = 0;
  int shippingCost = 0;
  int paidOverride = -1;
  String? customerId;
  String customerName = '';
  String customerWhatsapp = '';
  DateTime? estimatedDate;
  final notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    orderType =
        widget.initialPreOrder ? OrderType.preOrder : OrderType.readyStock;
    WidgetsBinding.instance.addPostFrameCallback((_) => loadProducts(''));
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> loadProducts(String term) async {
    final wsId = ref.read(gateProvider).activeWorkspaceId;
    if (wsId == null) return;
    setState(() {
      _loadingProducts = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(productRepositoryProvider);
      List<Product> results;
      if (term.isEmpty) {
        results = await repo.listAll(wsId, limit: 60);
      } else {
        results = [
          ...await repo.searchByName(wsId, term, limit: 15),
          ...await repo.searchByBarcodeOrSku(wsId, term),
        ];
      }
      final seen = <String>{};
      results.retainWhere((p) => p.availableForSale && seen.add(p.id));
      if (!mounted) return;
      setState(() {
        _products = results;
        _loadingProducts = false;
      });
    } catch (e) {
      Logger.e('pos load products failed', e);
      if (!mounted) return;
      setState(() {
        _loadError = mapToAppException(e).message;
        _loadingProducts = false;
      });
    }
  }

  void setOrderType(OrderType type) {
    setState(() {
      orderType = type;
      if (type == OrderType.preOrder) paidOverride = 0;
    });
  }

  void addToCart(Product product) {
    final currentQty = qtyInCart[product.id] ?? 0;
    if (_blocksOversell(product, currentQty + 1)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Stok "${product.name}" tersisa ${product.stock}. Overselling dinonaktifkan.'),
        backgroundColor: AppColors.expense,
      ));
      return;
    }
    setState(() {
      qtyInCart[product.id] = currentQty + 1;
      cartProducts[product.id] = product;
    });
  }

  void setQty(Product product, int qty) {
    if (qty <= 0) {
      setState(() {
        qtyInCart.remove(product.id);
        cartProducts.remove(product.id);
      });
      return;
    }
    if (_blocksOversell(product, qty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Melebihi stok "${product.name}" (${product.stock} tersisa).'),
        backgroundColor: AppColors.expense,
      ));
      return;
    }
    setState(() => qtyInCart[product.id] = qty);
  }

  bool _blocksOversell(Product product, int requestedQty) {
    if (orderType == OrderType.preOrder) return false;
    if (!product.type.tracksStock || product.unlimitedStock) return false;
    final allowOversell = ref
            .read(activeWorkspaceProvider)
            .workspace
            ?.settings
            .allowOverselling ??
        false;
    return !allowOversell && requestedQty > product.stock;
  }

  int get subtotal =>
      cartProducts.values.fold(0, (sum, p) => sum + p.sellingPrice * (qtyInCart[p.id] ?? 0));

  double get taxPercent =>
      ref.read(activeWorkspaceProvider).workspace?.settings.taxPercent ?? 0;

  int get taxAmount => ((subtotal - discountAmount) * taxPercent / 100).round();

  int get grandTotal => subtotal - discountAmount + taxAmount + shippingCost;

  int get itemCount => qtyInCart.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final supportsPreOrder =
        ref.watch(activeWorkspaceProvider).workspace?.supportsPreOrder ?? false;

    return PopScope(
      canPop: itemCount == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || itemCount == 0) return;
        final leave = await confirmAction(
          context,
          title: 'Buang keranjang?',
          message:
              'Ada item di keranjang yang belum diselesaikan. Yakin ingin keluar?',
          confirmLabel: 'Keluar',
          destructive: true,
        );
        if (leave && context.mounted) context.go('/sales');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catat Penjualan'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SegmentedButton<OrderType>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 11.5),
                ),
                segments: [
                  const ButtonSegment(
                      value: OrderType.readyStock, label: Text('Stok Siap')),
                  if (supportsPreOrder)
                    const ButtonSegment(
                        value: OrderType.preOrder, label: Text('Pre-Order')),
                ],
                selected: {orderType},
                onSelectionChanged: (selection) =>
                    setOrderType(selection.first),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: TextField(
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari produk, SKU atau barcode...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  suffixIcon: _searchTerm.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            setState(() => _searchTerm = '');
                            loadProducts('');
                          },
                        ),
                ),
                onChanged: (v) => _searchTerm = v,
                onSubmitted: (v) => loadProducts(v.trim()),
              ),
            ),
            Expanded(child: _buildProductList()),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$itemCount item di keranjang',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey[600])),
                      Text(money(grandTotal),
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827))),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed:
                      itemCount == 0 ? null : () => openCartSheet(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    side: BorderSide(color: AppColors.primary),
                  ),
                  child: const Text('Lanjutkan',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (_loadingProducts) return const ListSkeleton(itemCount: 5);
    if (_loadError != null) {
      return ErrorStateView(
          error: _loadError!, onRetry: () => loadProducts(_searchTerm));
    }
    if (_products.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Produk tidak ditemukan',
        message: _searchTerm.isEmpty
            ? 'Belum ada produk aktif. Tambahkan produk terlebih dahulu di menu Produk.'
            : 'Tidak ada produk aktif yang cocok dengan pencarian Anda.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final product = _products[index];
        final inCart = qtyInCart[product.id] ?? 0;
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => addToCart(product),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      switch (product.type) {
                        ProductType.physicalProduct =>
                          Icons.inventory_2_outlined,
                        ProductType.digitalProduct => Icons.cloud_outlined,
                        ProductType.service => Icons.handyman_outlined,
                        ProductType.otherService => Icons.spa_outlined,
                      },
                      size: 19,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(money(product.sellingPrice),
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark)),
                            const Spacer(),
                            if (product.type.tracksStock &&
                                !product.unlimitedStock)
                              Text(
                                'stok ${product.stock}${product.isLowStock ? ' • menipis' : ''}',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: product.isLowStock
                                        ? AppColors.expense
                                        : Colors.grey[500]),
                              )
                            else if (product.type ==
                                ProductType.digitalProduct)
                              Text(
                                product.unlimitedStock
                                    ? 'unlimited'
                                    : 'lisensi ${product.licenseCount}',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.grey[500]),
                              )
                            else
                              Text('jasa',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey[500])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (inCart > 0)
                    QtyStepper(qty: inCart, onChanged: (q) => setQty(product, q))
                  else
                    Icon(Icons.add_circle_outline_rounded,
                        size: 22, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void openCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PosCartSheet(),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}
