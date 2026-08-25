class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$');
  static final RegExp _phone = RegExp(r'^(\+62|62|0)8[0-9]{7,13}$');

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email wajib diisi';
    if (!_email.hasMatch(value)) return 'Format email tidak valid';
    return null;
  }

  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password wajib diisi';
    if (value.length < 8) return 'Password minimal 8 karakter';
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) return 'Password harus mengandung huruf';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Password harus mengandung angka';
    return null;
  }

  static String? required(String? v, {String field = 'Kolom'}) {
    if ((v ?? '').trim().isEmpty) return '$field wajib diisi';
    return null;
  }

  static String? businessName(String? v) =>
      required(v, field: 'Nama usaha');

  static String? positiveAmount(String? v, {String field = 'Nominal'}) {
    final raw = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) return '$field wajib diisi';
    final parsed = int.tryParse(raw) ?? 0;
    if (parsed <= 0) return '$field harus lebih dari 0';
    return null;
  }

  static String? nonNegativeAmount(String? v, {String field = 'Nominal'}) {
    final raw = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) return '$field wajib diisi';
    final parsed = int.tryParse(raw) ?? 0;
    if (parsed < 0) return '$field tidak boleh negatif';
    return null;
  }

  static String? quantity(String? v, {bool allowZero = false}) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Jumlah wajib diisi';
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) return 'Jumlah tidak valid';
    if (!allowZero && parsed == 0) return 'Jumlah harus lebih dari 0';
    return null;
  }

  static String? whatsapp(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!_phone.hasMatch(cleaned)) {
      return 'Gunakan format nomor Indonesia, contoh: 081234567890';
    }
    return null;
  }

  static String? price(String? v, {required bool requiredField}) {
    final raw = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) {
      return requiredField ? 'Harga wajib diisi' : null;
    }
    final parsed = int.tryParse(raw) ?? 0;
    if (parsed <= 0 && requiredField) return 'Harga harus lebih dari 0';
    return null;
  }

  static int parseAmount(String? v) {
    final raw = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }
}

class AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final parsed = int.parse(digits);
    final formatted = NumberFormat.decimalPattern('id_ID').format(parsed);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
