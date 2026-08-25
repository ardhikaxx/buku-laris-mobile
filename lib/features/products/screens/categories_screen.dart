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
              Text(existing == null ? 'Kategori Baru' : 'Ubah Kategori',
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                autofocus: existing == null,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Nama kategori *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                    labelText: 'Deskripsi (opsional)'),
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
      appBar: AppBar(title: const Text('Kategori Produk')),
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
              icon: Icons.category_outlined,
              title: 'Belum ada kategori',
              message:
                  'Kelompokkan produk Anda dengan kategori agar lebih mudah dikelola.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final cat = cats[index];
              return Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        colorFromString(cat.name).withValues(alpha: 0.13),
                    child: Icon(Icons.label_outline_rounded,
                        size: 18, color: colorFromString(cat.name)),
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
