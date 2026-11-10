import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/jol_theme.dart';
import '../widgets/jol_button.dart';
import '../widgets/jol_card.dart';
import '../widgets/jol_theme_button.dart';

class TabPlaceholderScreen extends StatelessWidget {
  const TabPlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.showGalleryLink = false,
  });

  final String title;
  final String subtitle;
  final bool showGalleryLink;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 116),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (showGalleryLink) const JolThemeButton(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 28),
          JolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THE JOL APP',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'A little more life, together.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'The foundation is ready. This screen will take shape in its '
                  'feature phase.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: tokens.muted),
                ),
              ],
            ),
          ),
          if (showGalleryLink) ...[
            const SizedBox(height: 20),
            JolButton(
              label: 'Open widget gallery',
              expanded: true,
              variant: JolButtonVariant.secondary,
              onPressed: () => context.push('/gallery'),
            ),
          ],
        ],
      ),
    );
  }
}
