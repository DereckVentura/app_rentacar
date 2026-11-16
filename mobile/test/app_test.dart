import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:autorent/core/api.dart';
import 'package:autorent/core/session.dart';
import 'package:autorent/core/theme/app_theme.dart';
import 'package:autorent/features/access.dart';
import 'package:autorent/features/catalog.dart';
import 'package:autorent/features/legal.dart';
import 'package:autorent/shared/widgets/screen.dart';

Widget wrap(Session s, Widget page) => AppScope(
  session: s,
  child: MaterialApp(
    theme: AppTheme.dark,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('es', 'SV')],
    locale: const Locale('es', 'SV'),
    home: Scaffold(body: page),
  ),
);
void main() {
  testWidgets('la aceptación legal requiere dos casillas expresas', (
    tester,
  ) async {
    Json? accepted;
    final api = Api(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'version': 'a' * 64,
              'documents': [
                {
                  'id': 'privacidad',
                  'titulo': 'Aviso de privacidad',
                  'texto': 'Datos de prueba.',
                },
                {
                  'id': 'terminos',
                  'titulo': 'Condiciones',
                  'texto': 'Uso académico.',
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final session = Session(api);
    await tester.pumpWidget(
      wrap(
        session,
        SingleChildScrollView(
          child: LegalConsent(
            onChanged: (value) {
              accepted = value;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(accepted, isNull);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(accepted, isNull);
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pumpAndSettle();
    expect(accepted?['version'], 'a' * 64);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(accepted, isNull);
    api.dispose();
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  test(
    'horas de El Salvador permanecen iguales desde cualquier dispositivo',
    () {
      expect(dateLabel('2026-11-01T15:30:00Z'), '01/11/2026 · 09:30');
      expect(
        svInstant(DateTime(2026, 11, 1, 9, 30)).toIso8601String(),
        '2026-11-01T15:30:00.000Z',
      );
      expect(svWall('2026-11-01T15:30:00Z')!.hour, 9);
    },
  );
  test(
    'errores de permisos conservan el mensaje seguro y revocan sesión en 401',
    () async {
      final api = Api(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'INVALID_TOKEN',
                'message': 'Inicia sesión nuevamente.',
              },
            }),
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      var expired = false;
      api.token = 'temporary';
      api.onExpired = () {
        expired = true;
      };
      await expectLater(
        api.call('/auth/me'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(expired, true);
      api.dispose();
    },
  );
  testWidgets('catálogo muestra información pendiente sin inventar precio', (
    tester,
  ) async {
    final api = Api(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'vehicles': [
                {
                  'id': 1,
                  'marca': {'nombre': 'Mitsubishi'},
                  'modelo': {'nombre': 'Outlander'},
                  'anio': 2017,
                  'precio_dia': null,
                  'reservable': false,
                  'ficha': {'color': 'Gris', 'traccion': 'FWD'},
                },
              ],
              'pagination': {'total': 1, 'totalPages': 1},
            },
          }),
          200,
        ),
      ),
    );
    final s = Session(api);
    await tester.pumpWidget(wrap(s, const CatalogPage()));
    await tester.pumpAndSettle();
    expect(find.text('Mitsubishi Outlander'), findsOneWidget);
    expect(find.text('Tarifa por confirmar'), findsOneWidget);
    expect(find.textContaining('0.00'), findsNothing);
    expect(tester.takeException(), isNull);
    api.dispose();
  });
  testWidgets('acceso envía las credenciales y guarda accessToken real', (
    tester,
  ) async {
    Json? sent;
    final api = Api(
      client: MockClient((r) async {
        sent = jsonDecode(r.body) as Json;
        return http.Response(
          jsonEncode({
            'data': {
              'accessToken': 'token-de-prueba',
              'user': {'id': 1, 'nombres': 'Ventura', 'rol': 'cliente'},
            },
          }),
          200,
        );
      }),
    );
    final s = Session(api);
    await tester.pumpWidget(wrap(s, const AccessPage()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'cliente@example.test',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Una frase larga de prueba',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.pumpAndSettle();
    expect(sent!['email'], 'cliente@example.test');
    expect(api.token, 'token-de-prueba');
    expect(
      await const FlutterSecureStorage().read(key: 'autorent_token'),
      'token-de-prueba',
    );
    expect(s.user!['id'], 1);
    api.dispose();
  });
}
