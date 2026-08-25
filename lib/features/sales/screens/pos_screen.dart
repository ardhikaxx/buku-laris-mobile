import 'dart:async';

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
  bool _indexBuilding = false;
  String? _loadError;
  String? _loadedForWsId;
  Timer? _retryTimer;
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
    _retryTimer?.cancel();
    notesController.dispose();
    super.dispose();
  }

  Future<void> loadProducts(String term) async {
    final wsId = ref.read(gateProvider).activeWorkspaceId;
    if (wsId == null) {
      if (mounted) {
        setState(() {
          _loadingProducts = false;
          _products = [];
        });
      }
      return;
    }
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
      _retryTimer?.cancel();
      setState(() {
        _products = results;
        _loadingProducts = false;
        _indexBuilding = false;
      });
    } catch (e) {
      Logger.e('pos load products failed', e);
      if (!mounted) return;
      final isIndexBuilding = e.toString().contains('index');
      setState(() {
        _loadError = mapToAppException(e).message;
        _loadingProducts = false;
        _indexBuilding = isIndexBuilding;
      });
      if (isIndexBuilding) {
        _retryTimer?.cancel();
        _retryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
          if (!mounted) {
            _retryTimer?.cancel();
            return;
          }
          loadProducts(_searchTerm.trim());
        });
      }
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

  Future<void> _handleBack(BuildContext context) async {
    if (itemCount > 0) {
      final leave = await confirmAction(
        context,
        title: 'Buang keranjang?',
        message:
            'Ada item di keranjang yang belum diselesaikan. Yakin ingin keluar?',
        confirmLabel: 'Keluar',
        destructive: true,
      );
      if (!leave || !mounted) return;
      setState(() {
        qtyInCart.clear();
        cartProducts.clear();
      });
    }
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/sales');
    }
  }

  @override
  Widget build(BuildContext context) {
    final supportsPreOrder =
        ref.watch(activeWorkspaceProvider).workspace?.supportsPreOrder ?? false;
    final gateWsId = ref.watch(gateProvider).activeWorkspaceId;
    if (gateWsId != _loadedForWsId && !_loadingProducts) {
      _loadedForWsId = gateWsId;
      WidgetsBinding.instance.addPostFrameCallback((_) => loadProducts(''));
    }

    return PopScope(
      canPop: itemCount == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Kembali',
            onPressed: () => _handleBack(context),
          ),
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
                      if (notesController.text.isNotEmpty)
                        Text(
                          'Keterangan: ${notesController.text}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      itemCount == 0 ? null : () => openCartSheet(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  iconAlignment: IconAlignment.end,
                  label: const Text('Lanjutkan',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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
    if (_indexBuilding) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 2.6)),
              const SizedBox(height: 16),
              Text('Menyiapkan indeks produk...',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800])),
              const SizedBox(height: 6),
              Text(
                'Firebase sedang membangun indeks pertama kali (1-3 menit). Halaman ini otomatis dimuat ulang setiap 15 detik.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
    if (_loadError != null) {
      return ErrorStateView(
          error: _loadError!, onRetry: () => loadProducts(_searchTerm));
    }
    if (_products.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: _searchTerm.isEmpty
            ? 'Belum ada produk yang bisa dijual'
            : 'Produk tidak ditemukan',
        message: _searchTerm.isEmpty
            ? 'Tambahkan produk atau layanan terlebih dahulu, lalu kembali ke sini untuk mencatat penjualan.'
            : 'Tidak ada produk aktif yang cocok dengan pencarian Anda.',
        action: ref.watch(activeWorkspaceProvider).can(Permission.productsManage) &&
                _searchTerm.isEmpty
            ? ElevatedButton.icon(
                onPressed: () => context.push('/products/new'),
                icon: const Icon(Icons.add_box_outlined, size: 18),
                label: const Text('Tambah Produk'))
            : null,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
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
      builder: (_) => PosCartSheet(pos: this),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}
