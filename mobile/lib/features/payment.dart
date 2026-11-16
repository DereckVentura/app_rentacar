import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme/colors.dart';
import '../shared/widgets/autorent_text_field.dart';
import '../shared/widgets/screen.dart';

class PaymentInfo extends StatelessWidget {
  const PaymentInfo({super.key});
  @override
  Widget build(BuildContext context) => DataView(
    inline: true,
    load: () => AppScope.of(context).api.call('/payment-details'),
    builder: (data) {
      final p = data['payment'] as Json?;
      return HintBox(
        p == null
            ? 'La empresa todavía no ha agregado sus datos de pago.'
            : 'Datos para el pago\nBanco: ${p['banco']}\nTitular: ${p['titular']}\nTipo: ${p['tipo_cuenta']}\nCuenta: ${p['numero_cuenta']}\n${p['instrucciones'] ?? ''}',
      );
    },
  );
}

class PaymentEditor extends StatelessWidget {
  const PaymentEditor({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Datos de pago')),
    body: DataView(
      load: () => AppScope.of(context).api.call('/payment-details'),
      builder: (data) => _PaymentForm(payment: data['payment'] as Json? ?? {}),
    ),
  );
}

class _PaymentForm extends StatefulWidget {
  const _PaymentForm({required this.payment});
  final Json payment;
  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  static const labels = {
    'banco': 'Banco',
    'titular': 'Titular de la cuenta',
    'numero_cuenta': 'Número de cuenta',
    'tipo_cuenta': 'Tipo de cuenta',
    'instrucciones': 'Instrucciones de pago',
  };
  late final controls = {
    for (final key in labels.keys)
      key: TextEditingController(text: widget.payment[key]?.toString() ?? ''),
  };
  @override
  void dispose() {
    for (final c in controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'Cuenta bancaria de la empresa',
    fields: [
      const HintBox(
        'Estos datos se mostrarán a los clientes para coordinar el pago de su reserva.',
      ),
      for (final e in labels.entries)
        AutoRentTextField(
          label: e.value,
          controller: controls[e.key],
          validator: e.key == 'instrucciones' ? null : requiredText,
          maxLines: e.key == 'instrucciones' ? 3 : 1,
        ),
    ],
    save: () async {
      await AppScope.of(context).api.call(
        '/admin/payment-details',
        method: 'PUT',
        body: {for (final e in controls.entries) e.key: e.value.text.trim()},
      );
    },
  );
}

class ReservationCountdown extends StatefulWidget {
  const ReservationCountdown({
    super.key,
    required this.reservation,
    required this.onExpired,
  });
  final Json reservation;
  final VoidCallback onExpired;
  @override
  State<ReservationCountdown> createState() => _ReservationCountdownState();
}

class _ReservationCountdownState extends State<ReservationCountdown> {
  Timer? timer;
  final clock = Stopwatch();
  late Duration initial;
  bool notified = false;
  void reset() {
    initial = DateTime.parse(
      widget.reservation['vence_en'].toString(),
    ).difference(DateTime.parse(widget.reservation['servidor_utc'].toString()));
    clock.reset();
    clock.start();
    notified = false;
  }

  @override
  void initState() {
    super.initState();
    reset();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if ((initial - clock.elapsed).inMilliseconds <= 0 && !notified) {
        notified = true;
        widget.onExpired();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ReservationCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reservation['servidor_utc'] !=
        widget.reservation['servidor_utc']) {
      reset();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (initial - clock.elapsed).inSeconds.clamp(0, 10800);
    String digits(int n) => n.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tiempo para validar la reserva'),
          Text(
            '${digits(seconds ~/ 3600)}:${digits(seconds ~/ 60 % 60)}:${digits(seconds % 60)}',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: AppColors.gold),
          ),
          Text(
            seconds > 0
                ? 'La administración tiene 3 horas para validar. Al vencer, se liberan las fechas.'
                : 'Plazo vencido. Actualizando…',
          ),
        ],
      ),
    );
  }
}
