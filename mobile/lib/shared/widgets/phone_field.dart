import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneCountry {
  const PhoneCountry(this.name, this.prefix, this.min, this.max);
  final String name, prefix;
  final int min, max;
}

const _countries = [
  PhoneCountry('El Salvador', '+503', 8, 8),
  PhoneCountry('Guatemala', '+502', 8, 8),
  PhoneCountry('Honduras', '+504', 8, 8),
  PhoneCountry('Nicaragua', '+505', 8, 8),
  PhoneCountry('Costa Rica', '+506', 8, 8),
  PhoneCountry('Panamá', '+507', 7, 8),
  PhoneCountry('Belice', '+501', 7, 7),
  PhoneCountry('México', '+52', 10, 10),
  PhoneCountry('Estados Unidos y Canadá', '+1', 10, 10),
  PhoneCountry('España', '+34', 9, 9),
  PhoneCountry('Otro país', '+', 8, 15),
];

PhoneCountry _phoneCountry(String cleaned) => cleaned.startsWith('+')
    ? _countries.firstWhere((country) => cleaned.startsWith(country.prefix))
    : _countries.first;

String? validatedPhone(String? input) {
  final value = (input ?? '').replaceAll(RegExp(r'[ ().-]'), '');
  final number = RegExp(r'^\d{8}$').hasMatch(value) ? '+503$value' : value;
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(number)) return null;
  final country = _phoneCountry(number);
  final length = number.length - country.prefix.length;
  return length >= country.min && length <= country.max ? number : null;
}

class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    this.initialValue = '',
    required this.onChanged,
  });
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late PhoneCountry country;
  late final TextEditingController digits;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue.replaceAll(RegExp(r'[ ().-]'), '');
    country = _phoneCountry(initial);
    digits = TextEditingController(
      text: initial.startsWith('+')
          ? initial.substring(country.prefix.length)
          : initial,
    );
  }

  @override
  void dispose() {
    digits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<PhoneCountry>(
        initialValue: country,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'País o región'),
        items: [
          for (final item in _countries)
            DropdownMenuItem(
              value: item,
              child: Text(
                item.prefix == '+' ? item.name : '${item.name} ${item.prefix}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) {
          if (value == null || value == country) return;
          setState(() => country = value);
          digits.clear();
          widget.onChanged('');
        },
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: digits,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(country.max),
        ],
        decoration: InputDecoration(
          labelText: country.prefix == '+'
              ? 'Número con código de país'
              : 'Celular',
          prefixText: '${country.prefix} ',
          helperText: country.min == country.max
              ? '${country.min} dígitos'
              : '${country.min} a ${country.max} dígitos',
        ),
        onChanged: (value) =>
            widget.onChanged(value.isEmpty ? '' : '${country.prefix}$value'),
        validator: (value) =>
            validatedPhone('${country.prefix}${value ?? ''}') == null
            ? 'Ingresa un celular válido.'
            : null,
      ),
    ],
  );
}
