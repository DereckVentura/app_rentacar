import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String> saveText(String name, String text, String type) async {
  final blob = web.Blob([text.toJS].toJS, web.BlobPropertyBag(type: type));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  anchor.click();
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => web.URL.revokeObjectURL(url),
  );
  return 'Archivo preparado para descargar.';
}
