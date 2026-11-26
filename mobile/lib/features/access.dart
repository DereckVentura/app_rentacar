import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/session.dart';
import '../core/api.dart';
import '../core/validation.dart';
import 'legal.dart';
import '../shared/widgets/autorent_text_field.dart';
import '../shared/widgets/screen.dart';
import '../shared/widgets/brand.dart';
import '../shared/widgets/phone_field.dart';

Future<bool> requireLogin(BuildContext context) async {
  if (AppScope.of(context).user != null) return true;
  return await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AccessPage()),
      ) ??
      false;
}

class AccessPage extends StatefulWidget {
  const AccessPage({super.key});
  @override
  State<AccessPage> createState() => _AccessPageState();
}

class _AccessPageState extends State<AccessPage> {
  static Future<void>? googleInitialization;
  bool googleAvailable = false, googleBusy = false;
  String? googleClient;
  bool register = false, visible = false, remember = false;
  Json? acceptance;
  final email = TextEditingController(),
      password = TextEditingController(),
      names = TextEditingController(),
      surname = TextEditingController();
  String phone = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (googleClient != null ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    googleClient = '';
    final api = AppScope.of(context).api;
    api
        .call('/auth/google-config')
        .then((config) {
          final id = config['clientId'];
          if (mounted &&
              id is String &&
              id.endsWith('.apps.googleusercontent.com')) {
            setState(() {
              googleClient = id;
              googleAvailable = true;
            });
          }
        })
        .catchError((Object _) {});
  }

  Future<void> signInWithGoogle(Session session) async {
    if (googleBusy || googleClient == null) return;
    if (register && (validatedPhone(phone) == null || acceptance == null)) {
      tell(
        context,
        'Indica tu celular y acepta los documentos antes de registrarte con Google.',
      );
      return;
    }
    setState(() => googleBusy = true);
    try {
      final google = GoogleSignIn.instance;
      googleInitialization ??= google.initialize(serverClientId: googleClient);
      try {
        await googleInitialization;
      } catch (_) {
        googleInitialization = null;
        rethrow;
      }
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null) {
        throw const ApiException('Google no devolvió un token válido.');
      }
      final result = await session.api.call(
        '/auth/google',
        method: 'POST',
        body: {
          'credential': token,
          if (password.text.isNotEmpty) 'password': password.text,
          if (register) 'telefono': validatedPhone(phone),
          if (register) 'aceptacion': acceptance,
          'recordar': remember,
        },
      );
      await session.access(result, remember: remember);
      if (mounted) Navigator.pop(context, true);
    } on GoogleSignInException catch (error) {
      if (mounted && error.code != GoogleSignInExceptionCode.canceled) {
        tell(context, 'Google no está disponible en este dispositivo.');
      }
    } on ApiException catch (error) {
      if (mounted && error.code == 'GOOGLE_REGISTER_REQUIRED') {
        setState(() => register = true);
      }
      if (mounted) tell(context, error);
    } catch (_) {
      if (mounted) tell(context, 'No se pudo completar el acceso con Google.');
    } finally {
      if (mounted) setState(() => googleBusy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [email, password, names, surname]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return FormPage(
      title: register ? 'Crea tu cuenta' : 'Te damos la bienvenida',
      label: register ? 'Crear cuenta' : 'Ingresar',
      fields: [
        const MolinaBrand(large: true),
        const Text(
          'Ingresa con tu cuenta para gestionar tus reservas.',
          style: TextStyle(fontSize: 12),
        ),
        if (register) ...[
          AutoRentTextField(
            label: 'Nombres',
            controller: names,
            validator: requiredText,
            maxLength: 100,
            autofillHints: const [AutofillHints.givenName],
          ),
          AutoRentTextField(
            label: 'Apellidos',
            controller: surname,
            validator: requiredText,
            maxLength: 100,
            autofillHints: const [AutofillHints.familyName],
          ),
          PhoneField(initialValue: phone, onChanged: (value) => phone = value),
        ],
        AutoRentTextField(
          label: 'Correo electrónico',
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          validator: emailError,
        ),
        AutoRentTextField(
          label: 'Contraseña',
          controller: password,
          obscure: !visible,
          keyboardType: TextInputType.visiblePassword,
          validator: (value) => passwordError(value, creating: register),
          autofillHints: [
            register ? AutofillHints.newPassword : AutofillHints.password,
          ],
          suffixIcon: IconButton(
            tooltip: visible ? 'Ocultar contraseña' : 'Ver contraseña',
            onPressed: () => setState(() => visible = !visible),
            icon: Icon(
              visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        if (!register)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: remember,
            title: const Text('Recordar sesión'),
            onChanged: (value) => setState(() => remember = value ?? false),
          ),
        if (register)
          const Text(
            'Usa una contraseña de al menos 8 caracteres (máximo 72 bytes).',
          ),
        TextButton(
          onPressed: () => setState(() {
            register = !register;
            visible = false;
          }),
          child: Text(register ? 'Ya tengo una cuenta' : 'Crear una cuenta'),
        ),
        if (register)
          LegalConsent(
            onChanged: (value) {
              acceptance = value;
            },
          ),
        if (!register)
          TextButton(
            onPressed: () => openHelp(context),
            child: const Text('Aviso de privacidad y condiciones'),
          ),
        if (googleAvailable)
          OutlinedButton(
            onPressed: googleBusy ? null : () => signInWithGoogle(session),
            child: Text(
              googleBusy ? 'Comprobando cuenta…' : 'Continuar con Google',
            ),
          ),
      ],
      save: () async {
        if (register && acceptance == null) {
          throw const ApiException(
            'Lee los documentos y confirma ambas casillas para crear la cuenta.',
          );
        }
        final credentials = {
          'email': email.text.trim(),
          'password': password.text,
        };
        final result = await session.api.call(
          register ? '/auth/register' : '/auth/login',
          method: 'POST',
          body: {
            'email': email.text.trim(),
            'password': password.text,
            if (!register) 'recordar': remember,
            if (register) ...{
              'nombres': names.text.trim(),
              'apellidos': surname.text.trim(),
              'aceptacion': acceptance,
              'telefono': validatedPhone(phone),
            },
          },
        );
        await session.access(
          register
              ? await session.api.call(
                  '/auth/login',
                  method: 'POST',
                  body: credentials,
                )
              : result,
          remember: !register && remember,
        );
      },
    );
  }
}
