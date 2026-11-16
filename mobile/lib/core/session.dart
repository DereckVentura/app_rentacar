import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

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

  Future<void> access(Json result) async {
    api.token = result['accessToken'] as String?;
    if (api.token == null) {
      throw const ApiException('El servidor no devolvió una sesión válida.');
    }
    try {
      await _storage.write(key: 'autorent_token', value: api.token);
    } catch (_) {
      api.token = null;
      throw const ApiException('No se pudo guardar la sesión de forma segura.');
    }
    user = result['user'] as Json;
    error = null;
    notifyListeners();
  }

  Future<void> logout() async {
    api.token = null;
    user = null;
    try {
      await _storage.delete(key: 'autorent_token');
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
