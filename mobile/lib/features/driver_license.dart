import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../shared/widgets/screen.dart';

class DriverLicenseForm extends StatefulWidget {
  const DriverLicenseForm({super.key, required this.onSaved});
  final ValueChanged<Json?> onSaved;
  @override
  State<DriverLicenseForm> createState() => _DriverLicenseFormState();
}

class _DriverLicenseFormState extends State<DriverLicenseForm> {
  final holder = TextEditingController(),
      country = TextEditingController(text: 'El Salvador'),
      expiry = TextEditingController();
  Uint8List? front, back;
  bool consent = false, busy = false, saved = false;
  String? error;
  @override
  void dispose() {
    holder.dispose();
    country.dispose();
    expiry.dispose();
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
      final bytes = await file.readAsBytes();
      if (bytes.length > 3 * 1024 * 1024) {
        throw const ApiException('La imagen debe pesar como máximo 3 MB.');
      }
      if (!mounted) return;
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
            TextField(
              controller: country,
              decoration: const InputDecoration(labelText: 'País emisor'),
            ),
            TextField(
              controller: expiry,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Vencimiento de la licencia',
              ),
              onTap: () async {
                final now = DateTime.now();
                final day = await showDatePicker(
                  context: context,
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: DateTime(now.year + 30),
                );
                if (day != null) {
                  expiry.text =
                      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                }
              },
            ),
            for (final reverse in [false, true]) ...[
              Text(
                reverse ? 'Reverso de la licencia' : 'Frente de la licencia',
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
                ],
              ),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: consent,
              title: const Text(
                'Autorizo el uso de mi licencia para verificar esta reserva.',
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
                      if (front == null ||
                          back == null ||
                          holder.text.trim().isEmpty ||
                          country.text.trim().isEmpty ||
                          expiry.text.isEmpty ||
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
                          body: {
                            'titular': holder.text.trim(),
                            'pais': country.text.trim(),
                            'vencimiento': expiry.text,
                            'consentimiento': true,
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
        for (final side in ['front', 'back'])
          FutureBuilder<Uint8List>(
            future: api.image(
              '/driver-documents/${document['id']}/image?side=$side',
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('No se pudo cargar la licencia.');
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Image.memory(
                  snapshot.data!,
                  height: 220,
                  semanticLabel: side == 'front'
                      ? 'Frente de licencia'
                      : 'Reverso de licencia',
                ),
              );
            },
          ),
      ],
    );
  }
}
