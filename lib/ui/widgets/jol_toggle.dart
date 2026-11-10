import 'package:flutter/material.dart';

import '../theme/jol_theme.dart';

class JolToggle extends StatelessWidget {
  const JolToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);

    return Semantics(
      label: label,
      toggled: value,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyLarge),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: tokens.muted),
                    ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: tokens.text,
              activeThumbColor: tokens.background,
              inactiveTrackColor: tokens.surface2,
              inactiveThumbColor: tokens.muted,
            ),
          ],
        ),
      ),
    );
  }
}
