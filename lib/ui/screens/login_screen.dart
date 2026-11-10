import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/jol_theme.dart';
import '../widgets/jol_button.dart';
import '../widgets/jol_phone_field.dart';
import '../widgets/jol_theme_button.dart';
import '../widgets/jol_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    JolToast.show(context, 'Sign-in isn’t connected yet, so no code was sent.');
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
                        'Enter your mobile number and we’ll text a code to '
                        'confirm it’s you.',
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: tokens.muted),
                      ),
                      const SizedBox(height: 32),
                      JolPhoneField(
                        controller: _phoneController,
                        validator: _validatePhone,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: JolButton(
                  label: 'Continue',
                  expanded: true,
                  onPressed: _continue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validatePhone(String? value) {
    if ((value ?? '').trim().length != 9) {
      return 'Enter the 9 digits after +27.';
    }
    return null;
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
