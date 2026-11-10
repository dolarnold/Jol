import 'package:flutter/material.dart';

import '../theme/jol_theme.dart';
import '../widgets/jol_button.dart';
import '../widgets/jol_card.dart';
import '../widgets/jol_chip.dart';
import '../widgets/jol_input.dart';
import '../widgets/jol_list_row.dart';
import '../widgets/jol_logo.dart';
import '../widgets/jol_segmented.dart';
import '../widgets/jol_sheet.dart';
import '../widgets/jol_toast.dart';
import '../widgets/jol_toggle.dart';

class WidgetGalleryScreen extends StatefulWidget {
  const WidgetGalleryScreen({super.key});

  @override
  State<WidgetGalleryScreen> createState() => _WidgetGalleryScreenState();
}

class _WidgetGalleryScreenState extends State<WidgetGalleryScreen> {
  bool _toggleValue = true;
  bool _chipSelected = true;
  String _segment = 'Events';

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Widget gallery')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            'Foundation components',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Reusable building blocks in the default dark theme.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'Brand',
            child: const JolCard(
              child: Center(child: JolLogo(size: 44, withWordmark: true)),
            ),
          ),
          _Section(
            title: 'Buttons',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                JolButton(
                  label: 'Primary',
                  onPressed: () => JolToast.show(context, 'Primary button'),
                ),
                JolButton(
                  label: 'Purchase',
                  variant: JolButtonVariant.purchase,
                  onPressed: () => JolToast.show(context, 'Purchase button'),
                ),
                JolButton(
                  label: 'Secondary',
                  variant: JolButtonVariant.secondary,
                  onPressed: () => JolToast.show(context, 'Secondary button'),
                ),
                JolButton(
                  label: 'Ghost',
                  variant: JolButtonVariant.ghost,
                  onPressed: () => JolToast.show(context, 'Ghost button'),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Card and list row',
            child: JolCard(
              child: Column(
                children: [
                  const JolListRow(
                    title: 'List row title',
                    subtitle: 'Supporting information goes here',
                    trailing: Icon(Icons.chevron_right),
                  ),
                  Divider(color: tokens.line),
                  JolListRow(
                    title: 'Tap to see a toast',
                    trailing: const Icon(Icons.arrow_forward, size: 20),
                    onTap: () => JolToast.show(context, 'List row selected'),
                  ),
                ],
              ),
            ),
          ),
          _Section(
            title: 'Input',
            child: const JolInput(
              label: 'Event name',
              hint: 'Something worth going out for',
            ),
          ),
          _Section(
            title: 'Toggle',
            child: JolCard(
              child: JolToggle(
                label: 'Show me on public guest lists',
                subtitle: 'You can change this any time.',
                value: _toggleValue,
                onChanged: (value) => setState(() => _toggleValue = value),
              ),
            ),
          ),
          _Section(
            title: 'Segmented control',
            child: JolSegmented(
              options: const ['Events', 'Analytics'],
              selected: _segment,
              onSelectionChanged: (value) => setState(() => _segment = value),
            ),
          ),
          _Section(
            title: 'Chip',
            child: Wrap(
              spacing: 8,
              children: [
                JolChip(
                  label: 'Selected',
                  selected: _chipSelected,
                  onSelected: (value) => setState(() => _chipSelected = value),
                ),
                JolChip(
                  label: 'Unselected',
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
          _Section(
            title: 'Sheet and toast',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                JolButton(
                  label: 'Show sheet',
                  variant: JolButtonVariant.secondary,
                  onPressed: () => JolSheet.show<void>(
                    context: context,
                    title: 'Example sheet',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A shared bottom-sheet surface for key actions.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        JolButton(
                          label: 'Done',
                          expanded: true,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
                JolButton(
                  label: 'Show toast',
                  variant: JolButtonVariant.ghost,
                  onPressed: () => JolToast.show(context, 'Saved for later'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(title, style: Theme.of(context).textTheme.labelSmall),
          ),
          child,
        ],
      ),
    );
  }
}
