import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { _error = _mapError(e); _loading = false; });
      // Show "sign up?" dialog for missing account
      if (e.code == 'user-not-found') _showSignUpDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'An unexpected error occurred.'; _loading = false; });
    }
  }

  // ── Sign up ────────────────────────────────────────────────────────────────
  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Account created successfully!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { _error = _mapError(e); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'An unexpected error occurred.'; _loading = false; });
    }
  }

  // ── Forgot password ────────────────────────────────────────────────────────
  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter your email address first.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Password reset email sent to $email'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { _error = _mapError(e); _loading = false; });
    }
  }

  void _showSignUpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Account Not Found'),
        content: const Text('No account exists with this email. Would you like to sign up?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _signup(); },
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );
  }

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':         return 'No account found with this email.';
      case 'wrong-password':         return 'Incorrect email or password. Please try again.';
      case 'invalid-email':          return 'Invalid email format.';
      case 'invalid-credential':     return 'Incorrect email or password. Please try again.';
      case 'email-already-in-use':   return 'An account already exists with this email.';
      case 'weak-password':          return 'Password must be at least 6 characters.';
      case 'too-many-requests':      return 'Too many failed attempts. Please try again in 5 minutes.';
      case 'user-disabled':          return 'This account has been disabled.';
      case 'network-request-failed': return 'No internet connection. Please check your network.';
      default: return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final subColor  = Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary;
    final primary   = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      Center(
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            gradient: AppColors.heroGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withOpacity(0.3), 
                                blurRadius: 20, 
                                offset: const Offset(0, 8)
                              )
                            ],
                          ),
                          child: const Icon(Icons.flash_on_rounded, size: 40, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Sparks Invoice', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1.0, color: onSurface)),
                      const SizedBox(height: 8),
                      Text('Premium Invoicing for Professionals', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: subColor, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 48),

                      // Error banner
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.bold))),
                            GestureDetector(
                              onTap: () => setState(() => _error = null),
                              child: const Icon(Icons.close_rounded, color: AppColors.danger, size: 18),
                            ),
                          ]),
                        ),
                      ],

                      // Email field
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_rounded),
                          hintText: 'name@company.com',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v.trim())) return 'Invalid email format';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Password is required';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _forgotPassword,
                          child: Text('Forgot Password?', style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Buttons
                      if (_loading)
                        Center(child: CircularProgressIndicator(color: primary))
                      else ...[
                        ElevatedButton(
                          onPressed: _login,
                          child: const Text('Sign In'),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _signup,
                          child: const Text('Create New Account'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
