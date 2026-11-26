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

  Future<void> _register(Api api, String token) async {
    final previous = await _storage.read(key: _tokenKey);
    await api.call(
      '/notifications/android',
      method: 'POST',
      body: {'token': token},
    );
    await _storage.write(key: _tokenKey, value: token);
    if (previous != null && previous != token && api.token != null) {
      await api.call(
        '/notifications/android',
        method: 'DELETE',
        body: {'token': previous},
      );
    }
  }

  Future<void> activate(Api api, int userId) async {
    if (!supported || api.token == null) return;
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
    await _register(api, token);
    await _storage.write(key: _ownerKey, value: '$userId');
    await _listen(api);
  }

  Future<void> _listen(Api api) async {
    await _refresh?.cancel();
    final session = api.token;
    _refresh = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (session == null || api.token != session) return;
      try {
        await _register(api, token);
      } catch (_) {
        // Restore will retry on the next launch with the same account.
      }
    });
  }

  Future<RemoteMessage?> restore(Api api, int userId) async {
    if (!supported) return null;
    if (await _storage.read(key: _ownerKey) != '$userId') return null;
    await _ready(api);
    await _listen(api);
    final messaging = FirebaseMessaging.instance;
    final message = await messaging.getInitialMessage();
    final token = await messaging.getToken();
    if (token != null && api.token != null) await _register(api, token);
    return message;
  }

  Future<void> deactivate(Api api, {String? sessionToken}) async {
    if (!supported) return;
    await _refresh?.cancel();
    _refresh = null;
    final token = await _storage.read(key: _tokenKey);
    try {
      if (token != null && (sessionToken ?? api.token) != null) {
        await api.call(
          '/notifications/android',
          method: 'DELETE',
          body: {'token': token},
          sessionToken: sessionToken,
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
