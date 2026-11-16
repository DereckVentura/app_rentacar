import 'package:flutter/material.dart';

class AutoRentTextField extends StatelessWidget {
  const AutoRentTextField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.autofillHints,
  });
  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscure, enabled;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    obscureText: obscure,
    enabled: enabled,
    keyboardType: keyboardType,
    maxLines: maxLines,
    onChanged: onChanged,
    autofillHints: autofillHints,
    autocorrect: !obscure,
    enableSuggestions: !obscure,
    decoration: InputDecoration(labelText: label),
  );
}
