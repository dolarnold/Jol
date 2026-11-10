import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/jol_theme_mode.dart';

class JolThemeButton extends ConsumerWidget {
  const JolThemeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(jolThemeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final label = isDark ? 'Switch to light theme' : 'Switch to dark theme';

    return IconButton(
      onPressed: ref.read(jolThemeModeProvider.notifier).toggle,
      tooltip: label,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );
  }
}
