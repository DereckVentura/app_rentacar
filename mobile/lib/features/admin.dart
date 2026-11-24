import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../shared/widgets/autorent_button.dart';
import '../shared/widgets/autorent_text_field.dart';
import '../shared/widgets/screen.dart';
import 'locations.dart';
import 'payment.dart';
import 'legal.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int page = 1, version = 0;
  Future<void> edit([Json? vehicle]) async {
    final api = AppScope.of(context).api;
    try {
      final result = await Future.wait([
        api.call('/catalogs'),
        api.call('/admin/locations'),
      ]);
      if (!mounted) return;
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => VehicleEditor(
            vehicle: vehicle,
            catalogs: result[0],
            locations: (result[1]['locations'] as List).cast<Json>(),
          ),
        ),
      );
      if (ok == true && mounted) {
        setState(() {
          version++;
        });
      }
    } catch (e) {
      if (mounted) tell(context, e);
    }
  }

  Future<void> editDeadline() async {
    final api = AppScope.of(context).api;
    TextEditingController? deadline;
    try {
      final settings = await api.call('/reservation-settings');
      if (!mounted) return;
      final input = TextEditingController(text: settings['minutos'].toString());
      deadline = input;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => FormPage(
            title: 'Plazo para validar',
            fields: [
              AutoRentTextField(
                label: 'Minutos para validar una reserva',
                controller: input,
                keyboardType: TextInputType.number,
                validator: requiredText,
              ),
            ],
            save: () async {
              final minutes = int.tryParse(input.text.trim());
              if (minutes == null || minutes < 1 || minutes > 1440) {
                throw const ApiException('Escribe entre 1 y 1440 minutos.');
              }
              await api.call(
                '/admin/reservation-settings',
                method: 'PUT',
                body: {'minutos': minutes},
              );
            },
          ),
        ),
      );
    } catch (error) {
      if (mounted) tell(context, error);
    } finally {
      deadline?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    if (!session.admin) {
      return const PageBody(
        children: [HintBox('Esta sección requiere una cuenta administradora.')],
      );
    }
    return DataView(
      key: ValueKey('$page$version'),
      load: () => session.api.call(
        '/admin/vehicles',
        query: {'page': '$page', 'limit': '20'},
      ),
      builder: (data) {
        final rows = (data['vehicles'] as List).cast<Json>();
        return PageBody(
          children: [
            Text(
              'Tu flota, a tu manera',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const Text(
              'Completa los datos, cambia las fotos y agrega nuevos vehículos cuando tu negocio crezca.',
            ),
            AutoRentButton(
              label: 'Agregar vehículo',
              icon: Icons.add,
              onPressed: () => edit(),
            ),
            AutoRentButton(
              label: 'Modificar puntos de entrega',
              icon: Icons.location_on_outlined,
              secondary: true,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Ubicaciones')),
                    body: const LocationsPage(admin: true),
                  ),
                ),
              ),
            ),
            AutoRentButton(
              label: 'Datos de pago y cuenta bancaria',
              secondary: true,
              icon: Icons.account_balance_outlined,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentEditor()),
              ),
            ),
            AutoRentButton(
              label: 'Plazo para validar reservas',
              icon: Icons.timer_outlined,
              secondary: true,
              onPressed: editDeadline,
            ),
            if (rows.isEmpty)
              const HintBox(
                'Todavía no hay vehículos. Agrega tu primera unidad.',
              ),
            AutoRentButton(
              label: 'Marca contacto y preguntas frecuentes',
              secondary: true,
              icon: Icons.business_outlined,
              onPressed: () async {
                try {
                  final content = await session.api.call('/content');
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BusinessEditor(business: content['business'] as Json),
                    ),
                  );
                } catch (e) {
                  if (context.mounted) tell(context, e);
                }
              },
            ),
            AutoRentButton(
              label: 'Solicitudes de datos y reclamos',
              secondary: true,
              icon: Icons.privacy_tip_outlined,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPage()),
              ),
            ),
            ...rows.map(
              (v) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    '${vehicleName(v)} · ${value(facts(v)['color'])}',
                  ),
                  subtitle: Text(
                    '${v['anio']} · ${v['estado_operativo']}\n${v['publicado'] == true ? 'Publicado' : 'Oculto'} · ${v['precio_dia'] == null ? 'Tarifa pendiente' : 'USD ${v['precio_dia']} / día'}',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => edit(v),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: page > 1
                      ? () => setState(() {
                          page--;
                        })
                      : null,
                  child: const Text('Anterior'),
                ),
                Text('Página $page'),
                TextButton(
                  onPressed: page < (data['pagination']['totalPages'] as int)
                      ? () => setState(() {
                          page++;
                        })
                      : null,
                  child: const Text('Siguiente'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class VehicleEditor extends StatefulWidget {
  const VehicleEditor({
    super.key,
    this.vehicle,
    required this.catalogs,
    required this.locations,
  });
  final Json? vehicle;
  final Json catalogs;
  final List<Json> locations;
  @override
  State<VehicleEditor> createState() => _VehicleEditorState();
}

class _VehicleEditorState extends State<VehicleEditor> {
  final controls = <String, TextEditingController>{};
  late Json f;
  late List<Json> photos, references;
  int? category, location;
  String state = 'inactivo';
  bool published = false, verified = false, uploading = false;
  String? traction, transmission, fuel;
  @override
  void initState() {
    super.initState();
    final v = widget.vehicle ?? {};
    f = {...facts(v)};
    for (final key in [
      'marca',
      'modelo',
      'anio',
      'placa',
      'kilometraje',
      'precio_dia',
      'descripcion',
    ]) {
      controls[key] = TextEditingController(text: v[key]?.toString());
    }
    for (final key in [
      'color',
      'version',
      'plazas',
      'motor_litros',
      'potencia_hp',
      'observaciones',
    ]) {
      controls[key] = TextEditingController(text: f[key]?.toString());
    }
    category = v['categoria_id'] as int?;
    location = v['ubicacion_actual_id'] as int?;
    state = v['estado_operativo'] == 'disponible'
        ? 'operativo'
        : v['estado_operativo'] as String? ?? 'inactivo';
    published = v['publicado'] as bool? ?? false;
    verified = f['anio_verificado'] as bool? ?? false;
    traction = f['traccion'] as String?;
    transmission = f['transmision'] as String?;
    fuel = f['combustible'] as String?;
    photos = (f['fotos'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    references = (f['referencias'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  void dispose() {
    for (final c in controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String key,
    String label, {
    bool required = false,
    bool number = false,
    int lines = 1,
  }) => AutoRentTextField(
    label: label,
    controller: controls[key],
    validator: required ? requiredText : null,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : null,
    maxLines: lines,
  );
  Widget select(
    String label,
    String? current,
    Map<String, String> options,
    ValueChanged<String?> change,
  ) => DropdownButtonFormField<String>(
    initialValue: options.containsKey(current) ? current : '',
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: '', child: Text('Por confirmar')),
      ...options.entries.map(
        (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
      ),
    ],
    onChanged: (v) {
      change(v == '' ? null : v);
    },
  );
  Future<void> addPhoto({
    ImageSource source = ImageSource.gallery,
    int? replaceIndex,
  }) async {
    if (photos.length >= 12 && replaceIndex == null) {
      tell(context, 'Se permiten hasta 12 fotos.');
      return;
    }
    final api = AppScope.of(context).api;
    setState(() {
      uploading = true;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 78,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        throw const ApiException('La imagen debe pesar menos de 10 MB.');
      }
      void savePhoto(String url) {
        if (!mounted) return;
        setState(() {
          final item = <String, dynamic>{
            'url': url,
            'alt': '${controls['marca']!.text} ${controls['modelo']!.text}',
          };
          if (replaceIndex == null) {
            photos.add(item);
          } else if (replaceIndex < photos.length) {
            photos[replaceIndex] = item;
          }
        });
      }

      try {
        savePhoto(await api.uploadFleetPhoto(bytes));
        return;
      } on ApiException catch (error) {
        if (error.status != 404) rethrow;
      }
      final signature = await api.call(
        '/admin/media/signature',
        method: 'POST',
        body: {},
      );
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse(
                'https://api.cloudinary.com/v1_1/${signature['cloudName']}/image/upload',
              ),
            )
            ..fields.addAll({
              'timestamp': '${signature['timestamp']}',
              'folder': '${signature['folder']}',
              'api_key': '${signature['apiKey']}',
              'signature': '${signature['signature']}',
            })
            ..files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: file.name),
            );
      final response = await request.send().timeout(
        const Duration(seconds: 90),
      );
      final result = jsonDecode(
        await response.stream.bytesToString().timeout(
          const Duration(seconds: 90),
        ),
      ) as Json;
      if (response.statusCode >= 400 || result['secure_url'] == null) {
        throw const ApiException(
          'No se pudo subir la imagen. Intenta de nuevo.',
        );
      }
      savePhoto(result['secure_url'] as String);
    } catch (e) {
      if (mounted) tell(context, e);
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
        });
      }
    }
  }

  Future<void> reference([int? index]) async {
    final existing = index == null ? <String, dynamic>{} : references[index];
    final map = {
      for (final k in ['titulo', 'url', 'mercado', 'resumen'])
        k: TextEditingController(text: existing[k]?.toString()),
    };
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormPage(
          title: 'Referencia técnica',
          fields: [
            for (final e in {
              'titulo': 'Título',
              'url': 'Enlace HTTPS',
              'mercado': 'Mercado de referencia',
              'resumen': 'Resumen y limitaciones',
            }.entries)
              AutoRentTextField(
                label: e.value,
                controller: map[e.key],
                validator: requiredText,
                maxLines: e.key == 'resumen' ? 3 : 1,
              ),
          ],
          save: () async {
            final uri = Uri.tryParse(map['url']!.text.trim());
            if (uri == null || uri.scheme != 'https') {
              throw const ApiException('Usa un enlace HTTPS válido.');
            }
            final entry = {
              for (final e in map.entries) e.key: e.value.text.trim(),
            };
            if (index == null) {
              references.add(entry);
            } else {
              references[index] = entry;
            }
          },
        ),
      ),
    );
    for (final c in map.values) {
      c.dispose();
    }
    if (ok == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
    return FormPage(
      title: widget.vehicle == null ? 'Agregar vehículo' : 'Editar vehículo',
      fields: [
        const HintBox(
          'Puedes dejar datos pendientes. Para reservar se necesitan placa, kilometraje, tarifa y ubicación activa. Verifica la ficha antes de publicarla.',
        ),
        field('marca', 'Marca', required: true),
        field('modelo', 'Modelo', required: true),
        field('anio', 'Año informado', required: true, number: true),
        DropdownButtonFormField<int>(
          initialValue: category,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Categoría'),
          items: (widget.catalogs['categorias'] as List)
              .map(
                (c) => DropdownMenuItem(
                  value: c['id'] as int,
                  child: Text(c['nombre'].toString()),
                ),
              )
              .toList(),
          onChanged: (v) {
            category = v;
          },
          validator: (v) => v == null ? 'Selecciona una categoría.' : null,
        ),
        field('placa', 'Placa (pendiente si se deja vacío)'),
        field('kilometraje', 'Kilometraje actual', number: true),
        field('precio_dia', 'Tarifa diaria USD', number: true),
        DropdownButtonFormField<int>(
          initialValue: location ?? 0,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ubicación actual'),
          items: [
            const DropdownMenuItem(value: 0, child: Text('Por confirmar')),
            ...widget.locations.map(
              (l) => DropdownMenuItem(
                value: l['id'] as int,
                child: Text(
                  '${l['nombre']}${l['activo'] == true ? '' : ' · Inactiva'}',
                ),
              ),
            ),
          ],
          onChanged: (v) {
            location = v == 0 ? null : v;
          },
        ),
        select(
          'Estado operativo',
          state,
          {
            'operativo': 'Operativo',
            'mantenimiento': 'Mantenimiento',
            'inactivo': 'Inactivo',
          },
          (v) {
            state = v ?? 'inactivo';
          },
        ),
        SwitchListTile(
          title: const Text('Mostrar en el catálogo'),
          value: published,
          onChanged: (v) => setState(() {
            published = v;
          }),
        ),
        field('descripcion', 'Descripción', lines: 3),
        Text(
          'Ficha del vehículo',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        field('color', 'Color'),
        field('version', 'Versión / equipamiento confirmado'),
        select(
          'Tracción',
          traction,
          {'FWD': '4×2 · Delantera', 'AWD': 'AWD · Integral', '4WD': '4×4'},
          (v) {
            traction = v;
          },
        ),
        field('plazas', 'Asientos', number: true),
        field('motor_litros', 'Cilindrada (litros)', number: true),
        field('potencia_hp', 'Potencia (hp)', number: true),
        select(
          'Transmisión',
          transmission,
          {'CVT': 'CVT', 'automatica': 'Automática', 'manual': 'Manual'},
          (v) {
            transmission = v;
          },
        ),
        select(
          'Combustible',
          fuel,
          {
            'gasolina': 'Gasolina',
            'diesel': 'Diésel',
            'hibrido': 'Híbrido',
            'electrico': 'Eléctrico',
          },
          (v) {
            fuel = v;
          },
        ),
        SwitchListTile(
          title: const Text('Año comprobado con documentación'),
          value: verified,
          onChanged: (v) => setState(() {
            verified = v;
          }),
        ),
        field('observaciones', 'Observaciones de la ficha', lines: 3),
        Text(
          'Fotos · la primera será la portada',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final (index, p) in photos.indexed)
          Card(
            child: ListTile(
              leading: SizedBox(
                width: 64,
                child: Image.network(
                  api.media(p['url'])!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
              title: Text('Foto ${index + 1}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    tooltip: 'Opciones de foto',
                    enabled: !uploading,
                    onSelected: (action) {
                      if (action == 'replace') {
                        addPhoto(replaceIndex: index);
                      } else {
                        setState(
                          () => photos.insert(
                            action == 'up' ? index - 1 : index + 1,
                            photos.removeAt(index),
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'replace',
                        child: Text('Reemplazar foto'),
                      ),
                      if (index > 0)
                        const PopupMenuItem(
                          value: 'up',
                          child: Text('Subir en la lista'),
                        ),
                      if (index < photos.length - 1)
                        const PopupMenuItem(
                          value: 'down',
                          child: Text('Bajar en la lista'),
                        ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Usar de portada',
                    onPressed: index == 0 || uploading
                        ? null
                        : () => setState(() {
                            photos.insert(0, photos.removeAt(index));
                          }),
                    icon: const Icon(Icons.star_outline),
                  ),
                  IconButton(
                    tooltip: 'Quitar foto de la ficha',
                    onPressed: uploading
                        ? null
                        : () => setState(() {
                            photos.removeAt(index);
                          }),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        AutoRentButton(
          label: 'Agregar foto de la galería',
          secondary: true,
          loading: uploading,
          onPressed: uploading ? null : () => addPhoto(),
        ),
        AutoRentButton(
          label: 'Tomar foto con la cámara',
          secondary: true,
          onPressed: uploading
              ? null
              : () => addPhoto(source: ImageSource.camera),
        ),
        for (final (index, r) in references.indexed)
          ListTile(
            title: Text(r['titulo'].toString()),
            onTap: () => reference(index),
            trailing: IconButton(
              tooltip: 'Quitar referencia',
              onPressed: () => setState(() {
                references.removeAt(index);
              }),
              icon: const Icon(Icons.close),
            ),
          ),
        if (references.length < 5)
          TextButton(
            onPressed: () => reference(),
            child: const Text('Agregar referencia técnica'),
          ),
        if (widget.vehicle != null)
          TextButton(
            onPressed: uploading
                ? null
                : () async {
                    if (!await confirm(
                          context,
                          'Eliminar vehículo',
                          'Si hay reservas activas, el vehículo seguirá en la flota.',
                        ) ||
                        !context.mounted) {
                      return;
                    }
                    try {
                      await api.call(
                        '/admin/vehicles/${widget.vehicle!['id']}',
                        method: 'DELETE',
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (error) {
                      if (context.mounted) tell(context, error);
                    }
                  },
            child: const Text('Eliminar vehículo'),
          ),
      ],
      save: () async {
        if (uploading) {
          throw const ApiException('Espera a que termine de subir la foto.');
        }
        String? text(String key) => controls[key]!.text.trim().isEmpty
            ? null
            : controls[key]!.text.trim();
        int? number(String key) {
          final raw = text(key);
          if (raw == null) return null;
          final n = int.tryParse(raw);
          if (n == null || n < 0) throw ApiException('Revisa el campo $key.');
          return n;
        }

        final body = <String, dynamic>{
          'marca': text('marca'),
          'modelo': text('modelo'),
          'anio': number('anio'),
          'categoria_id': category,
          'placa': text('placa'),
          'kilometraje': number('kilometraje'),
          'precio_dia': text('precio_dia'),
          'ubicacion_actual_id': location,
          'estado_operativo': state,
          'publicado': published,
          'descripcion': text('descripcion'),
          'ficha': {
            'color': text('color'),
            'version': text('version'),
            'traccion': traction,
            'plazas': number('plazas'),
            'motor_litros': text('motor_litros'),
            'potencia_hp': number('potencia_hp'),
            'transmision': transmission,
            'combustible': fuel,
            'anio_verificado': verified,
            'observaciones': text('observaciones'),
            'fotos': photos,
            'referencias': references,
          },
        };
        await api.call(
          widget.vehicle == null
              ? '/admin/vehicles'
              : '/admin/vehicles/${widget.vehicle!['id']}',
          method: widget.vehicle == null ? 'POST' : 'PATCH',
          body: body,
        );
      },
    );
  }
}
