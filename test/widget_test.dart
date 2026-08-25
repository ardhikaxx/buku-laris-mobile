import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buku_laris/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders core elements', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Selamat datang kembali'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Masuk dengan Google'), findsOneWidget);
    expect(find.text('Lupa password?'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
