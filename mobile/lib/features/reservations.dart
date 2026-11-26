import 'dart:math';
import 'dart:async';

import 'payment.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/availability.dart';
import 'driver_license.dart';
import '../core/session.dart';
import '../core/theme/colors.dart';
import '../shared/widgets/autorent_button.dart';
import '../shared/widgets/autorent_text_field.dart';
import '../shared/widgets/phone_field.dart';
import '../shared/widgets/screen.dart';
import 'access.dart';
import 'legal.dart';
import 'reservation_feedback.dart';

const states = {
  'pendiente': 'Pendiente de validación',
  'lista_para_aprobar': 'Listo para aprobar',
  'en_revision': 'En revisión',
  'denegada': 'Denegada',
  'denegada_automatica': 'Denegada automáticamente',
  'vencida': 'Vencida',
  'confirmada': 'Confirmada',
  'pagada': 'Pagada',
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
  final now = svNow(), first = DateUtils.dateOnly(svNow());
  final last = first.add(const Duration(days: 730));
  var candidate =
      initial != null && !initial.isBefore(first) && !initial.isAfter(last)
      ? initial
      : first;
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
    lastDate: last,
    currentDate: first,
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
      final today = DateUtils.dateOnly(now);
      final range = await showDateRangePicker(
        context: context,
        firstDate: today,
        lastDate: today.add(const Duration(days: 730)),
        currentDate: today,
        helpText: 'Selecciona recogida y devolución',
        saveText: 'Elegir horas',
        selectableDayPredicate: (day, selectedStart, selectedEnd) {
          if (!fullyReservedDay(day, periods)) return true;
          if (selectedStart == null ||
              selectedEnd != null ||
              !day.isAfter(selectedStart)) {
            return false;
          }
          final midnight = svInstant(day);
          return !reservedRange(
            midnight.subtract(const Duration(seconds: 1)),
            midnight,
            periods,
          );
        },
      );
      if (range == null || !mounted) return;
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
      final pickupDate = range.start.copyWith(
        hour: pickupTime.hour,
        minute: pickupTime.minute,
      );
      final returnDate = range.end.copyWith(
        hour: returnTime.hour,
        minute: returnTime.minute,
      );
      final from = svInstant(pickupDate), to = svInstant(returnDate);
      if (!from.isAfter(DateTime.now()) ||
          !to.isAfter(from) ||
          to.difference(from) > const Duration(days: 90)) {
        tell(
          context,
          'Elige una recogida futura y una devolución posterior, con un máximo de 90 días.',
        );
        return;
      }
      if (reservedRange(from, to, periods)) {
        tell(
          context,
          'El horario se cruza con otra reserva. Elige otras horas o fechas.',
        );
        return;
      }
      changed(() {
        start = pickupDate;
        end = returnDate;
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
                          final phone = await askReservationPhone(context, api);
                          if (!context.mounted || phone == null) return;
                          if (!await confirm(
                                context,
                                'Solicitar reserva',
                                'Total USD ${quote!['total']}. El plazo para depositar empieza cuando administración confirme.',
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
                                'celular': phone,
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
  bool history = false;
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
      key: ValueKey((
        page,
        state,
        search,
        history,
        revision,
        session.user!['id'],
      )),
      load: () => session.api.call(
        '/reservations',
        query: {
          'page': '$page',
          'limit': '20',
          if (history) 'vista': 'historial',
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
            FilterChip(
              label: const Text('Historial de confirmadas y pagadas'),
              selected: history,
              onSelected: (selected) => setState(() {
                history = selected;
                state = '';
                page = 1;
              }),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(history),
              initialValue: state,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Todos')),
                ...states.entries.map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                ),
              ],
              onChanged: history
                  ? null
                  : (v) => setState(() {
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

  Future<void> confirmReservation() async {
    if (!await confirm(
          context,
          'Confirmar reserva',
          'Confirma que revisaste la licencia. El plazo para depositar empieza al confirmar.',
        ) ||
        !mounted) {
      return;
    }
    await adminAction('validate', {'datos_verificados': true});
  }

  Future<void> adminAction(String action, [Json body = const {}]) async {
    setState(() => busy = true);
    try {
      await AppScope.of(context).api.call(
        '/admin/reservations/${widget.id}/$action',
        method: 'POST',
        body: body,
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

  String get receiptPath => '/reservations/${widget.id}/receipt';

  Future<void> removeReservation(Json reservation) async {
    final state = reservation['estado'];
    final consequence = state == 'pagada' ? ' Se liberarán las fechas.' : '';
    if (busy ||
        !await confirm(
          context,
          'Eliminar reserva',
          '¿Eliminar definitivamente la reserva ${reservation['codigo']}?$consequence',
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await AppScope.of(context).api.call(
        '/admin/reservations/${widget.id}',
        method: 'DELETE',
        body: {'estado': state},
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        tell(context, error);
        dataKey.currentState?.reload();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> attachReceipt() async {
    final api = AppScope.of(context).api;
    setState(() => busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.length < 3 ||
          bytes[0] != 255 ||
          bytes[1] != 216 ||
          bytes[2] != 255 ||
          bytes.length > 2000000) {
        throw const ApiException('Selecciona una imagen JPG de menos de 2 MB.');
      }
      await api.uploadPrivatePhoto(
        receiptPath,
        bytes,
        contentType: 'image/jpeg',
      );
      if (mounted) tell(context, 'Comprobante guardado.');
    } catch (e) {
      if (mounted) tell(context, e);
    } finally {
      if (mounted) {
        setState(() => busy = false);
        dataKey.currentState?.reload();
      }
    }
  }

  Future<void> viewReceipt() async {
    try {
      final bytes = await AppScope.of(context).api.image(receiptPath);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) =>
            Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
      );
    } catch (e) {
      if (mounted) tell(context, e);
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 9,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  reservationState(r['estado']),
                  if (session.admin &&
                      const {
                        'vencida',
                        'denegada',
                        'cancelada',
                        'pagada',
                      }.contains(r['estado']))
                    IconButton(
                      tooltip: 'Eliminar reserva',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy ? null : () => removeReservation(r),
                    ),
                ],
              ),
              if (r['review_note'] != null)
                HintBox(r['review_note'].toString()),
              if (r['estado'] == 'completada')
                ReservationFeedback(
                  key: ValueKey(r['review_status']),
                  reservation: r,
                  admin: session.admin,
                  api: session.api,
                  onSaved: () => dataKey.currentState?.reload(),
                ),
              if (r['vence_en'] != null)
                ReservationCountdown(
                  reservation: r,
                  onExpired: () => dataKey.currentState?.reload(),
                ),
              if (r['vence_en'] != null) const PaymentInfo(),
              if (!session.admin && r['vence_en'] != null)
                AutoRentButton(
                  label: r['receipt_submitted_at'] == null
                      ? 'Adjuntar comprobante JPG'
                      : 'Cambiar comprobante',
                  loading: busy,
                  onPressed: busy ? null : attachReceipt,
                ),
              if (r['receipt_submitted_at'] != null)
                OutlinedButton(
                  onPressed: busy ? null : viewReceipt,
                  child: const Text('Ver comprobante'),
                ),
              if (session.admin && r['vence_en'] != null)
                AutoRentButton(
                  label: 'Marcar depósito recibido',
                  loading: busy,
                  onPressed: busy
                      ? null
                      : () async {
                          if (await confirm(
                                context,
                                'Registrar depósito',
                                'Confirma que la empresa recibió el depósito.',
                              ) &&
                              mounted) {
                            await adminAction('paid');
                          }
                        },
                ),
              if (session.admin &&
                  [
                    'pendiente',
                    'en_revision',
                    'lista_para_aprobar',
                    'denegada_automatica',
                  ].contains(r['estado'])) ...[
                if (r['estado'] == 'pendiente')
                  OutlinedButton(
                    onPressed: busy ? null : () => adminAction('review'),
                    child: const Text('Marcar en revisión'),
                  ),
                AutoRentButton(
                  label: 'Confirmar reserva',
                  loading: busy,
                  onPressed: busy ? null : confirmReservation,
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
                    'en_revision',
                    'confirmada',
                    'pagada',
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
              if (session.admin &&
                  (r['estado'] == 'pagada' ||
                      (r['estado'] == 'confirmada' &&
                          r['confirmed_at'] == null)))
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

Future<String?> askReservationPhone(BuildContext context, Api api) async {
  String current = '';
  try {
    final response = await api.call('/auth/me');
    current = ((response['user'] as Json)['telefono'] ?? '').toString();
  } catch (_) {}
  if (!context.mounted) return null;
  String entered = current;
  final form = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('¿Sigues usando este número?'),
      scrollable: true,
      content: Form(
        key: form,
        child: PhoneField(
          initialValue: current,
          onChanged: (value) => entered = value,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState?.validate() == true) {
              Navigator.pop(dialog, validatedPhone(entered));
            }
          },
          child: const Text('Confirmar mi celular'),
        ),
      ],
    ),
  );
}
