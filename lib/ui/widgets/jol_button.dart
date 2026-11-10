import 'package:flutter/material.dart';

import '../theme/jol_theme.dart';

enum JolButtonVariant { primary, purchase, secondary, ghost }

class JolButton extends StatelessWidget {
  const JolButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = JolButtonVariant.primary,
    this.small = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final JolButtonVariant variant;
  final bool small;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final (background, foreground, side) = switch (variant) {
      JolButtonVariant.primary => (
        tokens.text,
        tokens.background,
        BorderSide.none,
      ),
      JolButtonVariant.purchase => (
        tokens.accent,
        tokens.onAccent,
        BorderSide.none,
      ),
      JolButtonVariant.secondary => (
        tokens.surface2,
        tokens.text,
        BorderSide.none,
      ),
      JolButtonVariant.ghost => (
        Colors.transparent,
        tokens.text,
        BorderSide(color: tokens.line),
      ),
    };

    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: tokens.surface2,
        disabledForegroundColor: tokens.muted,
        minimumSize: Size(0, small ? 44 : 54),
        padding: EdgeInsets.symmetric(horizontal: small ? 16 : 24),
        shape: const StadiumBorder(),
        side: side,
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: foreground),
      ),
      child: Text(label),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}
