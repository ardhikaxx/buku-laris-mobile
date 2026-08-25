import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../errors/app_exception.dart';
import '../utils/formatters.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  )),
            ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sublabel;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.info,
    this.sublabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(height: 10),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
              if (sublabel != null) ...[
                const SizedBox(height: 2),
                Text(sublabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(0xFFD1D5DB)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorStateView extends ConsumerWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorStateView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = error is AppException ? (error as AppException).message : mapToAppException(error).message;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF4B5563), height: 1.5)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  final int itemCount;

  const ListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const Card(
        child: ListTile(
          contentPadding: EdgeInsets.all(14),
          title: SkeletonBox(height: 13),
          trailing: SkeletonBox(width: 70, height: 13),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 8),
            child: SkeletonBox(width: 120, height: 10),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya, Lanjutkan',
  String cancelLabel = 'Batal',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? const Color(0xFFDC2626) : null,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> confirmTyped(
  BuildContext context, {
  required String title,
  required String message,
  required String expectedPhrase,
  String hint = 'Ketik untuk konfirmasi',
  String confirmLabel = 'Hapus Permanen',
}) async {
  final controller = TextEditingController();
  var valid = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              onChanged: (v) => setState(() => valid = v.trim().toLowerCase() == expectedPhrase.toLowerCase()),
              decoration: InputDecoration(
                hintText: '$hint "$expectedPhrase"',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: valid ? () => Navigator.pop(ctx, true) : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF111827))),
          ),
        ],
      ),
    );
  }
}

class PagedListView<T> extends StatefulWidget {
  final Query<Map<String, dynamic>> Function() buildQuery;
  final T Function(DocumentSnapshot<Map<String, dynamic>> doc) mapper;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? emptyState;
  final EdgeInsetsGeometry padding;
  final ScrollController? scrollController;
  final Widget? header;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Key? refreshKey;

  const PagedListView({
    super.key,
    required this.buildQuery,
    required this.mapper,
    required this.itemBuilder,
    this.emptyState,
    this.padding = const EdgeInsets.all(16),
    this.scrollController,
    this.header,
    this.shrinkWrap = false,
    this.physics,
    this.refreshKey,
  });

  @override
  State<PagedListView<T>> createState() => PagedListViewState<T>();
}

class PagedListViewState<T> extends State<PagedListView<T>> {
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  final List<T> items = [];
  bool _loading = true;
  bool done = false;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    reset();
  }

  @override
  void didUpdateWidget(covariant PagedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      reset();
    }
  }

  void reset() {
    setState(() {
      _lastDoc = null;
      items.clear();
      done = false;
      _error = null;
      _loading = true;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (done || _busy || !mounted) return;
    _busy = true;
    try {
      final base = widget.buildQuery();
      var q = base.limit(_lastDoc == null ? AppConstants.pageSize : AppConstants.pageSize);
      if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);
      final snap = await q.get();
      final newItems = snap.docs.map(widget.mapper).toList();
      if (!mounted) return;
      setState(() {
        items.addAll(newItems);
        _loading = false;
        if (snap.docs.length < AppConstants.pageSize) done = true;
        if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && items.isEmpty) {
      return ErrorStateView(error: _error!, onRetry: reset);
    }
    if (_loading && items.isEmpty) return const ListSkeleton();

    if (items.isEmpty && done) {
      return widget.emptyState ??
          const EmptyState(
            icon: Icons.inbox_rounded,
            title: 'Belum ada data',
            message: 'Data akan muncul di sini setelah ditambahkan.',
          );
    }

    final count = items.length + (!done ? 1 : 0) + (widget.header != null ? 1 : 0);
    final list = ListView.builder(
      controller: widget.scrollController,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) {
        if (widget.header != null && index == 0) return widget.header!;
        final dataIndex = index - (widget.header != null ? 1 : 0);
        if (dataIndex >= items.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
          );
        }
        return widget.itemBuilder(context, items[dataIndex], dataIndex);
      },
    );

    return RefreshIndicator(onRefresh: () async => reset(), child: list);
  }
}
