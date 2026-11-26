import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../shared/widgets/screen.dart';
import '../shared/widgets/photo_crop.dart';

class DriverLicenseForm extends StatefulWidget {
  const DriverLicenseForm({super.key, required this.onSaved});
  final ValueChanged<Json?> onSaved;
  @override
  State<DriverLicenseForm> createState() => _DriverLicenseFormState();
}

class _DriverLicenseFormState extends State<DriverLicenseForm> {
  final holder = TextEditingController(), year = TextEditingController();
  int? month;
  Uint8List? front, back;
  bool consent = false, busy = false, saved = false;
  String? error;
  @override
  void dispose() {
    holder.dispose();
    year.dispose();
    super.dispose();
  }

  Future<void> pick(bool reverse, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2200,
        maxHeight: 2200,
        imageQuality: 90,
      );
      if (file == null) return;
      final original = await file.readAsBytes();
      if (!mounted) return;
      final bytes = await cropPhoto(
        context,
        original,
        width: 1280,
        height: 807,
      );
      if (!mounted || bytes == null) return;
      if (bytes.length > 3 * 1024 * 1024) {
        throw const ApiException('La imagen debe pesar como máximo 3 MB.');
      }
      setState(() {
        if (reverse) {
          back = bytes;
        } else {
          front = bytes;
        }
        saved = false;
        error = null;
      });
      widget.onSaved(null);
    } catch (e) {
      if (mounted) tell(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Licencia de conducir obligatoria',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Adjunta ambas caras completas y legibles. La administración verificará la licencia antes de entregar el vehículo.',
          ),
          if (saved) ...[
            const Text('Licencia adjunta · Pendiente de revisión'),
            TextButton(
              onPressed: () {
                setState(() => saved = false);
                widget.onSaved(null);
              },
              child: const Text('Cambiar licencia'),
            ),
          ] else ...[
            TextField(
              controller: holder,
              decoration: const InputDecoration(
                labelText: 'Nombre completo del titular',
              ),
            ),
            DropdownButtonFormField<int>(
              initialValue: month,
              decoration: const InputDecoration(
                labelText: 'Mes de vencimiento',
              ),
              items: [
                for (var value = 1; value <= 12; value++)
                  DropdownMenuItem(
                    value: value,
                    child: Text(value.toString().padLeft(2, '0')),
                  ),
              ],
              onChanged: busy ? null : (value) => setState(() => month = value),
            ),
            TextField(
              controller: year,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Año de vencimiento',
                hintText: 'AAAA',
              ),
            ),
            for (final reverse in [false, true]) ...[
              Text(
                reverse ? 'Reverso de la licencia' : 'Frente de la licencia',
              ),
              const Text(
                'Centra la licencia en la cámara y deja los bordes visibles.',
              ),
              if ((reverse ? back : front) != null)
                Image.memory(
                  (reverse ? back : front)!,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => pick(reverse, ImageSource.camera),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Escanear con cámara'),
                  ),
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => pick(reverse, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Cargar imagen'),
                  ),
                  if ((reverse ? back : front) != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              setState(() {
                                if (reverse) {
                                  back = null;
                                } else {
                                  front = null;
                                }
                              });
                              widget.onSaved(null);
                            },
                      child: const Text('Quitar foto'),
                    ),
                ],
              ),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: consent,
              title: const Text(
                'Autorizo el uso de mi licencia para que administración revise esta reserva.',
              ),
              onChanged: busy
                  ? null
                  : (v) => setState(() => consent = v ?? false),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final enteredYear = int.tryParse(year.text);
                      if (front == null ||
                          back == null ||
                          holder.text.trim().isEmpty ||
                          month == null ||
                          enteredYear == null ||
                          enteredYear < 2000 ||
                          enteredYear > DateTime.now().year + 30 ||
                          !consent) {
                        setState(
                          () => error = 'Completa los datos, adjunta ambas caras y autoriza su revisión.',
                        );
                        return;
                      }
                      final api = AppScope.of(context).api;
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final result = await api.call(
                          '/driver-documents',
                          method: 'POST',
                          responseTimeout: const Duration(seconds: 35),
                          body: {
                            'titular': holder.text.trim(),
                            'pais': 'El Salvador',
                            'vencimiento': DateTime(
                              enteredYear,
                              month! + 1,
                              0,
                            ).toIso8601String().split('T').first,
                            'consentimiento': true,
                            'encuadrada': true,
                            'frente': base64Encode(front!),
                            'reverso': base64Encode(back!),
                          },
                        );
                        if (mounted) {
                          widget.onSaved(result['document'] as Json);
                          setState(() => saved = true);
                        }
                      } catch (e) {
                        if (mounted) setState(() => error = e.toString());
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: Text(busy ? 'Guardando licencia…' : 'Adjuntar licencia'),
            ),
          ],
        ],
      ),
    ),
  );
}

class DriverLicenseReview extends StatelessWidget {
  const DriverLicenseReview({super.key, required this.document});
  final Json document;
  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
    return Column(
      children: [
        Text('${document['titular']} · Vence ${document['vencimiento']}'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final side in ['front', 'back'])
              Expanded(
                child: _LicenseSide(
                  key: ValueKey('${document['id']}-$side'),
                  api: api,
                  path: '/driver-documents/${document['id']}/image?side=$side',
                  label: side == 'front'
                      ? 'Frente de licencia'
                      : 'Reverso de licencia',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LicenseSide extends StatefulWidget {
  const _LicenseSide({
    super.key,
    required this.api,
    required this.path,
    required this.label,
  });
  final Api api;
  final String path, label;
  @override
  State<_LicenseSide> createState() => _LicenseSideState();
}

class _LicenseSideState extends State<_LicenseSide> {
  late final image = widget.api.image(widget.path);
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: image,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const Text('No se pudo cargar la foto.');
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final bytes = snapshot.data!;
      return TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (dialog) => Dialog(
            child: SizedBox(
              height: MediaQuery.sizeOf(dialog).height * .7,
              child: Column(
                children: [
                  Expanded(
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Center(
                        child: Image.memory(bytes, semanticLabel: widget.label),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1280 / 807,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                semanticLabel: widget.label,
              ),
            ),
            Text(widget.label),
          ],
        ),
      );
    },
  );
}
