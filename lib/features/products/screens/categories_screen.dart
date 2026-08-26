import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/gate.dart';
import '../../../config/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../models/product_category_model.dart';
import '../../../services/logger.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _showForm(BuildContext context, WidgetRef ref,
      {ProductCategory? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController =
        TextEditingController(text: existing?.description ?? '');
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sell_rounded,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(existing == null ? 'Kategori Baru' : 'Ubah Kategori',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                autofocus: existing == null,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama kategori *',
                  prefixIcon: Icon(Icons.sell_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                  prefixIcon: Icon(Icons.description_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () =>
                    Navigator.pop(ctx, nameController.text.trim().isNotEmpty),
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
    if (created != true || !context.mounted) return;

    try {
      final wsId = ref.read(gateProvider).activeWorkspaceId!;
      final repo = ref.read(categoryRepositoryProvider);
      if (existing == null) {
        await repo.create(
            wsId,
            ProductCategory(
                id: '',
                name: nameController.text,
                description: descController.text));
      } else {
        await repo.update(
          wsId,
          ProductCategory(
            id: existing.id,
            name: nameController.text,
            description: descController.text,
            parentId: existing.parentId,
            productType: existing.productType,
            archived: existing.archived,
          ),
        );
      }
    } catch (e) {
      Logger.e('category save failed', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mapToAppException(e).message),
          backgroundColor: AppColors.expense,
        ));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ProductCategory cat) async {
    final confirmed = await confirmAction(
      context,
      title: 'Hapus kategori "${cat.name}"?',
      message:
          'Jika kategori masih dipakai produk, kategori akan diarsipkan agar riwayat laporan tetap utuh.',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      final wsId = ref.read(gateProvider).activeWorkspaceId!;
      await ref.read(categoryRepositoryProvider).archiveIfUnused(wsId, cat.id);
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

    return Scaffold(
      appBar: FloatingCapsuleAppBar(
        showBackButton: true,
        leading: CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.sell_rounded,
              color: AppColors.primary, size: 20),
        ),
        titleText: 'Kategori Produk',
        subtitleText: 'Pengelompokan jenis barang toko',
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.all(7),
              minimumSize: const Size(36, 36),
            ),
            tooltip: 'Tambah Kategori',
            onPressed: () => _showForm(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'categories-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showForm(context, ref),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Kategori'),
      ),
      body: StreamBuilder<List<ProductCategory>>(
        stream: ref.read(categoryRepositoryProvider).watchAll(wsId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
          }
          if (snapshot.hasError) {
            return ErrorStateView(error: snapshot.error!, onRetry: () {});
          }
          final cats = snapshot.data ?? [];
          if (cats.isEmpty) {
            return const EmptyState(
              icon: Icons.sell_outlined,
              title: 'Belum ada kategori',
              message:
                  'Kelompokkan produk Anda dengan kategori agar lebih mudah dikelola.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cats.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final cat = cats[index];
              return Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorFromString(cat.name).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.sell_rounded,
                      size: 20,
                      color: colorFromString(cat.name),
                    ),
                  ),
                  title: Text(cat.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: cat.description.isEmpty
                      ? null
                      : Text(cat.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 19),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showForm(context, ref, existing: cat);
                      } else if (value == 'delete') {
                        _delete(context, ref, cat);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Ubah')),
                      PopupMenuItem(value: 'delete', child: Text('Hapus/Arsip')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
