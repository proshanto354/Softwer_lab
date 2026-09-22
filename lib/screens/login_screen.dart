import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';

/// Combined login / sign-up screen. The app uses a single screen with a
/// toggle (rather than two separate routes) — this preserves that existing
/// navigation flow while giving each mode ("Login" and "Create account")
/// its own professional layout and copy.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _message;
  bool _isError = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password. If you are new here, tap "Create an account".';
      case 'email-already-in-use':
        return 'An account already exists for this email. Try logging in.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
      case 'configuration-not-found':
        return 'Email/Password sign-in is not enabled in the Firebase console.';
      case 'invalid-api-key':
      case 'api-key-not-valid.-please-pass-a-valid-api-key.':
        return 'The Firebase API key is wrong. Check firebaseWebOptions in config.dart.';
      case 'network-request-failed':
        return 'No connection to Firebase. Check your internet and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  void _show(String msg, {bool error = true}) {
    if (!mounted) return;
    setState(() {
      _message = msg;
      _isError = error;
    });
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.length < 6) {
      _show('Enter a valid email and a password of at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_signUp) {
        await auth.createUserWithEmailAndPassword(email: email, password: pass);
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: pass);
      }
      // On success the AuthGate in main.dart switches screens automatically.
    } on FirebaseAuthException catch (e) {
      _show('${_friendly(e)}\n(${e.code})');
    } catch (e) {
      _show('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _show('Type your email first, then tap "Forgot password?".');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _show('Password reset email sent. Check your inbox.', error: false);
    } on FirebaseAuthException catch (e) {
      _show('${_friendly(e)}\n(${e.code})');
    }
  }

  void _toggleMode() => setState(() {
    _signUp = !_signUp;
    _message = null;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Brand(),
                        const SizedBox(height: 36),
                        _ModeSwitcher(signUp: _signUp, onChanged: (v) {
                          if (v != _signUp) _toggleMode();
                        }),
                        const SizedBox(height: 24),
                        Text(
                          _signUp ? 'Create your account' : 'Welcome back to Shomman',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _signUp
                              ? 'Create your account to access Shomman services and support.'
                              : 'Log in to continue using Shomman and support our elders.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        CustomTextField(
                          controller: _email,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.mail_outline,
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: _password,
                          label: 'Password',
                          obscureText: _hidePassword,
                          prefixIcon: Icons.lock_outline,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _busy ? null : _submit(),
                          suffixIcon: IconButton(
                            icon: Icon(_hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.textSecondary),
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                        if (!_signUp) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _reset,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        ] else
                          const SizedBox(height: 8),
                        if (_message != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isError ? AppColors.errorBg : AppColors.successBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _message!,
                              style: TextStyle(color: _isError ? AppColors.error : AppColors.success, fontSize: 13),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        PrimaryButton(
                          label: _signUp ? 'Create account' : 'Login',
                          loading: _busy,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: _toggleMode,
                            child: Text(_signUp ? 'Already have an account? Login' : "New here? Create an account"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.volunteer_activism, size: 36, color: AppColors.primary),
    ),
    const SizedBox(height: 14),
    Text('Shomman',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.textPrimary)),
    const SizedBox(height: 4),
    const Text('A safe digital voice for our elders',
        textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
  ]);
}

/// Segmented Login / Create account switch.
class _ModeSwitcher extends StatelessWidget {
  final bool signUp;
  final ValueChanged<bool> onChanged;
  const _ModeSwitcher({required this.signUp, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Expanded(child: _segment(context, 'Login', !signUp, () => onChanged(false))),
      Expanded(child: _segment(context, 'Sign up', signUp, () => onChanged(true))),
    ]),
  );

  Widget _segment(BuildContext context, String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        boxShadow: selected
            ? [const BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 1))]
            : null,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: selected ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    ),
  );
}
