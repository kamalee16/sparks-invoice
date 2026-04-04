import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> login(String email, String password) async {
    // Sanitize inputs
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass  = password.trim();

    if (cleanEmail.isEmpty) return 'Please enter your email.';
    if (cleanPass.isEmpty)  return 'Please enter your password.';
    if (!cleanEmail.contains('@')) return 'Enter a valid email address.';

    try {
      await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPass,
      );
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<String?> signup(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass  = password.trim();

    if (cleanEmail.isEmpty) return 'Please enter your email.';
    if (cleanPass.isEmpty)  return 'Please enter your password.';
    if (!cleanEmail.contains('@')) return 'Enter a valid email address.';
    if (cleanPass.length < 6) return 'Password must be at least 6 characters.';

    try {
      await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPass,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return 'Enter a valid email address first.';
    }
    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (_) {
      return 'Failed to send reset email. Please try again.';
    }
  }

  Future<void> logout() => _auth.signOut();

  Stream<User?> get user => _auth.authStateChanges();

  /// Maps Firebase error codes to user-friendly messages.
  /// Covers both legacy codes and the newer 'invalid-credential' code
  /// returned by Firebase SDK v9+ for security reasons.
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'invalid-credential':
        // Firebase SDK v9+ merges user-not-found + wrong-password into this
        return 'Email or password is incorrect. Please check and try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password login is not enabled. Contact support.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
