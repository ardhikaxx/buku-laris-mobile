import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buku_laris/config/gate.dart';
import 'package:buku_laris/config/providers.dart';
import 'package:buku_laris/features/sales/screens/pos_screen.dart';
import 'package:buku_laris/models/enums.dart';
import 'package:buku_laris/models/product_model.dart';
import 'package:buku_laris/models/workspace_member_model.dart';
import 'package:buku_laris/repositories/product_repository.dart';

class FakeProductRepository extends ProductRepository {
  final List<Product> Function() listAllImpl;

  FakeProductRepository({required this.listAllImpl});

  @override
  Future<List<Product>> listAll(String wsId, {int limit = 500}) async =>
      listAllImpl();
}

class FakeGateController extends GateController {
  @override
  GateState build() => const GateState(
        status: GateStatus.ready,
        activeWorkspaceId: 'ws-test',
      );
}

class FakeActiveWorkspaceController extends ActiveWorkspaceController {
  @override
  ActiveWorkspaceState build() => const ActiveWorkspaceState(
        member: WorkspaceMember(
          userId: 'u1',
          workspaceId: 'ws-test',
          displayName: 'Pemilik',
          email: 'pemilik@test.id',
          role: UserRole.OWNER,
        ),
      );
}

Widget _host({required List<Product> Function() products}) {
  return ProviderScope(
    overrides: [
      gateProvider.overrideWith(FakeGateController.new),
      activeWorkspaceProvider.overrideWith(FakeActiveWorkspaceController.new),
      productRepositoryProvider
          .overrideWith((ref) => FakeProductRepository(listAllImpl: products)),
    ],
    child: const MaterialApp(home: PosScreen()),
  );
}

void main() {
  testWidgets('POS dengan produk terisi tidak melempar exception layout',
      (tester) async {
    await tester.pumpWidget(_host(products: () => [
          Product(id: 'p1', name: 'Kopi Sachet', sellingPrice: 2000, stock: 10),
          Product(id: 'p2', name: 'Gula Pasir', sellingPrice: 15000, stock: 3),
        ]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Kopi Sachet'), findsOneWidget);
    expect(find.text('Gula Pasir'), findsOneWidget);
  });

  testWidgets('POS kosong menampilkan panduan dan tombol tambah produk',
      (tester) async {
    await tester.pumpWidget(_host(products: () => []));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Belum ada produk yang bisa dijual'), findsOneWidget);
    expect(find.text('Tambah Produk'), findsOneWidget);
  });

  testWidgets('POS gagal memuat karena index tetap merender tanpa crash',
      (tester) async {
    await tester.pumpWidget(_host(
      products: () => throw StateError(
          'FAILED_PRECONDITION: The query requires an index. It is building'),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
