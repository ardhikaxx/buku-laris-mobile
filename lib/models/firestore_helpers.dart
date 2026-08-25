import 'package:cloud_firestore/cloud_firestore.dart';

String str(dynamic v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

String? strOrNull(dynamic v) => v?.toString();

int intOf(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double doubleOf(dynamic v, [double fallback = 0]) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

bool boolOf(dynamic v, [bool fallback = false]) =>
    v is bool ? v : fallback;

DateTime? dtFromTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

Timestamp? tsFromDt(DateTime? dt) => dt == null ? null : Timestamp.fromDate(dt);

List<String> strList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

Map<String, dynamic> mapOf(dynamic v) =>
    v is Map<String, dynamic> ? v : <String, dynamic>{};

T enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final v in values) {
    if (v.name == name || describeEnumName(v) == name) return v;
  }
  return fallback;
}

String describeEnumName<T extends Enum>(T e) => e.name;

Map<String, dynamic> mergeNested(
    Map<String, dynamic> base, Map<String, dynamic>? update) {
  final result = Map<String, dynamic>.from(base);
  if (update != null) {
    update.forEach((k, value) {
      if (value is Map<String, dynamic> && result[k] is Map<String, dynamic>) {
        result[k] = mergeNested(result[k] as Map<String, dynamic>, value);
      } else {
        result[k] = value;
      }
    });
  }
  return result;
}
