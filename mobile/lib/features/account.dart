import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/android_push.dart';
import '../core/session.dart';
import '../shared/widgets/autorent_button.dart';
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
          const Icon(Icons.account_circle_outlined, size: 72),
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
          AutoRentButton(
            label: 'Cerrar sesión',
            secondary: true,
            onPressed: () async {
              await s.logout();
            },
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
  late final phone = TextEditingController(
    text: widget.account['telefono'] as String?,
  );
  late final preferences = <String, bool>{
    for (final key in categories.keys)
      key: widget.account['avisos']?[key] != false,
  };
  bool busy = false;
  int photoRevision = 0;

  @override
  void dispose() {
    names.dispose();
    surname.dispose();
    phone.dispose();
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
      setState(() => photoRevision++);
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
            if (session.user?['foto'] != null)
              PrivateProfilePhoto(
                key: ValueKey(photoRevision),
                api: session.api,
              ),
            const Text('Foto de perfil'),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(
                          () => changePhoto(session, ImageSource.gallery),
                        ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galería'),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () =>
                            run(() => changePhoto(session, ImageSource.camera)),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Cámara'),
                ),
              ],
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
            TextFormField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Celular'),
              keyboardType: TextInputType.phone,
              maxLength: 25,
              validator: requiredText,
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
                          'telefono': phone.text.trim(),
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
  const PrivateProfilePhoto({super.key, required this.api});
  final Api api;
  @override
  State<PrivateProfilePhoto> createState() => _PrivateProfilePhotoState();
}

class _PrivateProfilePhotoState extends State<PrivateProfilePhoto> {
  late final photo = widget.api.image('/account/photo');
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: photo,
    builder: (_, snapshot) => snapshot.hasData
        ? Align(
            alignment: Alignment.centerLeft,
            child: ClipOval(
              child: Image.memory(
                snapshot.data!,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                semanticLabel: 'Foto de perfil',
              ),
            ),
          )
        : const Icon(Icons.account_circle_outlined, size: 72),
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
          validator: requiredText,
        ),
        TextFormField(
          controller: next,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Nueva contraseña'),
          validator: (value) =>
              (value?.length ?? 0) < 8 ? 'Usa al menos ocho caracteres.' : null,
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
  Future<void> configurePush(Session session, bool enable) async {
    final id = session.user?['id'];
    if (pushBusy || id is! int) return;
    setState(() => pushBusy = true);
    try {
      if (enable) {
        await AndroidPush.instance.activate(session.api, id);
      } else {
        await AndroidPush.instance.deactivate(session.api);
      }
      if (mounted) {
        tell(
          context,
          enable
              ? 'Avisos activados en Android.'
              : 'Avisos desactivados en Android.',
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
        key: ValueKey('$page$version'),
        load: () =>
            api.call('/notifications', query: {'page': '$page', 'limit': '20'}),
        builder: (data) {
          final rows = (data['notifications'] as List).cast<Json>();
          return PageBody(
            children: [
              if (AndroidPush.supported)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: pushBusy
                          ? null
                          : () => configurePush(session, true),
                      child: const Text('Activar avisos en Android'),
                    ),
                    TextButton(
                      onPressed: pushBusy
                          ? null
                          : () => configurePush(session, false),
                      child: const Text('Desactivar'),
                    ),
                  ],
                ),
              Text('${data['unread']} avisos sin leer'),
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
                    subtitle: Text(n['mensaje'].toString()),
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
