import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/errors/app_exception.dart';
import 'logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String? get googleWebClientId {
    const fromDefine = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (fromDefine.isNotEmpty) return fromDefine;
    return '627019837892-ldcv7v96bjk63595lr5e541i2pjslejf.apps.googleusercontent.com';
  }

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
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(serverClientId: googleWebClientId);
      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        await googleSignIn.signOut();
        throw const AppException(
          'Google Sign-In belum terkonfigurasi. Tambahkan SHA-1 aplikasi di '
          'Firebase Console dan aktifkan Google Sign-In, lalu perbarui '
          'google-services.json.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCred = await _auth.signInWithCredential(credential);
      return userCred.user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      Logger.e('google sign in exception', e);
      throw AppException(
          'Login dengan Google gagal: ${e.description ?? e.code.name}', e);
    } on FirebaseAuthException catch (e) {
      Logger.e('google firebase auth failed', e);
      throw AppException(mapAuthError(e), e);
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
      final google = GoogleSignIn.instance;
      await google.signOut();
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
            final googleSignIn = GoogleSignIn.instance;
            await googleSignIn.initialize(serverClientId: googleWebClientId);
            final account = await googleSignIn.authenticate();
            final idToken = account.authentication.idToken;
            if (idToken == null) rethrow;
            await user.reauthenticateWithCredential(
                GoogleAuthProvider.credential(idToken: idToken));
          }
          await _auth.currentUser?.delete();
        } on FirebaseAuthException catch (e2) {
          throw AppException(mapAuthError(e2), e2);
        } on GoogleSignInException catch (e3) {
          throw AppException(
              'Verifikasi ulang dibatalkan. Akun tidak dihapus.', e3);
        }
      } else {
        throw AppException(mapAuthError(e), e);
      }
    }
  }
}
