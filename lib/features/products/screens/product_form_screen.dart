import 'dart:io';

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
import '../../../models/product_category_model.dart';
import '../../../models/product_model.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _costController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _licenseController = TextEditingController();
  final _descController = TextEditingController();

  ProductType _type = ProductType.physicalProduct;
  String? _categoryId;
  String _unit = 'pcs';
  bool _trackStock = true;
  bool _unlimitedStock = false;
  bool _isActive = true;
  bool _hadInitialStock = false;
  List<ProductCategory> _categories = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _licenseController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final wsId = ref.read(gateProvider).activeWorkspaceId!;
    try {
      final cats = await ref.read(categoryRepositoryProvider).list(wsId);
      Product? existing;
      if (widget.productId != null) {
        existing =
            await ref.read(productRepositoryProvider).getById(wsId, widget.productId!);
      }
      if (!mounted) return;
      setState(() {
        _categories = cats;
        if (existing != null) {
          _nameController.text = existing.name;
          _skuController.text = existing.sku;
          _barcodeController.text = existing.barcode;
          if (existing.costPrice != null) {
            _costController.text = number(existing.costPrice);
          }
          _priceController.text = number(existing.sellingPrice);
          if (existing.type.tracksStock && !existing.unlimitedStock) {
            _stockController.text = number(existing.stock);
          }
          if (existing.licenseCount != null && existing.type == ProductType.digitalProduct) {
            _licenseController.text = number(existing.licenseCount);
          }
          _minStockController.text = number(existing.minStock);
          _descController.text = existing.description;
          _type = existing.type;
          _categoryId = existing.categoryId.isEmpty ? null : existing.categoryId;
          _unit = existing.unit;
          _trackStock = existing.trackStock;
          _unlimitedStock = existing.unlimitedStock;
          _isActive = existing.isActive;
          _hadInitialStock = true;
        } else if (cats.isNotEmpty) {
          _categoryId = null;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = mapToAppException(e).message);
        _loading = false;
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final wsId = ref.read(gateProvider).activeWorkspaceId!;
      final repo = ref.read(productRepositoryProvider);

      final stockValue = Validators.parseAmount(_stockController.text);
      final licenseValue = _licenseController.text.isEmpty
          ? null
          : Validators.parseAmount(_licenseController.text);
      final costValue = _costController.text.isEmpty
          ? null
          : Validators.parseAmount(_costController.text);

      final product = Product(
        id: widget.productId ?? '',
        name: _nameController.text,
        sku: _skuController.text,
        barcode: _barcodeController.text,
        categoryId: _categoryId ?? '',
        type: _type,
        costPrice: costValue,
        sellingPrice: Validators.parseAmount(_priceController.text),
        unit: _unit,
        trackStock: _trackStock,
        unlimitedStock:
            _type == ProductType.digitalProduct ? _unlimitedStock : false,
        stock: stockValue,
        minStock: Validators.parseAmount(_minStockController.text),
        licenseCount:
            _type == ProductType.digitalProduct && !_unlimitedStock
                ? licenseValue
                : null,
        description: _descController.text,
        isActive: _isActive,
      );

      if (widget.productId == null) {
        final created = await repo.create(wsId, product.copyWith(stock: 0));
        if (_type.tracksStock && _trackStock && stockValue > 0) {
          final user = ref.read(authServiceProvider).currentUser!;
          await ref.read(stockRepositoryProvider).adjustStock(
                wsId: wsId,
                productId: created.id,
                reason: StockReason.initialStock,
                qtyChange: stockValue,
                absoluteTarget: stockValue,
                note: 'Stok awal',
                actorId: user.uid,
              );
        }
      } else {
        await repo.update(wsId, product, hadInitialStock: _hadInitialStock);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.productId == null
                ? 'Produk "${product.name}" berhasil ditambahkan'
                : 'Produk "${product.name}" berhasil diperbarui'),
            backgroundColor: AppColors.income,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = mapToAppException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: FloatingCapsuleAppBar(
          showBackButton: true,
          titleText: 'Memuat Produk...',
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isPhysical = _type == ProductType.physicalProduct;
    final isDigital = _type == ProductType.digitalProduct;

    return Scaffold(
      appBar: FloatingCapsuleAppBar(
        showBackButton: true,
        titleText: widget.productId == null ? 'Tambah Produk' : 'Ubah Produk',
        subtitleText: 'Kelola informasi produk & harga',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProductTypeSelector(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama Produk *'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Nama produk wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    hint: const Text('Tanpa kategori'),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                            value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
                IconButton(
                  tooltip: 'Kelola kategori',
                  onPressed: () => context.push('/categories'),
                  icon: const Icon(Icons.category_outlined, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [AmountInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Harga Modal',
                      prefixText: 'Rp ',
                      helperText: 'Untuk hitung estimasi laba',
                    ),
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [AmountInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Harga Jual *',
                      prefixText: 'Rp ',
                    ),
                    validator: (v) => Validators.price(v, requiredField: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(labelText: 'SKU'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Barcode'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _unit,
              decoration: const InputDecoration(
                  labelText: 'Satuan', hintText: 'pcs, kg, box, jasa...'),
              onChanged: (v) => _unit = v.trim().isEmpty ? 'pcs' : v.trim(),
            ),
            const SizedBox(height: 14),
            if (isPhysical) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pantau stok',
                    style: TextStyle(fontSize: 14)),
                subtitle: Text('Catat perubahan stok otomatis saat penjualan',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                value: _trackStock,
                onChanged: (v) => setState(() => _trackStock = v),
              ),
              if (_trackStock)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [AmountInputFormatter()],
                        enabled: widget.productId == null || !_hadInitialStock,
                        decoration: InputDecoration(
                          labelText: 'Stok ${widget.productId != null && _hadInitialStock ? "(ubah via menu Stok)" : ""}',
                        ),
                        validator: (v) => Validators.quantity(v, allowZero: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _minStockController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [AmountInputFormatter()],
                        decoration: const InputDecoration(
                            labelText: 'Stok minimum'),
                        validator: (v) =>
                            Validators.quantity(v, allowZero: true),
                      ),
                    ),
                  ],
                ),
            ],
            if (isDigital) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Stok tak terbatas',
                    style: TextStyle(fontSize: 14)),
                subtitle: Text('Produk selalu tersedia untuk dijual',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                value: _unlimitedStock,
                onChanged: (v) => setState(() => _unlimitedStock = v),
              ),
              if (!_unlimitedStock)
                TextFormField(
                  controller: _licenseController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [AmountInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Jumlah lisensi tersedia',
                    helperText: 'Berapa kali produk ini dapat dijual',
                  ),
                  validator: (v) => Validators.quantity(v, allowZero: true),
                ),
            ],
            if (!isPhysical && !isDigital) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 17, color: AppColors.income),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Jasa dan layanan tidak menggunakan stok barang.',
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.green[900], height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Deskripsi (opsional)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Produk aktif', style: TextStyle(fontSize: 14)),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.expense)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, Platform.isIOS ? 4 : 12),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white))
                : const Text('Simpan Produk'),
          ),
        ),
      ),
    );
  }

  Widget _buildProductTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Tipe Produk / Layanan',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final t in ProductType.values) ...[
                Expanded(
                  child: _buildTypeOption(
                    type: t,
                    isSelected: _type == t,
                    onTap: () => setState(() => _type = t),
                  ),
                ),
                if (t != ProductType.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required ProductType type,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final icon = switch (type) {
      ProductType.physicalProduct => Icons.inventory_2_rounded,
      ProductType.digitalProduct => Icons.cloud_download_rounded,
      ProductType.service => Icons.handyman_rounded,
      ProductType.otherService => Icons.miscellaneous_services_rounded,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : Colors.grey[600],
              ),
              const SizedBox(height: 5),
              Text(
                type.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color:
                      isSelected ? AppColors.primary : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

