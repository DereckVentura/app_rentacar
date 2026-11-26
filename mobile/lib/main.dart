import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/api.dart';
import 'core/native_push.dart';
import 'core/session.dart';
import 'core/theme/app_theme.dart';
import 'features/account.dart';
import 'features/admin.dart';
import 'features/catalog.dart';
import 'features/locations.dart';
import 'features/reservations.dart';
import 'features/legal.dart';
import 'shared/widgets/brand.dart';
import 'shared/widgets/autorent_button.dart';
import 'shared/widgets/screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const AutoRentApp());
}

class AutoRentApp extends StatefulWidget {
  const AutoRentApp({super.key});
  @override
  State<AutoRentApp> createState() => _AutoRentAppState();
}

class _AutoRentAppState extends State<AutoRentApp> {
  final session = Session(Api());
  @override
  void initState() {
    super.initState();
    session.restore();
  }

  @override
  void dispose() {
    session.api.dispose();
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    session: session,
    child: MaterialApp(
      title: 'Rent a Car Molina · AutoRent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('es', 'SV'),
      supportedLocales: const [Locale('es', 'SV')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AutoRentShell(),
    ),
  );
}

class AutoRentShell extends StatefulWidget {
  const AutoRentShell({super.key});
  @override
  State<AutoRentShell> createState() => _AutoRentShellState();
}

class _AutoRentShellState extends State<AutoRentShell>
    with WidgetsBindingObserver {
  int index = 0;
  int unread = 0;
  int? lastNotice, lastUser;
  bool polling = false, foreground = true;
  Timer? timer;
  StreamSubscription<RemoteMessage>? notificationTap;
  StreamSubscription<RemoteMessage>? foregroundNotification;
  void openNotifications(RemoteMessage message) {
    if (!mounted ||
        AppScope.of(context).user == null ||
        message.data['screen'] != 'notifications') {
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsPage()))
        .then((_) => poll());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 60), (_) => poll());
    if (NativePush.supported) {
      notificationTap = FirebaseMessaging.onMessageOpenedApp.listen(
        openNotifications,
      );
      foregroundNotification = FirebaseMessaging.onMessage.listen(
        (_) => poll(),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AppScope.of(context).user?['id'] as int?;
    if (id != lastUser) {
      if (lastUser == null && index == 3) index = 0;
      lastUser = id;
      lastNotice = null;
      unread = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        poll();
        if (mounted && id != null && NativePush.supported) {
          NativePush.instance
              .restore(AppScope.of(context).api, id)
              .then((message) {
                if (message != null) openNotifications(message);
              })
              .catchError((Object _) {});
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) poll();
  }

  @override
  void dispose() {
    timer?.cancel();
    notificationTap?.cancel();
    foregroundNotification?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> poll() async {
    if (!mounted || polling || !foreground) return;
    final session = AppScope.of(context);
    if (session.user == null) return;
    final userId = session.user!['id'];
    polling = true;
    try {
      final data = await session.api.call(
        '/notifications',
        query: {'page': '1', 'limit': '1'},
      );
      if (!mounted || session.user?['id'] != userId) return;
      final rows = data['notifications'] as List;
      final newest = rows.isEmpty ? null : rows.first['id'] as int;
      if (lastNotice != null && newest != null && newest > lastNotice!) {
        tell(context, rows.first['titulo']);
      }
      setState(() {
        unread = data['unread'] as int;
        lastNotice = newest;
      });
    } catch (_) {
    } finally {
      polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (s.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (s.error != null && s.api.token != null) {
      return Scaffold(
        body: PageBody(
          children: [
            HintBox(s.error!),
            AutoRentButton(
              label: 'Reintentar conexión',
              onPressed: () => s.restore(),
            ),
            AutoRentButton(
              label: 'Continuar como visitante',
              secondary: true,
              onPressed: () async {
                await s.logout();
              },
            ),
          ],
        ),
      );
    }
    final items = [
      const NavigationDestination(
        icon: Icon(Icons.directions_car_outlined),
        label: 'Flota',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        label: 'Reservas',
      ),
      const NavigationDestination(
        icon: Icon(Icons.map_outlined),
        label: 'Mapa',
      ),
      if (s.user == null)
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Cuenta',
        ),
      if (s.admin)
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Admin',
        ),
    ];
    final selected = index < items.length ? index : 0;
    return Scaffold(
      appBar: AppBar(
        title: const MolinaBrand(),
        actions: [
          IconButton(
            tooltip: 'Ayuda y condiciones',
            onPressed: () => openHelp(context),
            icon: const Icon(Icons.help_outline),
          ),
          if (s.user != null)
            IconButton(
              tooltip: unread > 0
                  ? 'Notificaciones, $unread sin leer'
                  : 'Notificaciones',
              onPressed: () async {
                await showNoticePreview(context, s.api);
                await poll();
              },
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          if (s.user case final user?)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 12),
              child: MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.manage_accounts_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Mi cuenta')),
                          body: const AccountPage(),
                        ),
                      ),
                    ),
                    child: const Text('Mi cuenta'),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.logout),
                    onPressed: () async {
                      await s.logout();
                      if (mounted) setState(() => index = 0);
                    },
                    child: const Text('Cerrar sesión'),
                  ),
                ],
                builder: (context, controller, child) => IconButton(
                  tooltip: 'Abrir perfil',
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                  icon: PrivateProfilePhoto(
                    key: ValueKey('${user['id']}:${user['foto']}'),
                    api: s.api,
                    hasPhoto: user['foto'] != null,
                    size: 30,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: [
              const CatalogPage(),
              const ReservationsPage(),
              const LocationsPage(),
              if (s.user == null) const AccountPage(),
              if (s.admin) const AdminPage(),
            ][selected],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (v) => setState(() {
          index = v;
        }),
        destinations: items,
      ),
    );
  }
}
