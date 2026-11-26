import 'package:flutter/material.dart';

import '../core/api.dart';
import '../shared/widgets/screen.dart';

class ReservationFeedback extends StatefulWidget {
  const ReservationFeedback({
    super.key,
    required this.reservation,
    required this.admin,
    required this.api,
    required this.onSaved,
  });

  final Json reservation;
  final bool admin;
  final Api api;
  final VoidCallback onSaved;

  @override
  State<ReservationFeedback> createState() => _ReservationFeedbackState();
}

class _ReservationFeedbackState extends State<ReservationFeedback> {
  static const presets = [
    'Excelente servicio',
    'Entrega puntual',
    'Vehículo limpio y en buen estado',
    'La entrega podría mejorar',
  ];
  final comment = TextEditingController();
  bool open = false, busy = false;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> save({required bool skip}) async {
    setState(() => busy = true);
    try {
      await widget.api.call(
        '/reservations/${widget.reservation['id']}/review',
        method: 'POST',
        body: skip ? {'omitir': true} : {'comentario': comment.text.trim()},
      );
      if (mounted) widget.onSaved();
    } catch (error) {
      if (mounted) tell(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.reservation['review_status'];
    if (status == 'publicada') {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.rate_review_outlined),
          title: Text(widget.admin ? 'Reseña del cliente' : 'Tu reseña'),
          subtitle: Text('${widget.reservation['review_message']}'),
        ),
      );
    }
    if (widget.admin || status == 'omitida') return const SizedBox.shrink();
    if (!open) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => open = true),
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('Dejar una reseña'),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '¿Cómo estuvo tu alquiler?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : () => setState(() => open = false),
                  tooltip: 'Cerrar reseña',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final preset in presets)
                  ChoiceChip(
                    label: Text(preset),
                    selected: comment.text == preset,
                    onSelected: busy
                        ? null
                        : (selected) => setState(
                            () => comment.text = selected ? preset : '',
                          ),
                  ),
              ],
            ),
            TextField(
              controller: comment,
              enabled: !busy,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Comentario'),
            ),
            FilledButton(
              onPressed: busy || comment.text.trim().isEmpty
                  ? null
                  : () => save(skip: false),
              child: const Text('Enviar reseña'),
            ),
            TextButton(
              onPressed: busy ? null : () => save(skip: true),
              child: const Text('No dejar reseña'),
            ),
          ],
        ),
      ),
    );
  }
}
