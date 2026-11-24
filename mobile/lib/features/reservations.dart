import 'dart:math';
import 'dart:async';

import 'payment.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/availability.dart';
import 'driver_license.dart';
import '../core/session.dart';
import '../core/theme/colors.dart';
import '../shared/widgets/autorent_button.dart';
import '../shared/widgets/autorent_text_field.dart';
import '../shared/widgets/screen.dart';
import 'access.dart';
import 'legal.dart';

const states = {
  'pendiente': 'Pendiente de validación',
  'lista_para_aprobar': 'Listo para aprobar',
  'denegada': 'Denegada',
  'denegada_automatica': 'Denegada automáticamente',
  'vencida': 'Vencida',
  'confirmada': 'Confirmada',
  'en_curso': 'En curso',
  'completada': 'Completada',
  'cancelada': 'Cancelada',
  'no_presentado': 'No presentado',
};
Widget reservationState(dynamic state) => Chip(
  label: Text(states[state] ?? state.toString()),
  side: BorderSide.none,
  backgroundColor:
      ([
                'cancelada',
                'no_presentado',
                'denegada',
                'denegada_automatica',
              ].contains(state)
              ? AppColors.error
              : state == 'en_curso'
              ? AppColors.gold
              : AppColors.success)
          .withValues(alpha: .18),
);

String validationPeriod(dynamic raw) {
  final minutes = (raw as num?)?.toInt() ?? 180;
  if (minutes % 60 != 0) return '$minutes minutos';
  final hours = minutes ~/ 60;
  return '$hours ${hours == 1 ? 'hora' : 'horas'}';
}

Future<DateTime?> pickMoment(
  BuildContext context,
  DateTime? initial, {
  bool Function(DateTime)? selectable,
}) async {
  final now = svNow(), first = svNow().subtract(const Duration(days: 1));
  var candidate = initial != null && initial.isAfter(first)
      ? initial
      : now.add(const Duration(days: 1));
  final last = now.add(const Duration(days: 730));
  while (selectable != null &&
      !selectable(candidate) &&
      candidate.isBefore(last)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  if (selectable != null && !selectable(candidate)) {
    tell(context, 'No hay fechas disponibles en este período.');
    return null;
  }
  final date = await showDatePicker(
    context: context,
    initialDate: candidate,
    selectableDayPredicate: selectable,
    firstDate: first,
    lastDate: now.add(const Duration(days: 730)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial ?? now),
  );
  return time == null
      ? null
      : DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class ReservePage extends StatefulWidget {
  const ReservePage({super.key, required this.vehicle});
  final Json vehicle;
  @override
  State<ReservePage> createState() => _ReservePageState();
}

class _ReservePageState extends State<ReservePage> {
  DateTime? start, end;
  int? pickup, dropoff;
  Json? quote;
  Json? acceptance;
  Json? driverDocument;
  bool busy = false;
  String? error;
  String? operationKey;
  Json get input => {
    'vehiculo_id': widget.vehicle['id'],
    'entrega_id': pickup,
    'devolucion_id': dropoff,
    'inicio': svInstant(start!).toIso8601String(),
    'fin': svInstant(end!).toIso8601String(),
  };
  void changed(VoidCallback fn) => setState(() {
    fn();
    quote = null;
    driverDocument = null;
    acceptance = null;
    operationKey = null;
    error = null;
  });
  Future<void> chooseDates() async {
    try {
      final data = await AppScope.of(context).api
          .call('/vehicles/${widget.vehicle['id']}/availability');
      if (!mounted) return;
      final periods = (data['periods'] as List).cast<Json>();
      final now = svNow();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 730)),
        helpText: 'Selecciona recogida y devolución',
        saveText: 'Elegir horas',
        selectableDayPredicate: (day, selectedStart, selectedEnd) =>
            !reservedDay(day, periods),
      );
      if (range == null || !mounted) return;
      for (
        var day = range.start;
        !day.isAfter(range.end);
        day = day.add(const Duration(days: 1))
      ) {
        if (reservedDay(day, periods)) {
          tell(
            context,
            'El rango incluye fechas reservadas. Elige otro período.',
          );
          return;
        }
      }
      final pickupTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(start ?? now),
      );
      if (pickupTime == null || !mounted) return;
      final returnTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(end ?? start ?? now),
      );
      if (returnTime == null || !mounted) return;
      changed(() {
        start = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
          pickupTime.hour,
          pickupTime.minute,
        );
        end = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          returnTime.hour,
          returnTime.minute,
        );
      });
    } catch (e) {
      if (mounted) tell(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
    return Scaffold(
      appBar: AppBar(title: const Text('Reserva tu viaje')),
      body: DataView(
        load: () => api.call('/locations'),
        builder: (data) {
          final locations = (data['locations'] as List).cast<Json>();
          return PageBody(
            children: [
              Text(
                vehicleName(widget.vehicle),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text(
                'Todas las horas corresponden a El Salvador (UTC−6). Se cobra cada bloque de 24 horas iniciado.',
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : chooseDates,
                icon: const Icon(Icons.date_range),
                label: Text(
                  start == null
                      ? 'Seleccionar fechas'
                      : 'Recogida: ${wallLabel(start)}\nDevolución: ${wallLabel(end)}',
                ),
              ),
              if (start != null && end != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Fechas seleccionadas: ${wallLabel(start)} — ${wallLabel(end)}',
                  ),
                ),
              for (final isPickup in [true, false])
                DropdownButtonFormField<int>(
                  initialValue: isPickup ? pickup : dropoff,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: isPickup
                        ? 'Punto de entrega'
                        : 'Punto de devolución',
                  ),
                  items: locations
                      .map(
                        (l) => DropdownMenuItem(
                          value: l['id'] as int,
                          child: Text(l['nombre'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (v) => changed(() {
                          if (isPickup) {
                            pickup = v;
                          } else {
                            dropoff = v;
                          }
                        }),
                ),
              if (locations.isEmpty)
                const HintBox(
                  'La empresa debe agregar sus puntos de entrega antes de aceptar reservas.',
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: AppColors.error)),
              AutoRentButton(
                label: 'Consultar total y disponibilidad',
                secondary: true,
                loading: busy && quote == null,
                onPressed: busy
                    ? null
                    : () async {
                        if (start == null ||
                            end == null ||
                            pickup == null ||
                            dropoff == null) {
                          tell(
                            context,
                            'Selecciona las fechas y ambos puntos.',
                          );
                          return;
                        }
                        if (!end!.isAfter(start!) ||
                            !svInstant(start!).isAfter(DateTime.now())) {
                          tell(
                            context,
                            'El inicio debe ser futuro y el fin posterior al inicio.',
                          );
                          return;
                        }
                        setState(() {
                          busy = true;
                          error = null;
                          quote = null;
                        });
                        try {
                          final q = await api.call(
                            '/reservations/quote',
                            method: 'POST',
                            body: input,
                          );
                          if (mounted) {
                            setState(() {
                              quote = q;
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              error = e.toString();
                            });
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              busy = false;
                            });
                          }
                        }
                      },
              ),
              if (quote != null) ...[
                HintBox(
                  '${quote!['dias_cobrados']} días × USD ${quote!['precio_dia']}\nTotal: USD ${quote!['total']}',
                ),
                HintBox(
                  'El administrador dispone de ${validationPeriod(quote!['minutos'])} para validar la solicitud.',
                ),
                const PaymentInfo(),
                DriverLicenseForm(
                  onSaved: (document) {
                    setState(() => driverDocument = document);
                  },
                ),
                LegalConsent(
                  onChanged: (value) {
                    acceptance = value;
                  },
                ),
                AutoRentButton(
                  label: 'Solicitar reserva · USD ${quote!['total']}',
                  loading: busy,
                  onPressed: busy
                      ? null
                      : () async {
                          if (driverDocument == null) {
                            tell(
                              context,
                              'Adjunta ambas caras de tu licencia de conducir antes de confirmar.',
                            );
                            return;
                          }
                          if (acceptance == null) {
                            tell(
                              context,
                              'Lee los documentos y confirma ambas casillas.',
                            );
                            return;
                          }
                          if (!await confirm(
                                context,
                                'Solicitar reserva',
                                'Total USD ${quote!['total']}. El plazo de validación es de ${validationPeriod(quote!['minutos'])}. Si vence, se liberan las fechas.',
                              ) ||
                              !context.mounted) {
                            return;
                          }
                          operationKey ??= List.generate(
                            24,
                            (_) => Random.secure()
                                .nextInt(256)
                                .toRadixString(16)
                                .padLeft(2, '0'),
                          ).join();
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            final data = await api.call(
                              '/reservations',
                              method: 'POST',
                              body: {
                                ...input,
                                'precio_confirmado': quote!['precio_dia'],
                                'aceptacion': acceptance,
                                'documento_id': driverDocument!['id'],
                              },
                              key: operationKey,
                            );
                            if (context.mounted) {
                              tell(
                                context,
                                'Consulta el estado de la solicitud en Mis reservas.',
                              );
                              await Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReservationDetail(
                                    id: data['reservation']['id'] as int,
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                error =
                                    '$e Si la conexión se interrumpió, reintenta esta misma operación o consulta Mis reservas antes de cambiar las fechas.';
                              });
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                busy = false;
                              });
                            }
                          }
                        },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key});
  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  int page = 1, revision = 0;
  String state = '', search = '';
  final searchInput = TextEditingController();
  @override
  void dispose() {
    searchInput.dispose();
    super.dispose();
  }

  void filter(String input) => setState(() {
    search = input.trim();
    page = 1;
  });
  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    if (session.user == null) {
      return PageBody(
        children: [
          const HintBox(
            'Ingresa a tu cuenta para consultar tus reservas y alquileres.',
          ),
          AutoRentButton(
            label: 'Ingresar',
            onPressed: () => requireLogin(context),
          ),
        ],
      );
    }
    return DataView(
      key: ValueKey((page, state, search, revision, session.user!['id'])),
      load: () => session.api.call(
        '/reservations',
        query: {
          'page': '$page',
          'limit': '20',
          if (state.isNotEmpty) 'estado': state,
          if (search.isNotEmpty) 'buscar': search,
        },
      ),
      builder: (data) {
        final rows = (data['reservations'] as List).cast<Json>();
        return PageBody(
          children: [
            Text(
              session.admin ? 'Reservas y alquileres' : 'Mis reservas',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            TextField(
              controller: searchInput,
              onSubmitted: filter,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: session.admin
                    ? 'Código o nombre del cliente'
                    : 'Código de reserva',
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.search),
                  onPressed: () => filter(searchInput.text),
                ),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: state,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Todos')),
                ...states.entries.map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                ),
              ],
              onChanged: (v) => setState(() {
                state = v ?? '';
                page = 1;
              }),
            ),
            if (rows.isEmpty)
              const HintBox('Todavía no hay reservas para mostrar.'),
            ...rows.map(
              (r) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    session.admin
                        ? value(r['cliente_nombre'])
                        : '${r['vehiculo_nombre']} · ${value(r['color'])}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    '${r['codigo']} · ${states[r['estado']]}\n${dateLabel(r['inicio_utc'])}\nUSD ${r['total']}${session.admin ? '\n${r['vehiculo_nombre']}' : ''}',
                  ),
                  trailing: reservationState(r['estado']),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReservationDetail(id: r['id'] as int),
                      ),
                    );
                    if (mounted) {
                      setState(() {
                        revision++;
                      });
                    }
                  },
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

class ReservationDetail extends StatefulWidget {
  const ReservationDetail({super.key, required this.id});
  final int id;
  @override
  State<ReservationDetail> createState() => _ReservationDetailState();
}

class _ReservationDetailState extends State<ReservationDetail> {
  final dataKey = GlobalKey<DataViewState>();
  bool busy = false;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !busy) dataKey.currentState?.reload();
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> validate() async {
    if (!await confirm(
          context,
          'Validar reserva',
          'Confirma que revisaste la licencia y los datos del pago.',
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await AppScope.of(context).api.call(
        '/admin/reservations/${widget.id}/validate',
        method: 'POST',
        body: {},
      );
    } catch (e) {
      if (mounted) tell(context, e);
    } finally {
      if (mounted) {
        setState(() => busy = false);
        dataKey.currentState?.reload();
      }
    }
  }

  Future<void> deny() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DenyReservationPage(id: widget.id)),
    );
    if (mounted) dataKey.currentState?.reload();
  }

  Future<void> cancel() async {
    if (!await confirm(
          context,
          'Cancelar reserva',
          'Se cancelará esta reserva sin cargo de cancelación.',
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      busy = true;
    });
    try {
      await AppScope.of(context).api
          .call('/reservations/${widget.id}/cancel', method: 'POST', body: {});
      dataKey.currentState?.reload();
    } catch (e) {
      if (mounted) tell(context, e);
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> operation(Json r, bool returning) async {
    final api = AppScope.of(context).api;
    final km = TextEditingController(), notes = TextEditingController();
    int? location;
    try {
      final places = returning
          ? (await api.call('/locations'))['locations'] as List
          : [];
      if (!mounted) return;
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => FormPage(
            title: returning ? 'Registrar devolución' : 'Entregar vehículo',
            fields: [
              HintBox(
                'Reserva ${r['codigo']}\n${r['vehiculo_nombre']}\n${r['cliente_nombre']}',
              ),
              if (!returning && r['documento'] != null)
                DriverLicenseReview(document: r['documento'] as Json),
              AutoRentTextField(
                label: 'Kilometraje ${returning ? 'de regreso' : 'de salida'}',
                controller: km,
                keyboardType: TextInputType.number,
                validator: requiredText,
              ),
              if (returning)
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación actual',
                  ),
                  items: places
                      .map(
                        (l) => DropdownMenuItem(
                          value: l['id'] as int,
                          child: Text(l['nombre'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    location = v;
                  },
                  validator: (v) =>
                      v == null ? 'Selecciona una ubicación.' : null,
                ),
              AutoRentTextField(
                label: 'Observaciones (opcional)',
                controller: notes,
                maxLines: 3,
              ),
            ],
            save: () async {
              final mileage = int.tryParse(km.text.trim());
              if (mileage == null || mileage < 0) {
                throw const ApiException(
                  'Escribe un kilometraje entero válido.',
                );
              }
              if (!returning && r['documento'] != null) {
                if (!await confirm(
                  context,
                  'Verificar licencia',
                  '¿Has revisado ambas caras de la licencia y confirmado que es válida?',
                )) {
                  throw const ApiException(
                    'Verifica la licencia antes de entregar el vehículo.',
                  );
                }
              }
              await api.call(
                '/admin/reservations/${widget.id}/${returning ? 'return' : 'checkout'}',
                method: 'POST',
                body: {
                  'kilometraje': mileage,
                  if (!returning) 'licencia_valida': true,
                  'observaciones': notes.text.trim().isEmpty
                      ? null
                      : notes.text.trim(),
                  if (returning) 'ubicacion_id': location,
                },
              );
            },
          ),
        ),
      );
      if (ok == true) dataKey.currentState?.reload();
    } catch (e) {
      if (mounted) tell(context, e);
    } finally {
      km.dispose();
      notes.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de reserva')),
      body: DataView(
        key: dataKey,
        load: () => session.api.call('/reservations/${widget.id}'),
        builder: (data) {
          final r = data['reservation'] as Json;
          final end = DateTime.parse(r['fin_utc'].toString());
          final late =
              r['estado'] == 'en_curso' && end.isBefore(DateTime.now());
          return PageBody(
            children: [
              Text(
                r['vehiculo_nombre'].toString(),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (session.admin)
                Text(
                  'Cliente: ${r['cliente_nombre']}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              SelectableText('Código ${r['codigo']}'),
              reservationState(r['estado']),
              if (r['review_note'] != null)
                HintBox(r['review_note'].toString()),
              if (r['vence_en'] != null)
                ReservationCountdown(
                  reservation: r,
                  onExpired: () => dataKey.currentState?.reload(),
                ),
              const PaymentInfo(),
              if (session.admin &&
                  [
                    'pendiente',
                    'lista_para_aprobar',
                    'denegada_automatica',
                  ].contains(r['estado'])) ...[
                AutoRentButton(
                  label: 'Completar reserva',
                  loading: busy,
                  onPressed: busy ? null : validate,
                ),
                AutoRentButton(
                  label: 'Denegar reserva',
                  secondary: true,
                  onPressed: busy ? null : deny,
                ),
              ],
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copiar código de reserva'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: r['codigo'].toString()),
                  );
                  if (context.mounted) tell(context, 'Código copiado.');
                },
              ),
              Text(
                'Días reservados',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              HintBox(
                '${states[r['estado']]}${late ? ' · Devolución atrasada' : ''}\nEntrega: ${dateLabel(r['inicio_utc'])}\n${r['entrega_nombre']}\nDevolución: ${dateLabel(r['fin_utc'])}\n${r['devolucion_nombre']}',
              ),
              Text(
                'USD ${r['total']}',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: AppColors.goldLight),
              ),
              Text(
                '${r['unidades_cobradas']} días × USD ${r['precio_dia_aplicado']} · Pago coordinado con la empresa',
              ),
              if (r['salida_real_utc'] != null)
                HintBox(
                  'Salida: ${dateLabel(r['salida_real_utc'])} · ${r['km_salida']} km\nRegreso: ${dateLabel(r['devolucion_real_utc'])} · ${value(r['km_regreso'])} km',
                ),
              if (r['motivo_cancelacion'] != null)
                Text('Motivo: ${r['motivo_cancelacion']}'),
              if ([
                    'pendiente',
                    'lista_para_aprobar',
                    'confirmada',
                  ].contains(r['estado']) &&
                  (session.admin ||
                      DateTime.parse(r['inicio_utc'].toString())
                          .isAfter(DateTime.now())))
                AutoRentButton(
                  label: 'Cancelar reserva',
                  secondary: true,
                  loading: busy,
                  onPressed: busy ? null : cancel,
                ),
              if (session.admin && r['estado'] == 'confirmada')
                AutoRentButton(
                  label: 'Registrar entrega',
                  onPressed: () => operation(r, false),
                ),
              if (session.admin && r['estado'] == 'en_curso')
                AutoRentButton(
                  label: 'Registrar devolución',
                  onPressed: () => operation(r, true),
                ),
              if (r['documento'] != null)
                DriverLicenseReview(document: r['documento'] as Json),
            ],
          );
        },
      ),
    );
  }
}

class DenyReservationPage extends StatefulWidget {
  const DenyReservationPage({required this.id, super.key});
  final int id;
  @override
  State<DenyReservationPage> createState() => _DenyReservationPageState();
}

class _DenyReservationPageState extends State<DenyReservationPage> {
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Denegar reserva',
    label: 'Confirmar denegación',
    fields: [
      Wrap(
        spacing: 8,
        children: [
          for (final text in [
            'Documento inválido',
            'Licencia vencida',
            'Foto borrosa',
          ])
            OutlinedButton(
              onPressed: () => reason.text = text,
              child: Text(text),
            ),
        ],
      ),
      AutoRentTextField(
        label: 'Motivo',
        controller: reason,
        maxLines: 3,
        validator: requiredText,
      ),
    ],
    save: () async {
      await AppScope.of(context).api.call(
        '/admin/reservations/${widget.id}/deny',
        method: 'POST',
        body: {'motivo': reason.text.trim()},
      );
    },
  );
}
