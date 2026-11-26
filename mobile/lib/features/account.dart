import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/native_push.dart';
import '../core/session.dart';
import '../core/validation.dart';
import '../shared/widgets/autorent_button.dart';
import '../shared/widgets/phone_field.dart';
import '../shared/widgets/screen.dart';
import '../shared/widgets/photo_crop.dart';
import 'access.dart';
import 'reservations.dart';
import 'legal.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context), u = AppScope.of(context).user;
    return PageBody(
      children: [
        Text('Tu cuenta', style: Theme.of(context).textTheme.headlineLarge),
        if (u == null) ...[
          const HintBox(
            'Crea tu cuenta para reservar, consultar tu historial y recibir confirmaciones.',
          ),
          AutoRentButton(
            label: 'Ingresar o crear cuenta',
            onPressed: () => requireLogin(context),
          ),
        ] else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: PrivateProfilePhoto(
              key: ValueKey('${u['id']}:${u['foto']}'),
              api: s.api,
              hasPhoto: u['foto'] != null,
              size: 76,
            ),
          ),
          Text(
            '${u['nombres']} ${u['apellidos']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(u['email'].toString()),
          Text(value(u['telefono'])),
          Text(s.admin ? 'Administración' : 'Cliente'),
          AutoRentButton(
            label: 'Editar mi cuenta',
            icon: Icons.manage_accounts_outlined,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AccountEditor(account: u)),
            ),
          ),
          AutoRentButton(
            label: 'Mis avisos',
            icon: Icons.notifications_outlined,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
          ),
        ],
        AutoRentButton(
          label: 'Ayuda preguntas y condiciones',
          secondary: true,
          icon: Icons.help_outline,
          onPressed: () => openHelp(context),
        ),
        if (u != null)
          AutoRentButton(
            label: 'Privacidad y mis datos',
            secondary: true,
            icon: Icons.privacy_tip_outlined,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPage()),
            ),
          ),
        const HintBox(accountNotice),
      ],
    );
  }
}

class AccountEditor extends StatefulWidget {
  const AccountEditor({super.key, required this.account});
  final Json account;
  @override
  State<AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<AccountEditor> {
  static const categories = {
    'reserva': 'Reservas',
    'deposito': 'Depósitos',
    'recordatorio': 'Recordatorios',
    'chatbot': 'Chatbot',
  };
  final form = GlobalKey<FormState>();
  late final names = TextEditingController(
    text: widget.account['nombres'] as String?,
  );
  late final surname = TextEditingController(
    text: widget.account['apellidos'] as String?,
  );
  late String phone = widget.account['telefono'] as String? ?? '';
  late final preferences = <String, bool>{
    for (final key in categories.keys)
      key: widget.account['avisos']?[key] != false,
  };
  bool busy = false;

  @override
  void dispose() {
    names.dispose();
    surname.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
    } catch (error) {
      if (mounted) tell(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changePhoto(Session session, ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 95,
    );
    if (file == null) return;
    final original = await file.readAsBytes();
    if (!mounted) return;
    final cropped = await cropPhoto(context, original, width: 512, height: 512);
    if (!mounted || cropped == null) return;
    final result = await session.api.uploadPrivatePhoto(
      '/account/photo',
      cropped,
    );
    session.updateUser(result['user'] as Json);
    if (mounted) {
      tell(context, 'Foto guardada.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: Form(
        key: form,
        child: PageBody(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Foto de perfil',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    PrivateProfilePhoto(
                      key: ValueKey(session.user?['foto']),
                      api: session.api,
                      hasPhoto: session.user?['foto'] != null,
                      size: 70,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => run(
                                  () =>
                                      changePhoto(session, ImageSource.gallery),
                                ),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Importar de galería'),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => run(
                                  () =>
                                      changePhoto(session, ImageSource.camera),
                                ),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Usar cámara'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            TextFormField(
              controller: names,
              decoration: const InputDecoration(labelText: 'Nombres'),
              maxLength: 100,
              validator: requiredText,
            ),
            TextFormField(
              controller: surname,
              decoration: const InputDecoration(labelText: 'Apellidos'),
              maxLength: 100,
              validator: requiredText,
            ),
            PhoneField(
              initialValue: phone,
              onChanged: (value) => phone = value,
            ),
            ExpansionTile(
              title: const Text('Preferencias de avisos'),
              children: [
                for (final category in categories.entries)
                  SwitchListTile(
                    title: Text(category.value),
                    value: preferences[category.key]!,
                    onChanged: busy
                        ? null
                        : (value) =>
                              setState(() => preferences[category.key] = value),
                  ),
              ],
            ),
            AutoRentButton(
              label: 'Guardar cambios',
              loading: busy,
              onPressed: busy
                  ? null
                  : () => run(() async {
                      if (form.currentState?.validate() != true) return;
                      final result = await session.api.call(
                        '/account',
                        method: 'PATCH',
                        body: {
                          'nombres': names.text.trim(),
                          'apellidos': surname.text.trim(),
                          'telefono': validatedPhone(phone),
                          'avisos': preferences,
                        },
                      );
                      session.updateUser(result['user'] as Json);
                      if (context.mounted) tell(context, 'Cuenta guardada.');
                    }),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage(),
                      ),
                    ),
              child: const Text('Cambiar contraseña'),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivateProfilePhoto extends StatefulWidget {
  const PrivateProfilePhoto({
    super.key,
    required this.api,
    required this.hasPhoto,
    this.size = 96,
  });
  final Api api;
  final bool hasPhoto;
  final double size;
  @override
  State<PrivateProfilePhoto> createState() => _PrivateProfilePhotoState();
}

class _PrivateProfilePhotoState extends State<PrivateProfilePhoto> {
  late final photo = widget.hasPhoto
      ? widget.api.image('/account/photo')
      : null;
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: photo,
    builder: (_, snapshot) => CircleAvatar(
      radius: widget.size / 2,
      foregroundImage: snapshot.hasData ? MemoryImage(snapshot.data!) : null,
      child: Icon(Icons.person_outline, size: widget.size * .52),
    ),
  );
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final current = TextEditingController(), next = TextEditingController();
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return FormPage(
      title: 'Cambiar contraseña',
      label: 'Guardar contraseña',
      fields: [
        TextFormField(
          controller: current,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Contraseña actual'),
          validator: passwordError,
        ),
        TextFormField(
          controller: next,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Nueva contraseña'),
          validator: (value) => passwordError(value, creating: true),
        ),
      ],
      save: () async {
        await session.api.call(
          '/account/password',
          method: 'POST',
          body: {'actual': current.text, 'nueva': next.text},
        );
        await session.logout();
      },
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  int page = 1, version = 0;
  bool pushBusy = false;
  int? accountId;
  bool pushActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AppScope.of(context).user?['id'] as int?;
    if (id == accountId) return;
    accountId = id;
    pushActive = false;
    if (id != null && NativePush.supported) {
      NativePush.instance
          .isActive(id)
          .then((active) {
            if (mounted && accountId == id) setState(() => pushActive = active);
          })
          .catchError((Object _) {});
    }
  }

  Future<void> configurePush(Session session, bool enable) async {
    final id = session.user?['id'];
    if (pushBusy || id is! int) return;
    setState(() => pushBusy = true);
    try {
      if (enable) {
        await NativePush.instance.activate(session.api, id);
      } else {
        await NativePush.instance.deactivate(session.api);
      }
      if (mounted) {
        setState(() => pushActive = enable);
        tell(
          context,
          enable
              ? 'Avisos activados en este dispositivo.'
              : 'Avisos desactivados en este dispositivo.',
        );
      }
    } catch (error) {
      if (mounted) tell(context, error);
    } finally {
      if (mounted) setState(() => pushBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context), api = session.api;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis avisos')),
      body: DataView(
        key: ValueKey((page, version)),
        load: () =>
            api.call('/notifications', query: {'page': '$page', 'limit': '20'}),
        builder: (data) {
          final rows = (data['notifications'] as List).cast<Json>();
          return PageBody(
            children: [
              if (NativePush.supported)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Avisos del dispositivo'),
                    subtitle: const Text(
                      'Recibe novedades aunque AutoRent esté cerrado.',
                    ),
                    trailing: pushBusy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch(
                            value: pushActive,
                            onChanged: (enabled) =>
                                configurePush(session, enabled),
                          ),
                  ),
                ),
              Row(
                children: [
                  Expanded(child: Text('${data['unread']} sin leer')),
                  TextButton(
                    onPressed: data['unread'] == 0
                        ? null
                        : () async {
                            try {
                              await api.call(
                                '/notifications/read',
                                method: 'POST',
                                body: {},
                              );
                              if (mounted) setState(() => version++);
                            } catch (error) {
                              if (context.mounted) tell(context, error);
                            }
                          },
                    child: const Text('Marcar todas como leídas'),
                  ),
                ],
              ),
              if (rows.isEmpty)
                const HintBox(
                  'Aquí verás las confirmaciones de tus reservas, entregas y devoluciones.',
                ),
              ...rows.map(
                (n) => Card(
                  child: ListTile(
                    leading: Icon(
                      (n['read_at'] ?? n['leida_en']) == null
                          ? Icons.notifications_active_outlined
                          : Icons.done,
                    ),
                    title: Text(n['titulo'].toString()),
                    subtitle: Text(
                      '${n['mensaje']}\n${dateLabel(n['creado_en'])}',
                    ),
                    onTap: () async {
                      try {
                        await api.call(
                          '/notifications/${n['id']}/read',
                          method: 'POST',
                          body: {},
                        );
                        if (!context.mounted) return;
                        if (n['reserva_id'] != null) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReservationDetail(id: n['reserva_id'] as int),
                            ),
                          );
                        }
                        if (mounted) {
                          setState(() {
                            version++;
                          });
                        }
                      } catch (e) {
                        if (context.mounted) tell(context, e);
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
                    onPressed:
                        page <
                            ((data['pagination'] as Json?)?['totalPages'] ?? 1)
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
      ),
    );
  }
}

Future<void> showNoticePreview(BuildContext context, Api api) async {
  final selected = await showModalBottomSheet<Json>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .55,
    ),
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notificaciones',
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Cerrar notificaciones',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(sheet),
              ),
            ],
          ),
          Flexible(
            child: DataView(
              load: () => api.call('/notifications', query: {'limit': '3'}),
              builder: (data) {
                final rows = (data['notifications'] as List).cast<Json>();
                if (rows.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Todavía no tienes avisos.'),
                  );
                }
                return ListView(
                  shrinkWrap: true,
                  children: [
                    for (final row in rows)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          row['read_at'] == null
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_none,
                        ),
                        title: Text('${row['titulo']}'),
                        subtitle: Text(
                          '${row['mensaje']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(sheet, row),
                      ),
                  ],
                );
              },
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(sheet, {'expand': true}),
            icon: const Icon(Icons.open_in_full, size: 16),
            label: const Text('Ver todas las notificaciones'),
          ),
        ],
      ),
    ),
  );
  if (selected == null || !context.mounted) return;
  if (selected['expand'] == true) {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
    return;
  }
  try {
    await api.call(
      '/notifications/${selected['id']}/read',
      method: 'POST',
      body: {},
    );
    if (context.mounted && selected['reserva_id'] is int) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReservationDetail(id: selected['reserva_id'] as int),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) tell(context, error);
  }
}
