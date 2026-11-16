# Autenticación — Fase 4

Base local: `http://127.0.0.1:3000/api/v1`.

Esta fase permite registrar clientes, iniciar sesión y consultar el usuario de la sesión. Todas las respuestas usan JSON y las rutas de autenticación envían `Cache-Control: no-store`.

## Usuario público

Las tres operaciones devuelven esta representación del usuario. El `id` del ejemplo puede ser diferente en tu base.

```json
{
  "id": 1,
  "nombres": "Estudiante",
  "apellidos": "Prueba",
  "email": "estudiante@example.test",
  "telefono": null,
  "rol": "cliente"
}
```

El hash de contraseña, el estado interno `activo` y las fechas de la tabla no forman parte de la respuesta. El registro público asigna siempre `cliente`; el solicitante no puede elegir su rol.

## POST /auth/register

Crea un usuario activo con rol `cliente`. No inicia sesión automáticamente.

Envía `Content-Type: application/json` y un objeto con los siguientes campos:

| Campo | Regla |
| --- | --- |
| `nombres` | Texto Unicode válido obligatorio, de 1 a 100 caracteres después de quitar espacios externos, sin caracteres de control. |
| `apellidos` | Las mismas reglas de `nombres`. |
| `email` | Correo ASCII obligatorio, con formato válido y un máximo de 254 caracteres. Se quitan espacios externos y se convierte a minúsculas. |
| `password` | Texto Unicode válido obligatorio, de al menos 15 caracteres y como máximo 72 bytes en UTF-8. Se conserva exactamente, incluidos sus espacios. |
| `telefono` | Opcional. Acepta dígitos ASCII, espacios, `+`, paréntesis y guiones, con al menos un dígito y hasta 25 caracteres después de quitar espacios externos. Si se omite, vale `null` o queda vacío después de quitar espacios, se guarda `null`. |

No se aceptan campos adicionales. En particular, enviar `rol`, `activo` o `password_hash` produce un error de validación.

La contraseña puede ocupar más bytes que caracteres: una letra ASCII ocupa un byte y algunos símbolos ocupan varios. La API rechaza las contraseñas que exceden 72 bytes para evitar el truncamiento de bcrypt. Guarda un hash bcrypt con costo 12, que permite comprobar la contraseña posteriormente sin almacenarla como texto legible. [Documentación de bcrypt](https://github.com/kelektiv/node.bcrypt.js#security-issues-and-concerns).

Respuesta: `201 Created`.

```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "nombres": "Estudiante",
      "apellidos": "Prueba",
      "email": "estudiante@example.test",
      "telefono": null,
      "rol": "cliente"
    }
  }
}
```

Un correo ya registrado devuelve `409 EMAIL_ALREADY_EXISTS`. La normalización permite detectar el mismo correo aunque se envíe con mayúsculas o espacios externos.

## POST /auth/login

Envía un objeto JSON con exactamente `email` y `password`. El correo se normaliza igual que en el registro. La contraseña debe ser texto no vacío de hasta 72 bytes UTF-8 y se conserva exactamente; el mínimo de 15 caracteres se exige al crear la cuenta.

Respuesta: `200 OK`. El valor de `accessToken` indicado aquí es únicamente un marcador del contrato; cada inicio de sesión devuelve un JWT real.

```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "nombres": "Estudiante",
      "apellidos": "Prueba",
      "email": "estudiante@example.test",
      "telefono": null,
      "rol": "cliente"
    },
    "accessToken": "<JWT generado por el servidor>",
    "tokenType": "Bearer",
    "expiresIn": 3600
  }
}
```

Si el correo no existe, la contraseña es incorrecta o la cuenta está inactiva, la respuesta es el mismo error `401 INVALID_CREDENTIALS`. Esto evita revelar cuál de esas condiciones ocurrió.

El token permite presentar la sesión en solicitudes posteriores. Se firma con HS256, identifica al emisor `autorent-api` y a la audiencia `autorent-mobile`, y vence una hora después de emitirse. El servidor verifica firma, algoritmo, emisor, audiencia y vencimiento antes de admitirlo. La firma protege su integridad; no convierte su contenido en secreto. [Documentación de jsonwebtoken](https://github.com/auth0/node-jsonwebtoken#usage).

## GET /auth/me

Consulta el usuario de la sesión. No lleva cuerpo JSON. Envía esta cabecera, sustituyendo el marcador por el token recibido en el login:

```http
Authorization: Bearer <accessToken>
```

Respuesta: `200 OK`, con el mismo sobre `{ "success": true, "data": { "user": ... } }` del registro.

El servidor vuelve a consultar el usuario en MySQL en cada solicitud autenticada. Utiliza su estado activo y rol actuales. Un token de una cuenta eliminada o inactiva no permite continuar.

## Errores

El formato común es:

```json
{
  "success": false,
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "<mensaje de la operación>"
  }
}
```

| HTTP | Código | Cuándo ocurre |
| --- | --- | --- |
| `400` | `VALIDATION_ERROR` | Faltan campos, tienen tipos o valores inválidos, o se envían campos adicionales. |
| `400` | `INVALID_JSON` | El cuerpo no contiene JSON válido. |
| `401` | `INVALID_CREDENTIALS` | El inicio de sesión no se puede completar con las credenciales recibidas. |
| `401` | `AUTHENTICATION_REQUIRED` | Falta la cabecera de autenticación de una ruta protegida. |
| `401` | `INVALID_TOKEN` | El token es inválido, venció o no permite identificar un usuario activo. |
| `403` | `FORBIDDEN` | Un usuario autenticado no tiene uno de los roles exigidos por una ruta. |
| `409` | `EMAIL_ALREADY_EXISTS` | Ya existe el correo del registro. |
| `413` | `PAYLOAD_TOO_LARGE` | El cuerpo supera el límite JSON de 16 KB. |
| `429` | `TOO_MANY_REQUESTS` | Se agotó el límite temporal de intentos de registro e inicio de sesión. La cabecera `Retry-After` indica los segundos de espera. |
| `500` | `INTERNAL_SERVER_ERROR` | Ocurrió un fallo inesperado. La respuesta no incluye SQL, credenciales ni trazas. |
| `503` | `DATABASE_UNAVAILABLE` | MySQL no permite completar la consulta o escritura. La respuesta no incluye detalles de conexión. |

Registro y login comparten un máximo de 30 intentos por dirección IP durante una ventana de 15 minutos. Los intentos que alcanzan las validaciones de esas rutas consumen el límite, tanto si terminan correctamente como si fallan. Los cuerpos que fallan antes por JSON inválido o por superar 16 KB no llegan a ese contador. En las pruebas locales, las dos rutas comparten la dirección `127.0.0.1`. El contador se mantiene en la memoria de un único proceso y se reinicia al reiniciar la API; no coordina múltiples servidores.

El mensaje para ese rechazo es `Demasiados intentos. Espera unos minutos e inténtalo de nuevo.`.

El control de roles queda preparado para las siguientes rutas del negocio. Esta fase no agrega una dirección `/admin` para probarlo.

## Configuración y alcance

`JWT_SECRET` es una clave privada del servidor, distinta de la contraseña de MySQL y de las contraseñas de los clientes. Se configura en `backend/.env` como un valor base64url de exactamente 43 caracteres. `npm.cmd run auth:setup` genera 32 bytes aleatorios y los representa en ese formato sin mostrar la clave ni sustituir las credenciales de MySQL. Conserva una clave válida existente y avisa si encuentra una clave no vacía con formato inválido. La plantilla `.env.example` conserva el campo vacío y no contiene una clave utilizable.

La herramienta local `npm.cmd run user:promote -- --email "estudiante@example.test"` permite convertir una cuenta activa ya registrada en administrador. Es una operación local para quien controla el servidor; el registro público no permite hacerlo. No hace falta ejecutarla para validar esta fase.

Esta entrega no incluye renovación automática del JWT, cierre de sesión en el servidor, recuperación de contraseña, verificación de correo ni pantallas Flutter. Al vencer el token, vuelve a iniciar sesión. Las pruebas completas de Windows están en la [guía de la Fase 4](../phase4-auth-guide.md).
