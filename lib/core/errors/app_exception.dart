import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, [this.cause]);

  @override
  String toString() => message;
}

String mapAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Format email tidak valid.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Email atau password salah. Periksa kembali dan coba lagi.';
    case 'user-disabled':
      return 'Akun ini telah dinonaktifkan. Hubungi dukungan.';
    case 'email-already-in-use':
      return 'Email sudah terdaftar. Coba masuk atau gunakan email lain.';
    case 'weak-password':
      return 'Password terlalu lemah. Gunakan minimal 8 karakter dengan huruf dan angka.';
    case 'too-many-requests':
      return 'Terlalu banyak percobaan. Tunggu beberapa saat lalu coba lagi.';
    case 'network-request-failed':
      return 'Koneksi internet bermasalah. Periksa jaringan Anda.';
    case 'requires-recent-login':
      return 'Untuk keamanan, silakan login ulang terlebih dahulu.';
    case 'operation-not-allowed':
      return 'Metode login ini belum diaktifkan di Firebase Console.';
    case 'account-exists-with-different-credential':
      return 'Email sudah dipakai dengan metode login lain.';
    case 'credential-already-in-use':
      return 'Akun Google ini sudah tertaut dengan akun lain.';
    default:
      return 'Terjadi kesalahan autentikasi (${e.code}). Silakan coba lagi.';
  }
}

String mapFirestoreError(FirebaseException e) {
  switch (e.code) {
    case 'permission-denied':
      return 'Anda tidak memiliki izin untuk aksi ini.';
    case 'not-found':
      return 'Data tidak ditemukan atau sudah dihapus.';
    case 'unavailable':
      return 'Server tidak dapat dihubungi. Periksa koneksi internet Anda.';
    case 'failed-precondition':
      return 'Operasi membutuhkan indeks atau kondisi yang belum terpenuhi.';
    case 'aborted':
      return 'Transaksi gagal karena konflik data. Coba lagi.';
    case 'deadline-exceeded':
      return 'Waktu tunggu habis. Periksa koneksi dan coba lagi.';
    case 'resource-exhausted':
      return 'Kuota server terlampaui. Coba lagi nanti.';
    case 'unauthenticated':
      return 'Sesi berakhir. Silakan login kembali.';
    case 'already-exists':
      return 'Data serupa sudah ada.';
    default:
      return 'Terjadi kesalahan database (${e.code}). Silakan coba lagi.';
  }
}

AppException mapToAppException(Object error) {
  if (error is AppException) return error;
  if (error is FirebaseAuthException) return AppException(mapAuthError(error), error);
  if (error is FirebaseException) return AppException(mapFirestoreError(error), error);
  if (error.toString().contains('network')) {
    return AppException('Koneksi internet bermasalah. Periksa jaringan Anda.', error);
  }
  return AppException('Terjadi kesalahan. Silakan coba lagi.', error);
}

Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    throw mapToAppException(e);
  }
}
