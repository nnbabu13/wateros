import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AmountInput extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? prefix;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final double? initialValue;

  const AmountInput({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.prefix = '₹',
    this.readOnly = false,
    this.onChanged,
    this.validator,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? '0.00',
        prefixText: prefix,
        prefixStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }
}

class QuantityInput extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String unit;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const QuantityInput({
    super.key,
    required this.controller,
    this.label,
    this.unit = 'pcs',
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label ?? 'Quantity',
        suffixText: unit,
        suffixStyle: TextStyle(
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}
