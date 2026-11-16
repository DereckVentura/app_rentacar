import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../shared/widgets/autorent_button.dart';
import '../shared/widgets/screen.dart';
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

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  int page = 1, version = 0;
  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
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
              Text('${data['unread']} avisos sin leer'),
              if (rows.isEmpty)
                const HintBox(
                  'Aquí verás las confirmaciones de tus reservas, entregas y devoluciones.',
                ),
              ...rows.map(
                (n) => Card(
                  child: ListTile(
                    leading: Icon(
                      n['leida_en'] == null
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
                    onPressed: rows.length == 20
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
