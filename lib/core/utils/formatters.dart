import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

final NumberFormat _idNumber = NumberFormat.decimalPattern('id_ID');

extension CurrencyInt on int {
  String get idr => 'Rp${_idNumber.format(this)}';
}

String money(num? value) => value == null ? '-' : 'Rp${_idNumber.format(value)}';

String compactMoney(num value) {
  String abbreviate(num dividedBy, String suffix, num remainder) {
    final scaled = value / dividedBy;
    var text = scaled.toStringAsFixed(scaled % 1 == 0 ? 0 : 1);
    text = text.replaceAll('.', ',');
    return 'Rp$text$suffix';
  }

  if (value >= 1000000000) return abbreviate(1000000000, 'M', 1000000000);
  if (value >= 1000000) return abbreviate(1000000, 'jt', 1000000);
  if (value >= 1000) return abbreviate(1000, 'rb', 1000);
  return money(value);
}

String number(num? value) => value == null ? '-' : _idNumber.format(value);

String dateFull(DateTime? dt) =>
    dt == null ? '-' : DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt);

String dateShort(DateTime? dt) => dt == null ? '-' : DateFormat('d MMM yyyy', 'id_ID').format(dt);

String dateTimeShort(DateTime? dt) =>
    dt == null ? '-' : DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);

String timeOnly(DateTime? dt) => dt == null ? '-' : DateFormat('HH:mm').format(dt);

String monthYear(DateTime dt) => DateFormat('MMMM yyyy', 'id_ID').format(dt);

String dayLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  return DateFormat('E, d MMM', 'id_ID').format(dt);
}

DateTime startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

DateTime startOfWeek(DateTime dt) {
  final day = startOfDay(dt);
  return day.subtract(Duration(days: day.weekday - 1));
}

DateTime startOfMonth(DateTime dt) => DateTime(dt.year, dt.month);

Future<void> initLocale() async {
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';
}

String formatWhatsappLink(String phone) {
  var p = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (p.startsWith('0')) p = '62${p.substring(1)}';
  return 'https://wa.me/$p';
}

Color colorFromString(String seed, [List<Color> palette = const [
  Color(0xFF6366F1),
  Color(0xFF0EA5E9),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
]]) {
  var hash = 0;
  for (var i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.codeUnitAt(i)) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}
