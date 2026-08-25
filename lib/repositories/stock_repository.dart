import '../core/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/enums.dart';
import '../models/stock_movement_model.dart';
import 'base_repository.dart';

class StockAdjustResult {
  final int stockBefore;
  final int stockAfter;
  final bool lowStockTriggered;

  const StockAdjustResult({
    required this.stockBefore,
    required this.stockAfter,
    required this.lowStockTriggered,
  });
}

class StockRepository extends BaseRepository {
  final void Function(String productId, String productName, int stock, int minStock)?
      onLowStock;

  StockRepository({this.onLowStock});

  Future<StockAdjustResult> adjustStock({
    required String wsId,
    required String productId,
    required StockReason reason,
    required int qtyChange,
    String note = '',
    String? relatedSaleId,
    required String actorId,
    bool allowNegative = false,
    int? absoluteTarget,
  }) async {
    final productRef = sub(wsId, Collections.products).doc(productId);

    return await fs.runTransaction<StockAdjustResult>((txn) async {
      final snap = await txn.get(productRef);
      if (!snap.exists || snap.data() == null) {
        throw RepoException('Produk tidak ditemukan.');
      }
      final data = snap.data()!;
      final before = (data['stock'] as num?)?.toInt() ?? 0;
      var after = before;
      if (absoluteTarget != null) {
        after = absoluteTarget;
        qtyChange = after - before;
      } else {
        after = before + qtyChange;
      }
      if (after < 0 && !allowNegative) {
        throw RepoException(
          'Stok tidak boleh negatif. Stok saat ini: $before. Periksa kembali jumlah perubahan.',
        );
      }

      txn.update(productRef, {
        'stock': after,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      txn.set(
        sub(wsId, Collections.stockMovements).doc(),
        StockMovement(
          productId: productId,
          productName: data['name'] ?? '',
          reason: reason,
          qtyChange: qtyChange,
          stockBefore: before,
          stockAfter: after,
          note: note,
          relatedSaleId: relatedSaleId,
          createdBy: actorId,
        ).toMap(),
      );

      final minStock = (data['minStock'] as num?)?.toInt() ?? 0;
      final lowStockNow = after <= minStock;
      final wasLowStock = before <= minStock;

      return StockAdjustResult(
        stockBefore: before,
        stockAfter: after,
        lowStockTriggered: lowStockNow && !wasLowStock && minStock > 0,
      );
    }).then((result) {
      if (result.lowStockTriggered && onLowStock != null) {
        onLowStock!(productId, '', result.stockAfter, 0);
      }
      return result;
    });
  }

  Query<Map<String, dynamic>> movementsQuery(String wsId, {String? productId}) {
    var q = sub(wsId, Collections.stockMovements)
        as Query<Map<String, dynamic>>;
    if (productId != null && productId.isNotEmpty) {
      q = q.where('productId', isEqualTo: productId);
    }
    return q.orderBy('createdAt', descending: true);
  }

  Future<List<StockMovement>> recentMovements(String wsId, {int limit = 20}) async {
    final snap = await sub(wsId, Collections.stockMovements)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(StockMovement.fromDoc).toList();
  }
}
