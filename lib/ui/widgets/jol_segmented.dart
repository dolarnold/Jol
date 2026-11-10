import 'package:flutter/material.dart';

class JolSegmented extends StatelessWidget {
  const JolSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelectionChanged,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          for (final option in options)
            ButtonSegment<String>(value: option, label: Text(option)),
        ],
        selected: {selected},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) onSelectionChanged(selection.first);
        },
      ),
    );
  }
}
