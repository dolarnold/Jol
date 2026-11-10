import 'package:flutter/material.dart';

class JolInput extends StatelessWidget {
  const JolInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}
