import 'package:flutter/material.dart';

import '../theme/jol_theme.dart';

abstract final class JolToast {
  static void show(BuildContext context, String message) {
    final tokens = JolTokens.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: tokens.text)),
          duration: const Duration(milliseconds: 2200),
          behavior: SnackBarBehavior.floating,
          backgroundColor: tokens.surface2,
          shape: const StadiumBorder(),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        ),
      );
  }
}
