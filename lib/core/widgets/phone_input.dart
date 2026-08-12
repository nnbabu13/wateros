import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneInput extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const PhoneInput({
    super.key,
    required this.controller,
    this.label,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label ?? 'Phone Number',
        prefixText: '+91 ',
        prefixStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        counterText: '',
      ),
    );
  }
}
