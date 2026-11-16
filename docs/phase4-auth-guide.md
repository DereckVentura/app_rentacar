# Fase 4 — Registro e inicio de sesión

La Fase 3 quedó confirmada: la API respondió correctamente y devolvió `database: connected` en tu servicio MySQL el 27 de octubre de 2026 en UTC.

Ahora comprobaremos tres pasos: crear un cliente de prueba, iniciar sesión y consultar su usuario con el token recibido. La tabla `usuarios` ya existe: esta fase no requiere repetir migraciones, semillas ni la creación de `autorent_app`.

## Qué se incorpora

| Parte | Responsabilidad |
| --- | --- |
| `backend/src/routes/auth.routes.ts` y `backend/src/controllers/auth.controller.ts` | Reciben las peticiones de registro, login y consulta de sesión. |
| `backend/src/validators/auth.validator.ts` | Revisa nombres, correo, teléfono y contraseña y rechaza campos ajenos al contrato. |
| `backend/src/services/auth.service.ts` | Aplica las reglas, compara contraseñas y solicita la emisión de tokens. |
| `backend/src/repositories/user.repository.ts` y `backend/src/models/user.model.ts` | Consultan e insertan usuarios con parámetros SQL y definen sus datos. |
| `backend/src/services/password.service.ts` | Usa bcrypt para guardar hashes y comprobar contraseñas. |
| `backend/src/services/token.service.ts` y `backend/src/middlewares/auth.middleware.ts` | Verifican el token y consultan el usuario activo en MySQL. |
| `backend/src/middlewares/role.middleware.ts` | Prepara la autorización de operaciones futuras según el rol actual del usuario. |
| `backend/scripts/setup-auth-secret.mjs` y `backend/src/scripts/promote-user.ts` | Preparan `JWT_SECRET` y permiten promover posteriormente un usuario activo. |

Las rutas de esa tabla parten de `C:\Users\Ventura\OneDrive\Documentos\ChatGPT\AutoRent`. La API conserva el recorrido `routes → controllers → services → repositories → MySQL` de la fase anterior.

Las contraseñas del cliente se guardan mediante bcrypt con costo 12. Un hash permite comprobar una contraseña sin guardar su texto original. La API limita la longitud a 72 bytes UTF-8 porque bcrypt tiene ese límite. [Documentación de bcrypt](https://github.com/kelektiv/node.bcrypt.js#security-issues-and-concerns).

Después del login, un JWT firmado permite presentar la sesión durante una hora. El servidor verifica su firma y vencimiento y vuelve a consultar el estado y rol del usuario. La clave `JWT_SECRET` queda en el servidor. [Documentación de jsonwebtoken](https://github.com/auth0/node-jsonwebtoken#usage).

## 1. Reiniciar la API

En la ventana donde corre `npm.cmd run dev`, presiona `Ctrl+C`. Si PowerShell pide confirmar la terminación del proceso por lotes, confirma.

Entra en la carpeta del backend:

```powershell
Set-Location "C:\Users\Ventura\OneDrive\Documentos\ChatGPT\AutoRent\backend"
```

La clave local `JWT_SECRET` ya se prepara durante esta entrega. No necesitas cambiar tu contraseña de MySQL ni compartir `.env`. Si estás preparando otra copia del proyecto o aparece un error indicando que falta `JWT_SECRET`, ejecuta:

```powershell
npm.cmd run auth:setup
```

Este comando genera una clave aleatoria en el archivo local `.env` sin mostrarla y conserva las credenciales existentes. La plantilla `.env.example` deja la clave vacía de forma intencional. La clave generada tiene exactamente 43 caracteres base64url. Si ya encuentra una clave válida, conserva su valor. Si informa que existe una clave con formato inválido, conserva ese mensaje para revisar la configuración sin compartir la clave.

Inicia nuevamente:

```powershell
npm.cmd run dev
```

Deja esa ventana abierta. Las dependencias de esta entrega ya están preparadas; una instalación nueva debe ejecutar primero `npm.cmd ci` desde `backend`.

## 2. Preparar una cuenta de prueba

Abre una segunda ventana de PowerShell y conserva esa ventana para todos los pasos siguientes. Las variables de una ventana no pasan a otra.

Usaremos una cuenta ficticia. Puedes sustituir su correo por otro correo de prueba si ese ya existe; el sistema no envía correo en esta fase.

```powershell
$baseUrl = "http://127.0.0.1:3000/api/v1"
$email = "estudiante@example.test"
$securePassword = Read-Host "Crea una contraseña de prueba: mínimo 15 caracteres" -AsSecureString
$password = [System.Net.NetworkCredential]::new("", $securePassword).Password
$registrationBody = @{
    nombres = "Estudiante"
    apellidos = "Prueba"
    email = $email
    password = $password
} | ConvertTo-Json -Compress
```

Escribe tu contraseña cuando aparezca la pregunta; no se mostrará mientras la ingresas. Usa al menos 15 caracteres y no más de 72 bytes UTF-8. Los espacios cuentan y se conservan. No escribas la contraseña directamente en un comando y no la compartas en el chat.

La conversión a texto permite enviarla a la API y queda temporalmente en la memoria de esta sesión. No muestres `$password`, `$registrationBody` ni el contenido de `.env`.

## 3. Registrar el cliente

Ejecuta:

```powershell
$registration = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method Post -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($registrationBody))
$registration | ConvertTo-Json -Depth 5
```

La API debe responder HTTP `201` y mostrar un resultado similar al siguiente. El `id` depende de tu base:

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

La respuesta no muestra la contraseña ni su hash. El registro asigna siempre `cliente`; no agregues `rol` al cuerpo. Si aparece `409 EMAIL_ALREADY_EXISTS`, esa cuenta ya está registrada: no la borres y continúa con el login usando su contraseña, o prepara una cuenta ficticia diferente.

## 4. Iniciar sesión

En la misma ventana:

```powershell
$loginBody = @{
    email = $email
    password = $password
} | ConvertTo-Json -Compress
$login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($loginBody))
@{
    success = $login.success
    user = $login.data.user
    tokenType = $login.data.tokenType
    expiresIn = $login.data.expiresIn
    tokenRecibido = -not [string]::IsNullOrWhiteSpace($login.data.accessToken)
} | ConvertTo-Json -Depth 5
```

Debe mostrar `success: true`, tu usuario, `tokenType: Bearer`, `expiresIn: 3600` y `tokenRecibido: true`. El JWT se conserva en `$login` y el resumen anterior evita imprimirlo. No muestres el objeto `$login` completo ni compartas su token.

## 5. Consultar el usuario autenticado

Envía el token guardado como cabecera de autorización:

```powershell
$authHeaders = @{ Authorization = "Bearer $($login.data.accessToken)" }
$me = Invoke-RestMethod -Uri "$baseUrl/auth/me" -Headers $authHeaders
$me | ConvertTo-Json -Depth 5
```

Debe responder `success: true` y el mismo usuario con rol `cliente`. Esta consulta comprueba la firma y vencimiento del token y consulta la cuenta activa en MySQL.

## 6. Comprobar rechazos previstos

Estas pruebas son breves y forman parte de la validación. Registro y login comparten 30 intentos por IP durante 15 minutos. No ejecutes los bloques repetidamente.

Primero comprueba que `/auth/me` exige iniciar sesión:

```powershell
try {
    Invoke-RestMethod -Uri "$baseUrl/auth/me"
} catch {
    Write-Host "HTTP $([int]$_.Exception.Response.StatusCode)"
    $_.ErrorDetails.Message
}
```

Resultado esperado: `401` y `AUTHENTICATION_REQUIRED`.

Después usa un token inválido, creado solamente para esta prueba:

```powershell
try {
    Invoke-RestMethod -Uri "$baseUrl/auth/me" -Headers @{ Authorization = "Bearer token-invalido-de-prueba" }
} catch {
    Write-Host "HTTP $([int]$_.Exception.Response.StatusCode)"
    $_.ErrorDetails.Message
}
```

Resultado esperado: `401` y `INVALID_TOKEN`.

Comprueba un intento de login incorrecto con un valor aleatorio de prueba:

```powershell
$wrongLoginBody = @{
    email = $email
    password = [Guid]::NewGuid().ToString("N")
} | ConvertTo-Json -Compress
try {
    Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($wrongLoginBody))
} catch {
    Write-Host "HTTP $([int]$_.Exception.Response.StatusCode)"
    $_.ErrorDetails.Message
}
```

Resultado esperado: `401` y `INVALID_CREDENTIALS`. La misma respuesta se utiliza para una cuenta ausente o inactiva.

Finalmente vuelve a enviar una vez el registro del paso 3:

```powershell
try {
    Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method Post -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($registrationBody))
} catch {
    Write-Host "HTTP $([int]$_.Exception.Response.StatusCode)"
    $_.ErrorDetails.Message
}
```

Resultado esperado: `409` y `EMAIL_ALREADY_EXISTS`. Esto no crea otro usuario.

## 7. Terminar la prueba

Cuando termines, quita las variables que contienen contraseña y token:

```powershell
Remove-Variable password, securePassword, registrationBody, loginBody, wrongLoginBody, login, authHeaders -ErrorAction SilentlyContinue
```

También puedes cerrar esa segunda ventana. Si necesitas otra sesión más tarde, vuelve a ingresar la contraseña con `Read-Host -AsSecureString` y realiza el login.

Para confirmar esta fase, comparte solamente la respuesta de registro, el resumen de login que oculta el JWT y la respuesta de `/auth/me`. También puedes indicar los códigos de los rechazos previstos. No compartas la contraseña, el JWT ni `.env`.

El estudiante confirmó registro, login y consulta del perfil con respuestas correctas. La Fase 4 está completada; las instrucciones se conservan para repetir la comprobación o preparar otra instalación.

## Verificación de la implementación

La compilación y la comprobación de tipos terminaron correctamente. Las 53 pruebas automatizadas pasaron; incluyen configuración, HTTP, bcrypt, JWT, autorización, validaciones, límites de solicitudes y preparación segura de la clave local.

También pasaron 17 comprobaciones con MySQL 8.4.13 temporal y una cuenta de acceso restringida. Verificaron persistencia del hash, correo duplicado, registro simultáneo, rechazo de privilegios públicos, login, perfil, desactivación, promoción local y caída y recuperación de MySQL. Los procesos se detuvieron y sus archivos privados temporales se retiraron. Estas comprobaciones no crearon usuarios en tu servicio `MySQL84`.

La siguiente comprobación local corresponde al [catálogo de la Fase 5](phase5-catalog-guide.md).

## Si aparece un error

| Resultado | Qué revisar |
| --- | --- |
| `CONFIGURATION_ERROR` que menciona `JWT_SECRET` | Desde `backend`, ejecuta `npm.cmd run auth:setup` y reinicia la API. No pegues la clave en el chat. |
| `VALIDATION_ERROR` | Lee el mensaje. Revisa nombres, correo y contraseña, y conserva únicamente los campos del contrato. |
| `EMAIL_ALREADY_EXISTS` | Usa el login de esa cuenta si conoces su contraseña, o una cuenta ficticia diferente para repetir el registro. |
| `INVALID_CREDENTIALS` | Comprueba que usaste el correo y contraseña de la cuenta creada. Los espacios en la contraseña sí cuentan. |
| `AUTHENTICATION_REQUIRED` | Repite el paso 5 con `$authHeaders` en la misma ventana donde guardaste `$login`. |
| `INVALID_TOKEN` | Vuelve a iniciar sesión para obtener un token vigente; comprueba que se envíe con `Bearer`. |
| HTTP `429` | Se agotaron los intentos de esa ventana de 15 minutos. Espera a que se liberen antes de repetir registro o login. |
| No se pudo establecer conexión | Comprueba que la primera ventana siga ejecutando la API y que uses el puerto configurado. |
| `INTERNAL_SERVER_ERROR` | Comprueba el diagnóstico `/api/v1/health/database` y conserva el código general de la consola del servidor para revisarlo. |
| `DATABASE_UNAVAILABLE` | Comprueba que el servicio MySQL esté iniciado y consulta `/api/v1/health/database`. Conserva únicamente el mensaje de error, sin compartir `.env`. |

No hace falta crear un administrador para estas pruebas. El comando local de promoción queda disponible para configurar ese rol cuando se necesite; no existe un endpoint público para elegirlo al registrarse. El [contrato de autenticación](api/auth.md) detalla campos, respuestas y alcance.
