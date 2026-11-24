import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/api.dart';
import 'legal.dart';
import '../shared/widgets/autorent_text_field.dart';
import '../shared/widgets/screen.dart';
import '../shared/widgets/brand.dart';

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
  bool register = false, visible = false, remember = false;
  Json? acceptance;
  final email = TextEditingController(),
      password = TextEditingController(),
      names = TextEditingController(),
      surname = TextEditingController(),
      phone = TextEditingController();
  @override
  void dispose() {
    for (final c in [email, password, names, surname, phone]) {
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
            autofillHints: const [AutofillHints.givenName],
          ),
          AutoRentTextField(
            label: 'Apellidos',
            controller: surname,
            validator: requiredText,
            autofillHints: const [AutofillHints.familyName],
          ),
          AutoRentTextField(
            label: 'Teléfono (opcional)',
            controller: phone,
            keyboardType: TextInputType.phone,
          ),
        ],
        AutoRentTextField(
          label: 'Correo electrónico',
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          validator: requiredText,
        ),
        AutoRentTextField(
          label: 'Contraseña',
          controller: password,
          obscure: !visible,
          keyboardType: TextInputType.visiblePassword,
          validator: requiredText,
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
              if (phone.text.trim().isNotEmpty) 'telefono': phone.text.trim(),
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
