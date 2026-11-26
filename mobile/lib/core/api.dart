import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  const ApiException(this.message, [this.status = 0, this.code = '']);
  final String message, code;
  final int status;
  @override
  String toString() => message;
}

class Api {
  Api({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  final offline = ValueNotifier<bool>(false);
  static const configured = String.fromEnvironment('API_BASE_URL');
  final String base = configured.isNotEmpty
      ? configured.replaceFirst(RegExp(r'/$'), '')
      : 'https://autorent-molina.lovosdavid.chatgpt.site/api/v1';
  String? token;
  VoidCallback? onExpired;
  String? media(dynamic path) =>
      path == null ? null : Uri.parse(base).resolve(path.toString()).toString();
  Future<Json> call(
    String path, {
    String method = 'GET',
    Json? body,
    Map<String, String>? query,
    String? key,
    String? sessionToken,
    Duration responseTimeout = const Duration(seconds: 12),
  }) async {
    final bearer = sessionToken ?? token;
    final uri = Uri.parse('$base$path')
        .replace(queryParameters: query?.isEmpty == true ? null : query);
    try {
      final response = await _client
          .send(
            http.Request(method, uri)
              ..headers.addAll({
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                if (bearer != null) 'Authorization': 'Bearer $bearer',
                'Idempotency-Key': ?key,
              })
              ..body = body == null ? '' : jsonEncode(body),
          )
          .timeout(responseTimeout);
      final raw = await response.stream.bytesToString().timeout(
        const Duration(seconds: 90),
      );
      Json data;
      try {
        data = jsonDecode(raw) as Json;
      } catch (_) {
        throw const ApiException(
          'El servidor no respondió correctamente. Intenta de nuevo.',
        );
      }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && bearer != null && token == bearer) {
          onExpired?.call();
        }
        final error = data['error'] as Json? ?? {};
        throw ApiException(
          error['message']?.toString() ?? 'No se pudo completar la operación.',
          response.statusCode,
          error['code']?.toString() ?? '',
        );
      }
      return data['data'] as Json? ?? {};
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar. Comprueba tu conexión e intenta de nuevo.',
      );
    }
  }

  Future<Uint8List> image(String path) async {
    final response = await _client
        .get(
          Uri.parse('$base$path'),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw const ApiException('No se pudo cargar el documento.');
    }
    return response.bodyBytes;
  }

  Future<String> uploadFleetPhoto(Uint8List bytes) async {
    final response = await _client
        .post(
          Uri.parse('$base/admin/fleet-photos'),
          headers: {
            'Content-Type': 'application/octet-stream',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 35));
    final envelope = jsonDecode(response.body) as Json;
    if (response.statusCode >= 400) {
      throw ApiException(
        envelope['error']?['message']?.toString() ??
            'No se pudo subir la foto.',
        response.statusCode,
      );
    }
    return envelope['data']['url'] as String;
  }

  Future<Json> uploadPrivatePhoto(
    String path,
    Uint8List bytes, {
    String contentType = 'image/png',
  }) async {
    final response = await _client
        .put(
          Uri.parse('$base$path'),
          headers: {
            'Content-Type': contentType,
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 35));
    final envelope = jsonDecode(response.body) as Json;
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && token != null) onExpired?.call();
      final error = envelope['error'] as Json? ?? {};
      throw ApiException(
        error['message']?.toString() ?? 'No se pudo guardar la foto.',
        response.statusCode,
        error['code']?.toString() ?? '',
      );
    }
    return envelope['data'] as Json? ?? {};
  }

  void dispose() {
    _client.close();
    offline.dispose();
  }
}

String? localVehicleAsset(String? url) {
  if (url == null) return null;
  final file = Uri.tryParse(url)?.pathSegments.lastOrNull;
  const files = {
    'outlander-gris-1.jpeg',
    'outlander-gris-2.jpeg',
    'outlander-roja-1.jpeg',
    'outlander-roja-2.jpg',
    'rogue-gris-1.jpeg',
    'rogue-gris-2.jpeg',
  };
  return files.contains(file) ? 'assets/vehicles/$file' : null;
}

String vehicleName(Json v) =>
    '${v['marca'] is Map ? v['marca']['nombre'] : v['marca']} ${v['modelo'] is Map ? v['modelo']['nombre'] : v['modelo']}';
Json facts(Json v) => (v['ficha'] as Json?) ?? {};
String value(dynamic v) =>
    v == null || v.toString().isEmpty ? 'Por confirmar' : v.toString();
