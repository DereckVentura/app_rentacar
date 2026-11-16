import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/theme/colors.dart';
import 'autorent_button.dart';

String dateLabel(dynamic raw) {
  if (raw == null) return '—';
  final date = DateTime.tryParse(raw.toString());
  return date == null
      ? raw.toString()
      : DateFormat('dd/MM/yyyy · HH:mm')
            .format(date.toUtc().subtract(const Duration(hours: 6)));
}

DateTime svNow() => DateTime.now().toUtc().subtract(const Duration(hours: 6));
DateTime svInstant(DateTime wall) => DateTime.utc(
  wall.year,
  wall.month,
  wall.day,
  wall.hour,
  wall.minute,
).add(const Duration(hours: 6));
DateTime? svWall(String? iso) {
  final d = DateTime.tryParse(iso ?? '')
      ?.toUtc()
      .subtract(const Duration(hours: 6));
  return d == null ? null : DateTime(d.year, d.month, d.day, d.hour, d.minute);
}

String wallLabel(DateTime? d) =>
    d == null ? '—' : DateFormat('dd/MM/yyyy · HH:mm').format(d);
void tell(BuildContext context, Object message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message.toString())));
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: children
            .expand((w) => [w, const SizedBox(height: 16)])
            .toList(),
      ),
    ),
  );
}

class HintBox extends StatelessWidget {
  const HintBox(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text),
  );
}

class DataView extends StatefulWidget {
  const DataView({
    super.key,
    required this.load,
    required this.builder,
    this.inline = false,
  });
  final bool inline;
  final Future<Json> Function() load;
  final Widget Function(Json) builder;
  @override
  State<DataView> createState() => DataViewState();
}

class DataViewState extends State<DataView> {
  late Future<Json> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  void reload() {
    if (mounted) {
      setState(() {
        future = widget.load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: future,
    builder: (c, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (snap.hasError) {
        if (widget.inline) {
          return Column(
            children: [
              HintBox(snap.error.toString()),
              TextButton(
                onPressed: reload,
                child: const Text('Intentar de nuevo'),
              ),
            ],
          );
        }
        return PageBody(
          children: [
            HintBox(snap.error.toString()),
            AutoRentButton(label: 'Intentar de nuevo', onPressed: reload),
          ],
        );
      }
      if (widget.inline) return widget.builder(snap.data ?? {});
      return RefreshIndicator(
        onRefresh: () async {
          reload();
          try {
            await future;
          } catch (_) {}
        },
        child: widget.builder(snap.data ?? {}),
      );
    },
  );
}

class FormPage extends StatefulWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.fields,
    required this.save,
    this.label = 'Guardar cambios',
  });
  final String title, label;
  final List<Widget> fields;
  final Future<void> Function() save;
  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Form(
      key: form,
      child: PageBody(
        children: [
          ...widget.fields,
          if (error != null)
            Text(error!, style: const TextStyle(color: AppColors.error)),
          AutoRentButton(
            label: widget.label,
            loading: busy,
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              setState(() {
                busy = true;
                error = null;
              });
              try {
                await widget.save();
                if (context.mounted) Navigator.pop(context, true);
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
        ],
      ),
    ),
  );
}

String? requiredText(String? v) =>
    v == null || v.trim().isEmpty ? 'Completa este campo.' : null;
String? positiveNumber(String? v) => v == null || v.isEmpty
    ? null
    : (double.tryParse(v) == null || double.parse(v) <= 0
          ? 'Escribe un número mayor que cero.'
          : null);
