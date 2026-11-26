import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';
import 'android_push.dart';

class Session extends ChangeNotifier {
  Session(this.api) {
    api.onExpired = () {
      logout();
    };
  }
  final Api api;
  final _storage = const FlutterSecureStorage();
  Json? user;
  bool restoring = true;
  String? error;
  bool get admin => user?['rol'] == 'administrador';
  void updateUser(Json account) {
    if (user != null && user!['id'] == account['id']) {
      user = account;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    error = null;
    try {
      api.token = await _storage.read(key: 'autorent_token');
      if (api.token?.startsWith('offline-demo-') == true) {
        api.token = null;
        await _storage.delete(key: 'autorent_token');
      }
      if (api.token != null) {
        user = (await api.call('/auth/me'))['user'] as Json;
      }
    } catch (e) {
      error = e.toString();
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> access(Json result, {bool remember = false}) async {
    api.token = result['accessToken'] as String?;
    if (api.token == null) {
      throw const ApiException('El servidor no devolvió una sesión válida.');
    }
    try {
      if (remember) {
        await _storage.write(key: 'autorent_token', value: api.token);
      } else {
        await _storage.delete(key: 'autorent_token');
      }
    } catch (_) {
      api.token = null;
      throw const ApiException('No se pudo guardar la sesión de forma segura.');
    }
    user = result['user'] as Json;
    error = null;
    notifyListeners();
  }

  Future<void> logout() async {
    final sessionToken = api.token;
    final detached = sessionToken != null
        ? AndroidPush.instance
              .deactivate(api, sessionToken: sessionToken)
              .catchError((Object _) {})
        : Future<void>.value();
    api.token = null;
    user = null;
    try {
      await _storage.delete(key: 'autorent_token');
      await detached.timeout(const Duration(seconds: 2), onTimeout: () {});
    } finally {
      error = null;
      notifyListeners();
    }
  }
}

class AppScope extends InheritedNotifier<Session> {
  const AppScope({super.key, required Session session, required super.child})
    : super(notifier: session);
  static Session of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
