import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/errors/app_exception.dart';
import 'logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw const AppException('Pendaftaran gagal. Silakan coba lagi.');
      }
      await user.updateDisplayName(displayName.trim());
      await user.reload();
      return _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      Logger.e('register failed', e);
      throw AppException(mapAuthError(e), e);
    }
  }

  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user;
    } on FirebaseAuthException catch (e) {
      Logger.e('signIn failed', e);
      throw AppException(mapAuthError(e), e);
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      final userCred = await _auth.signInWithCredential(credential);
      return userCred.user;
    } on FirebaseAuthException catch (e) {
      Logger.e('google firebase auth failed', e);
      throw AppException(mapAuthError(e), e);
    } on PlatformException catch (e) {
      Logger.e('google sign in platform exception', e);
      if (e.code == 'sign_in_canceled' || e.code == 'sign_in_failed') {
        throw const AppException('Login dengan Google dibatalkan.');
      }
      throw AppException('Login dengan Google gagal: ${e.message ?? e.code}', e);
    } catch (e) {
      Logger.e('google sign in failed', e);
      throw const AppException(
          'Login dengan Google gagal. Periksa koneksi dan coba lagi.');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AppException(mapAuthError(e), e);
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        try {
          if (password != null && user.email != null) {
            final cred = EmailAuthProvider.credential(
                email: user.email!, password: password);
            await user.reauthenticateWithCredential(cred);
          } else {
            final account = await _googleSignIn.signIn();
            if (account == null) {
              throw const AppException(
                  'Verifikasi ulang dibatalkan. Akun tidak dihapus.');
            }
            final auth = await account.authentication;
            await user.reauthenticateWithCredential(GoogleAuthProvider.credential(
              idToken: auth.idToken,
              accessToken: auth.accessToken,
            ));
          }
          await _auth.currentUser?.delete();
        } on FirebaseAuthException catch (e2) {
          throw AppException(mapAuthError(e2), e2);
        } on AppException {
          rethrow;
        }
      } else {
        throw AppException(mapAuthError(e), e);
      }
    }
  }
}
