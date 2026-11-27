import 'dart:convert';

String? mileageError(String? input, {bool allowEmpty = false}) {
  final value = input?.trim() ?? '';
  if (value.isEmpty && allowEmpty) return null;
  return RegExp(r'^[0-9]{1,6}$').hasMatch(value)
      ? null
      : 'Ingresa un kilometraje entero de 0 a 999.999 km.';
}

String? emailError(String? input) {
  final value = input?.trim() ?? '';
  return value.length > 254 ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)
      ? 'Ingresa un correo electrónico válido.'
      : null;
}

String? passwordError(String? input, {bool creating = false}) {
  final value = input ?? '';
  if (value.isEmpty) return 'Ingresa tu contraseña.';
  if (creating && value.runes.length < 8) {
    return 'Usa al menos ocho caracteres.';
  }
  if (utf8.encode(value).length > 72) {
    return 'La contraseña supera el tamaño permitido.';
  }
  return null;
}
