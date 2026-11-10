import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/jol_theme.dart';

class JolPhoneField extends StatelessWidget {
  const JolPhoneField({
    super.key,
    required this.controller,
    required this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mobile number', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('mobile-number'),
          controller: controller,
          validator: validator,
          onChanged: onChanged,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          maxLength: 9,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: '82 555 0147',
            counterText: '',
            prefixIcon: Container(
              width: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.surface2,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(13),
                ),
                border: Border(right: BorderSide(color: tokens.line)),
              ),
              child: Text('+27', style: Theme.of(context).textTheme.bodyLarge),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 56,
              minHeight: 50,
            ),
          ),
        ),
      ],
    );
  }
}
