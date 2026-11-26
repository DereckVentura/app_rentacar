import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.suffixIcon,
    this.maxLength,
    this.inputFormatters,
  });
  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscure, enabled;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    obscureText: obscure,
    enabled: enabled,
    keyboardType: keyboardType,
    maxLines: maxLines,
    maxLength: maxLength,
    inputFormatters: inputFormatters,
    onChanged: onChanged,
    autofillHints: autofillHints,
    autocorrect: !obscure && keyboardType != TextInputType.visiblePassword,
    enableSuggestions:
        !obscure && keyboardType != TextInputType.visiblePassword,
    decoration: InputDecoration(labelText: label, suffixIcon: suffixIcon),
  );
}
