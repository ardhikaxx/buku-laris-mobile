import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/gate.dart';
import 'config/router.dart';
import 'core/theme/app_theme.dart';

class BukuLarisApp extends ConsumerWidget {
  const BukuLarisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(gateProvider.select((s) => s.status), (_, _) {});
    final router = ref.watch(routerProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: MaterialApp.router(
        title: 'Buku Laris',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('id', 'ID'),
        routerConfig: router,
        builder: (context, child) {
          return _GlobalErrorBoundary(child: child ?? const SizedBox.shrink());
        },
      ),
    );
  }
}

class _GlobalErrorBoundary extends StatelessWidget {
  final Widget child;

  const _GlobalErrorBoundary({required this.child});

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (details) {
      return Material(
        color: const Color(0xFFF6F7F9),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
                const SizedBox(height: 12),
                const Text(
                  'Terjadi kesalahan tak terduga',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Coba muat ulang halaman. Jika berlanjut, hubungi dukungan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    };
    return Directionality(
      textDirection: TextDirection.ltr,
      child: child,
    );
  }
}

bool get isMobile => Platform.isAndroid || Platform.isIOS;
