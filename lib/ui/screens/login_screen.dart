import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api/api_client.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/auth/privacy_repository.dart';
import '../../data/auth/profile_repository.dart';
import '../theme/jol_theme.dart';
import '../widgets/jol_button.dart';
import '../widgets/jol_theme_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  var _hidePassword = true;
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  var _isSubmitting = false;
  // Set once the server says this account uses two-step login.
  var _needsCode = false;
  String? _errorMessage;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .login(
            login: _normalizeLogin(_loginController.text),
            password: _passwordController.text,
            twoFactorCode: _needsCode ? _codeController.text.trim() : null,
          );
      if (!mounted) return;
      ref.invalidate(currentUserProvider);
      context.go('/discover');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.code == 'TWO_FACTOR_REQUIRED') {
          // Password was right: show the code field.
          _needsCode = true;
          _errorMessage = null;
        } else {
          _errorMessage = error.message;
        }
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _normalizeLogin(String input) {
    final value = input.trim();
    if (value.contains('@')) return value;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 9) return '+27$digits';
    if (digits.length == 10 && digits.startsWith('0')) {
      return '+27${digits.substring(1)}';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: tokens.background,
            systemNavigationBarColor: tokens.background,
          ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _AuthHeader(title: 'Log in', onBack: () => context.pop()),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    children: [
                      Text(
                        'good to see you again',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Log in with the email address or mobile number on '
                        'your JOL account.',
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: tokens.muted),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        key: const ValueKey('login-identifier'),
                        controller: _loginController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter your email or mobile number.'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Email or mobile number',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('login-password'),
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        validator: (value) => (value ?? '').isEmpty
                            ? 'Enter your password.'
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _hidePassword ? 'Show password' : 'Hide password',
                            icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          // Reset by email on the website; then sign in here.
                          onPressed: () => launchUrl(
                            Uri.parse('$siteUrl/forgot-password'),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      if (_needsCode) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('login-two-factor'),
                          controller: _codeController,
                          autofocus: true,
                          keyboardType: TextInputType.text,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _continue(),
                          validator: (value) => (value ?? '').trim().length < 6
                              ? 'Enter the 6-digit code or a recovery code.'
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Code from your authenticator app',
                            helperText:
                                'Lost your phone? Enter a recovery code instead.',
                          ),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: JolButton(
                  label: _isSubmitting ? 'Signing in…' : 'Log in',
                  expanded: true,
                  onPressed: _isSubmitting ? null : _continue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: tokens.muted),
            ),
          ),
          const JolThemeButton(),
        ],
      ),
    );
  }
}
