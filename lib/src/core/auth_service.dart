import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Autentikasi: Google Sign-In → Firebase Auth SDK.
/// Sesi disimpan native (tahan restart & offline) — tanpa token manual.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _google = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  Stream<User?> get state => _auth.authStateChanges();

  User? get current => _auth.currentUser;

  /// Login Google. Melempar StateError bila ID token tak didapat,
  /// GoogleSignInException bila dibatalkan/gagal.
  Future<User> signInWithGoogle() async {
    final account = await _google.authenticate();
    final token = account.authentication.idToken;
    if (token.isEmpty) {
      throw StateError('Google tidak memberikan ID token.');
    }
    final credential =
        await _auth.signInWithCredential(GoogleAuthProvider.credential(
      idToken: token,
    ));
    final user = credential.user;
    if (user == null) {
      throw StateError('Login Firebase gagal.');
    }
    return user;
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Putus sesi Google saja (sesi Firebase dipertahankan agar listener
  /// restore/de-ban tetap jalan pada akun yang diblokir).
  Future<void> signOutGoogleOnly() async {
    try {
      await _google.signOut();
    } catch (_) {}
  }
}
