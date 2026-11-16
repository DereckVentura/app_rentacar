import 'package:flutter/services.dart';

Future<String> saveText(String name, String text, String type) async {
  await Clipboard.setData(ClipboardData(text: text));
  return 'Contenido copiado. Puedes guardarlo en un archivo de texto.';
}
