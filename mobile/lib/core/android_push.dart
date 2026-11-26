// The server sends to FCM registration tokens. The newer APIs return installation IDs.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

class AndroidPush {
  static const _storage = FlutterSecureStorage();
  static const _ownerKey = 'autorent_android_push_owner';
  static const _tokenKey = 'autorent_android_push_token';
  static final instance = AndroidPush._();
  AndroidPush._();
  StreamSubscription<String>? _refresh;
  Future<void>? _initializing;
  Future<void> _pending = Future<void>.value();

  Future<T> _ordered<T>(Future<T> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _initialize(Api api) async {
    if (Firebase.apps.isNotEmpty) return;
    final result = await api.call('/notifications/android-config');
    final config = result['config'] as Json?;
    if (config == null) {
      throw const ApiException('Los avisos Android aún no están configurados.');
    }
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config['apiKey'] as String,
        appId: config['appId'] as String,
        messagingSenderId: config['messagingSenderId'] as String,
        projectId: config['projectId'] as String,
      ),
    );
  }

  Future<void> _ready(Api api) async {
    _initializing ??= _initialize(api);
    try {
      await _initializing;
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _register(Api api, String token, String session) async {
    final previous = await _storage.read(key: _tokenKey);
    await api.call(
      '/notifications/android',
      method: 'POST',
      body: {'token': token},
      sessionToken: session,
    );
    await _storage.write(key: _tokenKey, value: token);
    if (previous != null && previous != token) {
      await api.call(
        '/notifications/android',
        method: 'DELETE',
        body: {'token': previous},
        sessionToken: session,
      );
    }
  }

  Future<void> activate(Api api, int userId) async {
    final session = api.token;
    if (!supported || session == null) return;
    await _ordered(() => _activate(api, userId, session));
  }

  Future<void> _activate(Api api, int userId, String session) async {
    await _ready(api);
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus != AuthorizationStatus.authorized) {
      throw const ApiException('Android no concedió permiso para los avisos.');
    }
    final token = await messaging.getToken();
    if (token == null) {
      throw const ApiException('Android no devolvió un registro de avisos.');
    }
    if (api.token != session) {
      throw const ApiException(
        'La sesión cambió. Vuelve a activar los avisos.',
      );
    }
    await _register(api, token, session);
    await _storage.write(key: _ownerKey, value: '$userId');
    await _listen(api, session);
  }

  Future<void> _listen(Api api, String session) async {
    await _refresh?.cancel();
    _refresh = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      try {
        await _ordered(() async {
          if (api.token == session) await _register(api, token, session);
        });
      } catch (_) {
        // Restore will retry on the next launch with the same account.
      }
    });
  }

  Future<RemoteMessage?> restore(Api api, int userId) async {
    final session = api.token;
    if (!supported || session == null) return null;
    return _ordered(() => _restore(api, userId, session));
  }

  Future<RemoteMessage?> _restore(Api api, int userId, String session) async {
    if (api.token != session) return null;
    if (await _storage.read(key: _ownerKey) != '$userId') return null;
    await _ready(api);
    if (api.token != session) return null;
    await _listen(api, session);
    final messaging = FirebaseMessaging.instance;
    final message = await messaging.getInitialMessage();
    try {
      final token = await messaging.getToken();
      if (token != null && api.token == session) {
        await _register(api, token, session);
      }
    } catch (_) {
      // A temporary registration failure need not prevent opening the inbox.
    }
    return api.token == session ? message : null;
  }

  Future<void> deactivate(Api api, {String? sessionToken}) async {
    if (!supported) return;
    final session = sessionToken ?? api.token;
    await _ordered(() => _deactivate(api, session));
  }

  Future<void> _deactivate(Api api, String? session) async {
    await _refresh?.cancel();
    _refresh = null;
    final token = await _storage.read(key: _tokenKey);
    try {
      if (token != null && session != null) {
        await api.call(
          '/notifications/android',
          method: 'DELETE',
          body: {'token': token},
          sessionToken: session,
          responseTimeout: const Duration(seconds: 2),
        );
      }
    } finally {
      await _storage.delete(key: _ownerKey);
      await _storage.delete(key: _tokenKey);
      if (Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.deleteToken();
      }
    }
  }
}
