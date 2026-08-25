import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FloatingCapsuleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final String? titleText;
  final String? subtitleText;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry margin;
  final Widget? bottom;
  final double height;
  final bool centerTitle;

  const FloatingCapsuleAppBar({
    super.key,
    this.title,
    this.titleText,
    this.subtitleText,
    this.leading,
    this.showBackButton = false,
    this.onBackPressed,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.margin = const EdgeInsets.fromLTRB(16, 6, 16, 6),
    this.bottom,
    this.height = 54.0,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        height +
            (bottom != null ? 52.0 : 0.0) +
            14.0,
      );

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final shouldShowBack = showBackButton || canPop;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: margin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                  ] else if (shouldShowBack) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF1E293B),
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(38, 38),
                      ),
                      onPressed: onBackPressed ??
                          () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              context.pop();
                            }
                          },
                      tooltip: 'Kembali',
                    ),
                  ] else ...[
                    const SizedBox(width: 10),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: title ??
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: centerTitle
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            if (titleText != null)
                              Text(
                                titleText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: foregroundColor ?? const Color(0xFF0F172A),
                                ),
                              ),
                            if (subtitleText != null && subtitleText!.isNotEmpty)
                              Text(
                                subtitleText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                  ),
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!,
                    ),
                    const SizedBox(width: 4),
                  ] else ...[
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
            if (bottom != null) ...[
              const SizedBox(height: 6),
              bottom!,
            ],
          ],
        ),
      ),
    );
  }
}
