import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/api_client.dart';
import '../../data/auth/auth_repository.dart';
import '../theme/jol_theme.dart';
import '../widgets/jol_button.dart';
import '../widgets/jol_theme_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
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
          );
      if (!mounted) return;
      context.go('/discover');
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
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
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) => (value ?? '').isEmpty
                            ? 'Enter your password.'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
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
