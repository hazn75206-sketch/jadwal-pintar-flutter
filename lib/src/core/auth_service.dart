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
  bool _googleReady = false;

  Stream<User?> get state => _auth.authStateChanges();

  User? get current => _auth.currentUser;

  /// google_sign_in v7 wajib initialize dulu; di Android wajib pakai
  /// serverClientId (Web OAuth client). ID ini PUBLIK (sudah ada di setiap
  /// google-services.json/APK) — bukan rahasia.
  /// Sumber: Firebase Console → Project settings → Web client (auto created).
  static const _serverClientId =
      '1094417152750-fll838h1omjsfm2es6anle8sf6mdvh5k.apps.googleusercontent.com';

  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await _google.initialize(serverClientId: _serverClientId);
    _googleReady = true;
  }

  /// Login Google. Melempar StateError bila ID token tak didapat,
  /// GoogleSignInException bila dibatalkan/gagal.
  Future<User> signInWithGoogle() async {
    await _ensureGoogleReady();
    final account = await _google.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
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
