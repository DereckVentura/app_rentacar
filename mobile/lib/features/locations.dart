import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme/colors.dart';
import '../shared/widgets/autorent_button.dart';
import '../shared/widgets/autorent_text_field.dart';
import '../shared/widgets/screen.dart';

class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key, this.admin = false});
  final bool admin;
  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
  final dataKey = GlobalKey<DataViewState>();
  void showLocation(Json location) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              location['nombre'].toString(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(location['direccion'].toString()),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir en el mapa externo'),
              onPressed: () => launchUrl(
                Uri.https('www.google.com', '/maps/search/', {
                  'api': '1',
                  'query': '${location['latitud']},${location['longitud']}',
                }),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> edit([Json? item]) async {
    final api = AppScope.of(context).api;
    final name = TextEditingController(text: item?['nombre']),
        address = TextEditingController(text: item?['direccion']),
        lat = TextEditingController(text: item?['latitud']?.toString()),
        lng = TextEditingController(text: item?['longitud']?.toString());
    String type = item?['tipo'] as String? ?? 'sucursal';
    bool active = item?['activo'] as bool? ?? true;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormPage(
          title: item == null ? 'Agregar ubicación' : 'Editar ubicación',
          fields: [
            AutoRentTextField(
              label: 'Nombre',
              controller: name,
              validator: requiredText,
            ),
            AutoRentTextField(
              label: 'Dirección',
              controller: address,
              validator: requiredText,
              maxLines: 2,
            ),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'sucursal', child: Text('Sucursal')),
                DropdownMenuItem(
                  value: 'punto_autorizado',
                  child: Text('Punto autorizado'),
                ),
              ],
              onChanged: (v) {
                type = v!;
              },
            ),
            AutoRentTextField(
              label: 'Latitud (ej. 13.48)',
              controller: lat,
              validator: requiredText,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            AutoRentTextField(
              label: 'Longitud (ej. -88.18)',
              controller: lng,
              validator: requiredText,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            StatefulBuilder(
              builder: (c, update) => SwitchListTile(
                title: const Text('Ubicación activa'),
                value: active,
                onChanged: (v) => update(() {
                  active = v;
                }),
              ),
            ),
          ],
          save: () async {
            await api.call(
              item == null
                  ? '/admin/locations'
                  : '/admin/locations/${item['id']}',
              method: item == null ? 'POST' : 'PUT',
              body: {
                'nombre': name.text.trim(),
                'tipo': type,
                'direccion': address.text.trim(),
                'latitud': lat.text.trim(),
                'longitud': lng.text.trim(),
                'activo': active,
              },
            );
          },
        ),
      ),
    );
    for (final c in [name, address, lat, lng]) {
      c.dispose();
    }
    if (ok == true) dataKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
    return DataView(
      key: dataKey,
      load: () => api.call(widget.admin ? '/admin/locations' : '/locations'),
      builder: (data) {
        final locations = (data['locations'] as List).cast<Json>();
        final active = locations.where((l) => l['activo'] == true).toList();
        return PageBody(
          children: [
            Text(
              widget.admin ? 'Administrar ubicaciones' : 'Encuéntranos',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            if (widget.admin)
              AutoRentButton(
                label: 'Agregar ubicación',
                icon: Icons.add,
                onPressed: () => edit(),
              ),
            if (active.isEmpty)
              const HintBox(
                'Pronto publicaremos nuestros puntos de entrega y devolución. No hay ubicaciones activas por ahora.',
              ),
            if (active.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 350,
                  child: FlutterMap(
                    key: ValueKey(active.toString()),
                    options: MapOptions(
                      initialCenter: LatLng(
                        double.parse(active.first['latitud'].toString()),
                        double.parse(active.first['longitud'].toString()),
                      ),
                      initialZoom: 12,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: const String.fromEnvironment(
                          'MAP_TILE_URL',
                          defaultValue:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        ),
                        userAgentPackageName: 'sv.autorent.autorent',
                      ),
                      MarkerLayer(
                        markers: active
                            .map(
                              (l) => Marker(
                                point: LatLng(
                                  double.parse(l['latitud'].toString()),
                                  double.parse(l['longitud'].toString()),
                                ),
                                width: 48,
                                height: 48,
                                child: Tooltip(
                                  message: l['nombre'].toString(),
                                  child: GestureDetector(
                                    onTap: () => showLocation(l),
                                    child: const Icon(
                                      Icons.location_on,
                                      size: 44,
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      SimpleAttributionWidget(
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                          mode: LaunchMode.externalApplication,
                        ),
                        source: const Text(
                          '© OpenStreetMap contributors · openstreetmap.org/copyright',
                          style: TextStyle(color: Colors.black, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ...locations.map(
              (l) => Card(
                child: ListTile(
                  title: Text(l['nombre'].toString()),
                  subtitle: Text(
                    '${l['direccion']}\n${l['tipo'] == 'sucursal' ? 'Sucursal' : 'Punto autorizado'}${l['activo'] == true ? '' : ' · Inactiva'}',
                  ),
                  trailing: widget.admin
                      ? const Icon(Icons.edit_outlined)
                      : null,
                  onTap: widget.admin ? () => edit(l) : () => showLocation(l),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
