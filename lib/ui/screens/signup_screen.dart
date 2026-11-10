import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/student_email_validator.dart';
import '../theme/jol_theme.dart';
import '../widgets/jol_button.dart';
import '../widgets/jol_phone_field.dart';
import '../widgets/jol_theme_button.dart';
import '../widgets/jol_toast.dart';
import '../widgets/jol_toggle.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentEmailController = TextEditingController();
  bool _isStudent = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _studentEmailController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    JolToast.show(context, 'Sign-up isn’t connected yet, so no code was sent.');
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
                        'Takes under a minute. We’ll text a code to confirm '
                        'your number.',
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
                        helper: '(for receipts)',
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
                      _StudentCard(
                        isStudent: _isStudent,
                        emailController: _studentEmailController,
                        onChanged: (value) {
                          setState(() => _isStudent = value);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              _SignUpFooter(onContinue: _continue),
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
  const _LabeledField({required this.label, required this.child, this.helper});

  final String label;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: Theme.of(context).textTheme.labelLarge,
            children: [
              if (helper != null)
                TextSpan(
                  text: ' $helper',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: JolTokens.of(context).muted),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.isStudent,
    required this.emailController,
    required this.onChanged,
  });

  final bool isStudent;
  final TextEditingController emailController;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JolToggle(
            label: 'I’m a student',
            subtitle: 'Unlock student prices where events offer them.',
            value: isStudent,
            onChanged: onChanged,
          ),
          if (isStudent) ...[
            const SizedBox(height: 4),
            Text(
              'Student email',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey('student-email'),
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              validator: (value) => isValidStudentEmail(value ?? '')
                  ? null
                  : "That isn't a student email. Use your university "
                        'address ending in .ac.za, like name@myuct.ac.za.',
              decoration: const InputDecoration(hintText: 'you@myuct.ac.za'),
            ),
            const SizedBox(height: 6),
            Text(
              'Use the email your university gave you (ending in .ac.za). '
              'We’ll send a code there to verify you.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: tokens.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignUpFooter extends StatelessWidget {
  const _SignUpFooter({required this.onContinue});

  final VoidCallback onContinue;

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
            label: 'Send code & continue',
            expanded: true,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}
