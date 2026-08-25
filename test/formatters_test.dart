import 'package:flutter_test/flutter_test.dart';
import 'package:buku_laris/core/utils/formatters.dart';
import 'package:buku_laris/core/utils/validators.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initLocale();
  });

  group('money formatter', () {
    test('formats Rupiah Indonesian style', () {
      expect(money(1500000), 'Rp1.500.000');
      expect(money(0), 'Rp0');
      expect(money(null), '-');
    });

    test('compact money abbreviates large values', () {
      expect(compactMoney(1500000), 'Rp1,5jt');
      expect(compactMoney(250000), 'Rp250rb');
      expect(compactMoney(1000000), 'Rp1jt');
    });
  });

  group('date formatters', () {
    test('dateShort uses Indonesian month', () {
      final dt = DateTime(2026, 8, 25);
      expect(dateShort(dt), '25 Agu 2026');
    });
  });

  group('validators', () {
    test('email validation', () {
      expect(Validators.email('budi@usaha.id'), isNull);
      expect(Validators.email('budi@'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('password policy requires letters and digits', () {
      expect(Validators.password('abc12345'), isNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('abcdefgh'), isNotNull);
      expect(Validators.password('ab12'), isNotNull);
    });

    test('amount parsing strips formatting', () {
      expect(Validators.parseAmount('1.500.000'), 1500000);
      expect(Validators.parseAmount('Rp 25.000'), 25000);
      expect(Validators.parseAmount(''), 0);
    });

    test('positive amount rejects zero and negative text', () {
      expect(Validators.positiveAmount('0'), isNotNull);
      expect(Validators.positiveAmount('5000'), isNull);
    });

    test('whatsapp accepts Indonesian formats or empty', () {
      expect(Validators.whatsapp('081234567890'), isNull);
      expect(Validators.whatsapp('+6281234567890'), isNull);
      expect(Validators.whatsapp('12345'), isNotNull);
      expect(Validators.whatsapp(''), isNull);
    });
  });
}
