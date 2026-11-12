import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/api_client.dart';
import '../../data/auth/auth_repository.dart';
import '../theme/jol_theme.dart';
import '../widgets/jol_button.dart';
import '../widgets/jol_phone_field.dart';
import '../widgets/jol_theme_button.dart';
import '../widgets/jol_toast.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
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
          .registerAttendee(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: '+27${_phoneController.text.trim()}',
            password: _passwordController.text,
          );
      if (!mounted) return;
      JolToast.show(
        context,
        'Account created. Check your email to verify your address.',
      );
      context.go('/discover');
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
              _SignUpHeader(onBack: () => context.pop()),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                    children: [
                      Text(
                        'Let’s get you in',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create your JOL account with your email and mobile '
                        'number.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: tokens.muted, fontSize: 15),
                      ),
                      const SizedBox(height: 20),
                      _LabeledField(
                        label: 'Full name',
                        child: TextFormField(
                          key: const ValueKey('signup-name'),
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter your full name.'
                              : null,
                          decoration: const InputDecoration(
                            hintText: 'Your name',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      JolPhoneField(
                        controller: _phoneController,
                        validator: (value) => (value ?? '').trim().length != 9
                            ? 'Enter the 9 digits after +27.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: 'Email',
                        child: TextFormField(
                          key: const ValueKey('signup-email'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: _validateEmail,
                          decoration: const InputDecoration(
                            hintText: 'you@example.com',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: 'Password',
                        child: TextFormField(
                          key: const ValueKey('signup-password'),
                          controller: _passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          validator: (value) => (value ?? '').length < 8
                              ? 'Use at least 8 characters.'
                              : null,
                          decoration: const InputDecoration(
                            hintText: 'At least 8 characters',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Student verification is not connected to the API yet.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: tokens.muted),
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
              _SignUpFooter(
                isSubmitting: _isSubmitting,
                onContinue: _isSubmitting ? null : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}

class _SignUpHeader extends StatelessWidget {
  const _SignUpHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: const Icon(Icons.arrow_back),
          ),
          const JolThemeButton(),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SignUpFooter extends StatelessWidget {
  const _SignUpFooter({required this.isSubmitting, required this.onContinue});

  final bool isSubmitting;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.background,
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'By continuing, you agree to JOL’s Terms and Privacy Policy.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: tokens.muted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          JolButton(
            key: const ValueKey('signup-continue'),
            label: isSubmitting ? 'Creating account…' : 'Create account',
            expanded: true,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}
