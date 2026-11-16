import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/save_text.dart';
import '../shared/widgets/autorent_button.dart';
import '../shared/widgets/autorent_text_field.dart';
import '../shared/widgets/brand.dart';
import '../shared/widgets/screen.dart';

const accountNotice =
    'Consulta las condiciones del servicio y gestiona tus datos desde tu cuenta.';
void openHelp(BuildContext c) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => const HelpPage()));

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ayuda y condiciones')),
    body: DataView(
      load: () => AppScope.of(context).api.call('/content'),
      builder: (data) {
        final b = data['business'] as Json;
        return PageBody(
          children: [
            const MolinaBrand(),
            const HintBox(accountNotice),
            Text(
              '${b['direccion']}\n${b['municipio']}\n${b['telefono']}${b['correo'] == null ? '' : '\n${b['correo']}'}',
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: b['telefono'].toString()),
                );
                if (context.mounted) tell(context, 'Teléfono copiado.');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar teléfono'),
            ),
            Text(
              'Preguntas frecuentes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ...(b['faq'] as List).map(
              (q) => Card(
                child: ExpansionTile(
                  title: Text(q['pregunta'].toString()),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(q['respuesta'].toString()),
                    ),
                  ],
                ),
              ),
            ),
            Text('Documentos', style: Theme.of(context).textTheme.titleLarge),
            ...(data['documents'] as List).map(
              (d) => ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(d['titulo'].toString()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LegalDocumentPage(
                      document: d as Json,
                      version: data['version'].toString(),
                    ),
                  ),
                ),
              ),
            ),
            if (AppScope.of(context).user != null)
              AutoRentButton(
                label: 'Privacidad y mis datos',
                secondary: true,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPage()),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    super.key,
    required this.document,
    required this.version,
  });
  final Json document;
  final String version;
  @override
  Widget build(BuildContext context) {
    final text =
        '${document['titulo']}\nVersión SHA-256: $version\n\n${document['texto']}';
    return Scaffold(
      appBar: AppBar(title: Text(document['titulo'].toString())),
      body: PageBody(
        children: [
          const HintBox(accountNotice),
          SelectableText(document['texto'].toString()),
          Text(
            'Versión $version',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          AutoRentButton(
            label: 'Guardar o copiar documento',
            secondary: true,
            onPressed: () async {
              final message = await saveText(
                'autorent-${document['id']}.txt',
                text,
                'text/plain;charset=utf-8',
              );
              if (context.mounted) tell(context, message);
            },
          ),
        ],
      ),
    );
  }
}

class LegalConsent extends StatefulWidget {
  const LegalConsent({super.key, required this.onChanged});
  final ValueChanged<Json?> onChanged;
  @override
  State<LegalConsent> createState() => _LegalConsentState();
}

class _LegalConsentState extends State<LegalConsent> {
  bool privacy = false, terms = false;
  @override
  Widget build(BuildContext context) => DataView(
    inline: true,
    load: () => AppScope.of(context).api.call('/content'),
    builder: (data) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(accountNotice),
        ...(data['documents'] as List).map(
          (d) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LegalDocumentPage(
                  document: d as Json,
                  version: data['version'].toString(),
                ),
              ),
            ),
            child: Text(d['titulo'].toString()),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('He leído el aviso de privacidad'),
          value: privacy,
          onChanged: (v) => setState(() {
            privacy = v ?? false;
            widget.onChanged(
              privacy && terms
                  ? {
                      'version': data['version'],
                      'privacidad': true,
                      'terminos': true,
                    }
                  : null,
            );
          }),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Acepto las condiciones de uso'),
          value: terms,
          onChanged: (v) => setState(() {
            terms = v ?? false;
            widget.onChanged(
              privacy && terms
                  ? {
                      'version': data['version'],
                      'privacidad': true,
                      'terminos': true,
                    }
                  : null,
            );
          }),
        ),
      ],
    ),
  );
}

const privacyTypes = {
  'acceso': 'Acceso',
  'rectificacion': 'Rectificación',
  'supresion': 'Supresión de datos o cuenta',
  'oposicion': 'Oposición',
  'portabilidad': 'Portabilidad',
  'olvido': 'Olvido',
  'limitacion': 'Limitación',
  'retiro_consentimiento': 'Retiro de consentimiento',
  'reclamo': 'Reclamo',
};

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  int version = 0, page = 1;
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.admin
              ? 'Solicitudes de datos y reclamos'
              : 'Privacidad y mis datos',
        ),
      ),
      body: DataView(
        key: ValueKey('$version/$page'),
        load: () => s.api.call(
          '/privacy/requests',
          query: {'page': '$page', 'limit': '20'},
        ),
        builder: (data) {
          final rows = (data['requests'] as List).cast<Json>();
          return PageBody(
            children: [
              const HintBox(
                'Cada solicitud genera una constancia. Puedes consultar la respuesta aquí. No adjuntes DUI, licencia, contraseñas ni datos de tarjetas. La supresión requiere revisión y no elimina automáticamente registros que deban conservarse.',
              ),
              AutoRentButton(
                label: 'Guardar o copiar mis datos',
                secondary: true,
                loading: busy,
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          final result = await s.api.call('/privacy/export');
                          final message = await saveText(
                            'mis-datos-autorent.json',
                            const JsonEncoder.withIndent('  ').convert(result),
                            'application/json',
                          );
                          if (context.mounted) tell(context, message);
                        } catch (e) {
                          if (context.mounted) tell(context, e);
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
              ),
              AutoRentButton(
                label: 'Presentar solicitud o reclamo',
                onPressed: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyRequestEditor(),
                    ),
                  );
                  if (ok == true && mounted) setState(() => version++);
                },
              ),
              if (rows.isEmpty)
                const HintBox('No hay solicitudes para mostrar.'),
              ...rows.map(
                (r) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Constancia #${r['id']} · ${privacyTypes[r['tipo']] ?? r['tipo']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${r['estado']} · ${dateLabel("${'${r['creado_en']}'.replaceFirst(' ', 'T')}Z")}',
                        ),
                        if (s.admin)
                          Text(
                            '${r['nombres']} ${r['apellidos']} · ${r['email']}',
                          ),
                        SelectableText(r['detalle'].toString()),
                        if (r['respuesta'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: SelectableText(
                              'Respuesta: ${r['respuesta']}',
                            ),
                          ),
                        if (s.admin)
                          TextButton(
                            onPressed: () async {
                              final ok = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PrivacyResponseEditor(request: r),
                                ),
                              );
                              if (ok == true && mounted) {
                                setState(() => version++);
                              }
                            },
                            child: const Text('Atender solicitud'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: page > 1 ? () => setState(() => page--) : null,
                    child: const Text('Anterior'),
                  ),
                  Text('Página $page'),
                  TextButton(
                    onPressed: rows.length == 20
                        ? () => setState(() => page++)
                        : null,
                    child: const Text('Siguiente'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class PrivacyRequestEditor extends StatefulWidget {
  const PrivacyRequestEditor({super.key});
  @override
  State<PrivacyRequestEditor> createState() => _PrivacyRequestEditorState();
}

class _PrivacyRequestEditorState extends State<PrivacyRequestEditor> {
  final detail = TextEditingController();
  String type = 'acceso';
  @override
  void dispose() {
    detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Solicitud o reclamo',
    label: 'Enviar y obtener constancia',
    fields: [
      DropdownButtonFormField<String>(
        initialValue: type,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Tipo'),
        items: privacyTypes.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) => setState(() => type = v!),
      ),
      TextFormField(
        controller: detail,
        maxLength: 2000,
        maxLines: 6,
        validator: requiredText,
        decoration: const InputDecoration(
          labelText: 'Describe lo que necesitas',
        ),
      ),
      const Text(
        'Puedes seguir el estado y la respuesta en esta sección. Para cambiar datos, indica cuáles deben corregirse. No envíes documentos personales.',
      ),
    ],
    save: () async {
      final r = await AppScope.of(context).api.call(
        '/privacy/requests',
        method: 'POST',
        body: {'tipo': type, 'detalle': detail.text.trim()},
      );
      if (context.mounted) {
        tell(context, 'Solicitud recibida. Constancia #${r['id']}.');
      }
    },
  );
}

class PrivacyResponseEditor extends StatefulWidget {
  const PrivacyResponseEditor({super.key, required this.request});
  final Json request;
  @override
  State<PrivacyResponseEditor> createState() => _PrivacyResponseEditorState();
}

class _PrivacyResponseEditorState extends State<PrivacyResponseEditor> {
  late final answer = TextEditingController(
    text: widget.request['respuesta']?.toString(),
  );
  String state = 'en_revision';
  @override
  void dispose() {
    answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Atender constancia #${widget.request['id']}',
    fields: [
      SelectableText(widget.request['detalle'].toString()),
      const HintBox(
        'Documenta la gestión y la base de cualquier conservación necesaria. Marcar como respondida no borra ni corrige registros automáticamente. Sigue los plazos legales y el procedimiento del manual.',
      ),
      DropdownButtonFormField<String>(
        initialValue: state,
        items: const [
          DropdownMenuItem(value: 'en_revision', child: Text('En revisión')),
          DropdownMenuItem(value: 'respondida', child: Text('Respondida')),
        ],
        onChanged: (v) => setState(() => state = v!),
      ),
      TextFormField(
        controller: answer,
        maxLength: 3000,
        maxLines: 7,
        validator: requiredText,
        decoration: const InputDecoration(
          labelText: 'Respuesta visible para el solicitante',
        ),
      ),
    ],
    save: () async {
      await AppScope.of(context).api.call(
        '/admin/privacy/requests/${widget.request['id']}',
        method: 'PUT',
        body: {'estado': state, 'respuesta': answer.text.trim()},
      );
    },
  );
}

class BusinessEditor extends StatefulWidget {
  const BusinessEditor({super.key, required this.business});
  final Json business;
  @override
  State<BusinessEditor> createState() => _BusinessEditorState();
}

class _BusinessEditorState extends State<BusinessEditor> {
  late final fields = {
    for (final k in [
      'nombre',
      'direccion',
      'municipio',
      'telefono',
      'correo',
      'responsable',
    ])
      k: TextEditingController(text: widget.business[k]?.toString()),
  };
  late final faqs = (widget.business['faq'] as List)
      .map(
        (q) => [
          TextEditingController(text: q['pregunta'].toString()),
          TextEditingController(text: q['respuesta'].toString()),
        ],
      )
      .toList();
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    for (final pair in faqs) {
      for (final c in pair) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Marca contacto y preguntas',
    fields: [
      const HintBox(
        'Estos datos son públicos. Cambiarlos genera una nueva versión de los documentos para futuras aceptaciones. No publiques datos personales sin autorización.',
      ),
      for (final e in fields.entries)
        AutoRentTextField(
          label: const {
            'nombre': 'Nombre comercial',
            'direccion': 'Dirección',
            'municipio': 'Municipio',
            'telefono': 'Teléfono',
            'correo': 'Correo de contacto opcional',
            'responsable': 'Responsable de datos opcional',
          }[e.key]!,
          controller: e.value,
          validator: ['correo', 'responsable'].contains(e.key)
              ? null
              : requiredText,
        ),
      Text(
        'Preguntas frecuentes',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      for (final pair in faqs)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  controller: pair[0],
                  maxLength: 160,
                  validator: requiredText,
                  decoration: const InputDecoration(labelText: 'Pregunta'),
                ),
                TextFormField(
                  controller: pair[1],
                  maxLength: 2000,
                  maxLines: 4,
                  validator: requiredText,
                  decoration: const InputDecoration(labelText: 'Respuesta'),
                ),
                TextButton(
                  onPressed: () => setState(() => faqs.remove(pair)),
                  child: const Text('Quitar pregunta'),
                ),
              ],
            ),
          ),
        ),
      if (faqs.length < 30)
        TextButton.icon(
          onPressed: () => setState(
            () => faqs.add([TextEditingController(), TextEditingController()]),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Agregar pregunta'),
        ),
    ],
    save: () async {
      await AppScope.of(context).api.call(
        '/admin/content',
        method: 'PUT',
        body: {
          for (final e in fields.entries)
            e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
          'faq': faqs
              .map(
                (p) => {
                  'pregunta': p[0].text.trim(),
                  'respuesta': p[1].text.trim(),
                },
              )
              .toList(),
        },
      );
    },
  );
}
