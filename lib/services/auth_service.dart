import 'package:firebase_auth/firebase_auth.dart';
import 'package:g11chat_app/models/auth_user_model.dart';

class AuthServiceException implements Exception {
  const AuthServiceException({required this.code, required this.message});

  final String code;
  final String message;
}

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  AuthUserModel? get currentUser => _mapUser(_auth.currentUser);

  Stream<AuthUserModel?> authStateChanges() {
    return _auth.authStateChanges().map(_mapUser);
  }

  Future<AuthUserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthServiceException(
          code: "user-null",
          message: "User not available after login.",
        );
      }
      return _mapUser(user)!;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(
        code: e.code,
        message: e.message ?? "Authentication error",
      );
    }
  }

  Future<AuthUserModel> register({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthServiceException(
          code: "user-null",
          message: "User not available after registration.",
        );
      }
      return _mapUser(user)!;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(
        code: e.code,
        message: e.message ?? "Authentication error",
      );
    }
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name);
  }

  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
  }

  Future<void> signOut() => _auth.signOut();

  AuthUserModel? _mapUser(User? user) {
    if (user == null) return null;
    return AuthUserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}
