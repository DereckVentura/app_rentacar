import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme/colors.dart';
import '../shared/widgets/autorent_button.dart';
import '../shared/widgets/autorent_text_field.dart';
import '../shared/widgets/vehicle_card.dart';
import '../shared/widgets/screen.dart';
import 'access.dart';
import 'reservations.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  int page = 1;
  Map<String, String> filters = {};
  Future<void> filter() async {
    final api = AppScope.of(context).api;
    try {
      final catalogs = await api.call('/catalogs');
      if (!mounted) return;
      final result = await Navigator.push<Map<String, String>>(
        context,
        MaterialPageRoute(
          builder: (_) => CatalogFilters(catalogs: catalogs, initial: filters),
        ),
      );
      if (result != null) {
        setState(() {
          filters = result;
          page = 1;
        });
      }
    } catch (e) {
      if (mounted) tell(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
    return DataView(
      key: ValueKey('$page$filters'),
      load: () => api.call(
        '/vehicles',
        query: {...filters, 'page': '$page', 'limit': '12'},
      ),
      builder: (data) {
        final vehicles = (data['vehicles'] as List).cast<Json>();
        final pages = data['pagination']['totalPages'] as int;
        return PageBody(
          children: [
            Text(
              'Elige tu próximo viaje',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const Text(
              'Conoce nuestra flota y encuentra el vehículo para tu camino.',
            ),
            Row(
              children: [
                Expanded(
                  child: Text('${data['pagination']['total']} vehículos'),
                ),
                if (filters.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      filters = {};
                      page = 1;
                    }),
                    child: const Text('Limpiar'),
                  ),
                OutlinedButton.icon(
                  onPressed: filter,
                  icon: const Icon(Icons.tune),
                  label: Text(
                    filters.isEmpty ? 'Filtros' : 'Filtros (${filters.length})',
                  ),
                ),
              ],
            ),
            if (vehicles.isEmpty)
              const HintBox(
                'No hay vehículos con estos filtros. Puedes cambiar las fechas o quitar filtros.',
              ),
            LayoutBuilder(
              builder: (c, size) {
                final count = size.maxWidth >= 700 ? 2 : 1;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: vehicles
                      .map(
                        (v) => SizedBox(
                          width: (size.maxWidth - (count - 1) * 16) / count,
                          child: VehicleCard(
                            title: vehicleName(v),
                            subtitle:
                                '${v['anio']} · ${value(facts(v)['color'])} · ${value(facts(v)['traccion'])}',
                            price: v['precio_dia'] as String?,
                            imageUrl: api.media(v['imagen_url']),
                            status: v['reservable'] == true
                                ? (v['disponible'] == true
                                      ? 'Disponible en tus fechas'
                                      : 'Consulta disponibilidad')
                                : 'Disponible para consultar · datos por completar',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VehicleDetail(id: v['id'] as int),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
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
                Text('$page / ${pages == 0 ? 1 : pages}'),
                TextButton(
                  onPressed: page < pages
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

class CatalogFilters extends StatefulWidget {
  const CatalogFilters({
    super.key,
    required this.catalogs,
    required this.initial,
  });
  final Json catalogs;
  final Map<String, String> initial;
  @override
  State<CatalogFilters> createState() => _CatalogFiltersState();
}

class _CatalogFiltersState extends State<CatalogFilters> {
  late final Map<String, String> fields = {...widget.initial};
  late final min = TextEditingController(text: fields['precio_min']),
      max = TextEditingController(text: fields['precio_max']);
  late final kmMin = TextEditingController(text: fields['kilometraje_min']),
      kmMax = TextEditingController(text: fields['kilometraje_max']);
  DateTime? start, end;
  @override
  void initState() {
    super.initState();
    start = svWall(fields['inicio']);
    end = svWall(fields['fin']);
  }

  @override
  void dispose() {
    for (final c in [min, max, kmMin, kmMax]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Encuentra tu vehículo')),
    body: PageBody(
      children: [
        for (final entry in {
          'categoria_id': 'categorias',
          'marca_id': 'marcas',
          'modelo_id': 'modelos',
        }.entries)
          DropdownButtonFormField<String>(
            initialValue: fields[entry.key],
            isExpanded: true,
            decoration: InputDecoration(
              labelText: {
                'categoria_id': 'Categoría',
                'marca_id': 'Marca',
                'modelo_id': 'Modelo',
              }[entry.key],
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Todos')),
              ...(widget.catalogs[entry.value] as List)
                  .where(
                    (e) =>
                        entry.key != 'modelo_id' ||
                        fields['marca_id'] == null ||
                        fields['marca_id'] == '' ||
                        '${e['marca_id']}' == fields['marca_id'],
                  )
                  .map(
                    (e) => DropdownMenuItem(
                      value: '${e['id']}',
                      child: Text(e['nombre'].toString()),
                    ),
                  ),
            ],
            onChanged: (v) => setState(() {
              if (v == null || v.isEmpty) {
                fields.remove(entry.key);
              } else {
                fields[entry.key] = v;
              }
              if (entry.key == 'marca_id') fields.remove('modelo_id');
            }),
            key: ValueKey('${entry.key}${fields['marca_id']}'),
          ),
        AutoRentTextField(
          label: 'Tarifa mínima USD (opcional)',
          controller: min,
          keyboardType: TextInputType.number,
        ),
        AutoRentTextField(
          label: 'Tarifa máxima USD (opcional)',
          controller: max,
          keyboardType: TextInputType.number,
        ),
        AutoRentTextField(
          label: 'Kilometraje mínimo (opcional)',
          controller: kmMin,
          keyboardType: TextInputType.number,
        ),
        AutoRentTextField(
          label: 'Kilometraje máximo (opcional)',
          controller: kmMax,
          keyboardType: TextInputType.number,
        ),
        const Text('Todas las horas corresponden a El Salvador (UTC−6).'),
        OutlinedButton(
          onPressed: () async {
            final d = await pickMoment(context, start);
            if (d != null) {
              setState(() {
                start = d;
              });
            }
          },
          child: Text('Inicio: ${wallLabel(start)}'),
        ),
        OutlinedButton(
          onPressed: () async {
            final d = await pickMoment(
              context,
              end ?? start?.add(const Duration(days: 1)),
            );
            if (d != null) {
              setState(() {
                end = d;
              });
            }
          },
          child: Text('Fin: ${wallLabel(end)}'),
        ),
        AutoRentButton(
          label: 'Aplicar filtros',
          onPressed: () {
            for (final e in {
              'precio_min': min.text,
              'precio_max': max.text,
              'kilometraje_min': kmMin.text,
              'kilometraje_max': kmMax.text,
            }.entries) {
              if (e.value.trim().isEmpty) {
                fields.remove(e.key);
              } else {
                fields[e.key] = e.value.trim();
              }
            }
            if (start != null && end != null) {
              fields['inicio'] = svInstant(start!).toIso8601String();
              fields['fin'] = svInstant(end!).toIso8601String();
            } else if (start != null || end != null) {
              tell(context, 'Selecciona inicio y fin.');
              return;
            }
            Navigator.pop(context, fields);
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, <String, String>{}),
          child: const Text('Quitar todos los filtros'),
        ),
      ],
    ),
  );
}

class VehicleDetail extends StatefulWidget {
  const VehicleDetail({super.key, required this.id});
  final int id;
  @override
  State<VehicleDetail> createState() => _VehicleDetailState();
}

class _VehicleDetailState extends State<VehicleDetail> {
  int photoIndex = 0;
  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
    return Scaffold(
      appBar: AppBar(title: const Text('Tu vehículo')),
      body: DataView(
        load: () => api.call('/vehicles/${widget.id}'),
        builder: (data) {
          final v = data['vehicle'] as Json, f = facts(data['vehicle'] as Json);
          final photos = f['fotos'] as List? ?? [];
          return PageBody(
            children: [
              Text(
                vehicleName(v),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              Text(
                '${v['anio']} · ${value(f['color'])}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (photos.isNotEmpty)
                SizedBox(
                  height: 300,
                  child: PageView(
                    onPageChanged: (index) => setState(() {
                      photoIndex = index;
                    }),
                    children: photos
                        .map(
                          (p) => ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              api.media(p['url'])!,
                              fit: BoxFit.contain,
                              semanticLabel: p['alt'].toString(),
                              errorBuilder: (_, _, _) =>
                                  localVehicleAsset(p['url']?.toString()) !=
                                      null
                                  ? Image.asset(
                                      localVehicleAsset(p['url']?.toString())!,
                                      fit: BoxFit.contain,
                                    )
                                  : const HintBox('No se pudo cargar la foto.'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (photos.length > 1)
                Text(
                  '${photoIndex + 1} / ${photos.length} · Desliza para ver todas las fotos.',
                  textAlign: TextAlign.center,
                ),
              Text(
                v['precio_dia'] == null
                    ? 'Tarifa por confirmar'
                    : '\$${v['precio_dia']} USD / día',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: AppColors.goldLight),
              ),
              if (v['reservable'] != true)
                const HintBox(
                  'La empresa está completando los datos de esta unidad. Las reservas se habilitarán cuando estén listos.',
                ),
              if (v['descripcion'] != null) Text(v['descripcion'].toString()),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final e in {
                        'Versión': f['version'],
                        'Tracción': f['traccion'],
                        'Asientos': f['plazas'],
                        'Motor (L)': f['motor_litros'],
                        'Potencia (hp)': f['potencia_hp'],
                        'Transmisión': f['transmision'],
                        'Combustible': f['combustible'],
                        'Kilometraje': v['kilometraje'],
                      }.entries)
                        Row(
                          children: [
                            Expanded(child: Text(e.key)),
                            Expanded(
                              child: Text(
                                value(e.value),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Text(
                f['anio_verificado'] == true
                    ? 'Año verificado por la empresa.'
                    : 'Año informado por el propietario; verificación pendiente.',
              ),
              if (f['observaciones'] != null)
                HintBox(f['observaciones'].toString()),
              if (v['ubicacion'] != null)
                HintBox(
                  'Ubicación: ${v['ubicacion']['nombre']}\n${v['ubicacion']['direccion']}',
                ),
              AutoRentButton(
                label: 'Elegir fechas y reservar',
                onPressed: v['reservable'] == true
                    ? () async {
                        if (!await requireLogin(context) || !context.mounted) {
                          return;
                        }
                        if (AppScope.of(context).admin) {
                          tell(
                            context,
                            'Usa una cuenta cliente para reservar.',
                          );
                          return;
                        }
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReservePage(vehicle: v),
                          ),
                        );
                      }
                    : null,
              ),
              if ((f['referencias'] as List? ?? []).isNotEmpty)
                ExpansionTile(
                  title: const Text('Referencias técnicas del fabricante'),
                  children: (f['referencias'] as List)
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r['titulo'].toString()),
                              Text(r['resumen'].toString()),
                              TextButton(
                                onPressed: () => launchUrl(
                                  Uri.parse(r['url'].toString()),
                                  mode: LaunchMode.externalApplication,
                                ),
                                child: const Text(
                                  'Abrir referencia del fabricante',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}
