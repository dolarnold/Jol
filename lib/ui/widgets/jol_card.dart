import 'package:flutter/material.dart';

import '../theme/jol_theme.dart';

class JolCard extends StatelessWidget {
  const JolCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool? border;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: (border ?? false) ? Border.all(color: tokens.line) : null,
      ),
      child: child,
    );
  }
}
