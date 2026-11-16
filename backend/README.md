# AutoRent API

La versión actual incluye autenticación, catálogo, administración, reservas, alquileres, ubicaciones, avisos y privacidad. Para la entrega universitaria utiliza [LEEME-PRIMERO](../LEEME-PRIMERO.md), el [diseño técnico](../docs/technical-design.md), la [guía de instalación](../docs/installation-and-delivery.md) y la [API de operaciones](../docs/api/operations.md).

Comprobaciones: `npm run typecheck`, `npm test`, `npm run build`. Migraciones: `npm run db:migrate` con credenciales de migración configuradas. No volver a cargar semillas ficticias en una instalación existente. La demostración independiente se prepara mediante `node scripts/demo.mjs`; el iniciador de la raíz abre la web. `.env`, `.private` y respaldos son privados.

Las instrucciones históricas siguientes corresponden a las primeras fases y se conservan para referencia. Las cuentas y módulos descritos como futuros ya están implementados; prevalecen los manuales actuales anteriores.

## Referencia de las primeras fases

La Fase 3 construyó una API base con Express y TypeScript y comprobó su conexión con la base `autorent`. El estudiante confirmó las comprobaciones de diagnóstico y las operaciones de registro, inicio de sesión y perfil de la Fase 4. Continúa con la [guía del catálogo de la Fase 5](../docs/phase5-catalog-guide.md). Los pasos siguientes se conservan como referencia para instalaciones nuevas.

La Fase 2 ya quedó aplicada en tu servicio `MySQL84`: conserva sus tablas y datos. No vuelvas a ejecutar la migración ni las semillas para iniciar esta API. El error `1050: Table 'usuarios' already exists` significa que intentaste crear una tabla existente.

## 1. Crear la cuenta de conexión de la API

La API usará la cuenta MySQL `autorent_app`, con permisos para consultar, agregar, modificar y eliminar datos en `autorent`. Las migraciones se ejecutan por separado con `root`.

Esta cuenta permite conectar el servidor de Node.js con MySQL. No es una cuenta de cliente ni de administrador de la aplicación; esas cuentas estarán en la tabla `usuarios` y se crearán cuando implementemos autenticación.

Abre PowerShell y entra en la raíz del proyecto:

```powershell
Set-Location "C:\Users\Ventura\OneDrive\Documentos\ChatGPT\AutoRent"
```

Ejecuta el siguiente archivo **una sola vez**:

```powershell
& "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 --table --execute="SOURCE database/access/001_create_app_user.sql"
```

Introduce la contraseña de `root` cuando aparezca `Enter password:`. MySQL no mostrará caracteres mientras la escribes.

MySQL mostrará una tabla con una contraseña aleatoria de 32 caracteres para `autorent_app`. Copia únicamente ese valor y guárdalo localmente en el archivo del paso siguiente. No lo pegues en el chat ni lo guardes en el archivo SQL. Comprueba que el comando terminó correctamente:

```powershell
$LASTEXITCODE
```

El resultado esperado es `0`. Si aparece un error de cuenta existente, detente: este archivo no cambia su contraseña y no debes repetirlo para recuperarla. Si no guardaste la contraseña, revisaremos la cuenta antes de restablecerla.

El script usa `IDENTIFIED BY RANDOM PASSWORD`, que devuelve la contraseña generada como resultado de `CREATE USER`. [Referencia oficial de MySQL](https://dev.mysql.com/doc/refman/8.4/en/create-user.html).

## 2. Completar la configuración local

Abre en VS Code este archivo ya preparado:

```text
C:\Users\Ventura\OneDrive\Documentos\ChatGPT\AutoRent\backend\.env
```

Completa solamente el contenido entre las comillas de `DB_PASSWORD` con la contraseña aleatoria del paso anterior. Mantén las comillas y guarda el archivo. Los valores previstos para el servicio local son:

| Variable | Valor |
| --- | --- |
| `NODE_ENV` | `development` |
| `HOST` | `127.0.0.1` |
| `PORT` | `3000` |
| `DB_HOST` | `127.0.0.1` |
| `DB_PORT` | `3306` |
| `DB_NAME` | `autorent` |
| `DB_USER` | `autorent_app` |
| `DB_PASSWORD` | Contraseña aleatoria que MySQL acaba de generar. |

`backend/.env` contiene tu configuración privada y está excluido de Git. No compartas su contenido. `backend/.env.example` es la plantilla pública sin contraseña; si necesitas preparar otra instalación, cópiala como `.env` y completa su contraseña localmente.

La API exige una contraseña no vacía antes de iniciar. Los mensajes de error no imprimen contraseñas, consultas SQL ni detalles de conexión.

Desde la Fase 4 también necesita `JWT_SECRET`: ejecuta `npm.cmd run auth:setup` desde `backend` para generar y guardar esa clave privada automáticamente, conservando los valores MySQL. En este equipo ya se ejecutó. No necesitas copiarla ni compartirla.

## 3. Iniciar la API

En PowerShell, entra en `backend`:

```powershell
Set-Location "C:\Users\Ventura\OneDrive\Documentos\ChatGPT\AutoRent\backend"
```

Las dependencias se instalan con las versiones del archivo `package-lock.json`. Si es una instalación nueva o necesitas reinstalarlas, ejecuta:

```powershell
npm.cmd ci
```

Inicia el servidor de desarrollo:

```powershell
npm.cmd run dev
```

Debes ver este mensaje:

```text
[autorent-api] Servidor disponible en http://127.0.0.1:3000
[autorent-api] Estado: /api/v1/health | MySQL: /api/v1/health/database
```

**Deja esta ventana abierta.** El comando permanece trabajando y reinicia el servidor cuando cambias sus archivos. Para detenerlo al terminar, presiona `Ctrl+C`.

La API escucha en tu computadora local. Cuando construyamos la aplicación Flutter, revisaremos la configuración de red del emulador; esa integración todavía no forma parte de esta fase.

## 4. Comprobar HTTP y MySQL

Abre una **segunda ventana de PowerShell**. Puedes estar en cualquier carpeta. Ejecuta primero:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/api/v1/health" | ConvertTo-Json -Depth 5
```

Respuesta esperada; la fecha y hora serán las del momento de la consulta:

```json
{
  "success": true,
  "data": {
    "service": "autorent-api",
    "status": "ok",
    "timestamp": "2026-10-27T02:00:00.000Z"
  }
}
```

Después comprueba la conexión con MySQL:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/api/v1/health/database" | ConvertTo-Json -Depth 5
```

Respuesta esperada:

```json
{
  "success": true,
  "data": {
    "service": "autorent-api",
    "status": "ok",
    "timestamp": "2026-10-27T02:00:00.000Z",
    "database": "connected"
  }
}
```

La primera consulta comprueba que la API responde. La segunda obtiene una conexión de MySQL y ejecuta `SELECT 1 AS connected`; no cambia registros del negocio. Las sesiones MySQL trabajan en UTC. Los ejemplos `timestamp` terminan en `Z`, que indica UTC.

Un fallo de MySQL no impide que el servidor HTTP siga respondiendo: el primer endpoint puede dar `200` mientras el segundo da `503`. Esto permite distinguir un servidor detenido de una base de datos no disponible. [Conceptos de comprobación y cierre en Express](https://expressjs.com/en/advanced/healthcheck-graceful-shutdown/).

## Si aparece un error

| Situación | Qué revisar |
| --- | --- |
| `CONFIGURATION_ERROR` al iniciar | Lee qué variable menciona el mensaje. Guarda `backend/.env`; `DB_PASSWORD` es obligatorio y los puertos deben ser enteros entre 1 y 65535. |
| `EADDRINUSE` | Ya hay un proceso usando el puerto. Si dejaste otra API abierta, detenla con `Ctrl+C`; también puedes cambiar `PORT` en `.env`, reiniciar y usar ese mismo puerto en las dos URL. |
| PowerShell no puede conectar con la URL | Comprueba que la primera ventana continúe abierta y muestre el mensaje de servidor disponible. |
| HTTP `503` con `DATABASE_UNAVAILABLE` | Comprueba que `MySQL84` esté iniciado y revisa `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` y la contraseña local. El servidor muestra únicamente el código general para no exponer datos privados. |
| Error al crear `autorent_app` porque ya existe | No repitas el script ni borres la cuenta. Conserva el error para revisar su estado. |

Para comprobar la cuenta MySQL directamente, sin poner la contraseña en el comando, ejecuta:

```powershell
& "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -h 127.0.0.1 -P 3306 -u autorent_app -p --database=autorent --execute="SELECT 1 AS connected;"
```

Introduce la contraseña de `autorent_app`, no la de `root`. Debe devolver `connected` con valor `1`. Si recibes `Access denied` o `ER_ACCESS_DENIED_ERROR`, revisa el usuario, el host y el valor exacto de la contraseña. Puedes compartir el mensaje de error sin incluir contraseñas ni el contenido de `.env`.

## Cómo está organizada la API

La petición sigue este recorrido:

```text
routes → controllers → services → repositories → MySQL
```

| Archivo o carpeta | Responsabilidad actual |
| --- | --- |
| `src/server.ts` | Carga la configuración, conecta las capas e inicia/cierra el servidor y el grupo de conexiones. |
| `src/app.ts` | Configura Express, protección de cabeceras, lectura JSON, rutas y manejo de errores. |
| `src/config/env.ts` | Lee y valida variables de entorno. |
| `src/config/database.ts` | Mantiene hasta cinco conexiones reutilizables con MySQL y fija cada sesión en UTC. |
| `src/routes/health.routes.ts` | Asocia las dos URL con los métodos del controlador. |
| `src/controllers/health.controller.ts` | Devuelve respuestas HTTP con JSON. |
| `src/services/health.service.ts` | Construye el estado del servicio y convierte fallos de MySQL en un error controlado. |
| `src/repositories/health.repository.ts` | Ejecuta la consulta de comprobación mediante MySQL2. |
| `src/models/health.model.ts` | Define la estructura de los datos de estado. |
| `src/middlewares/` | Devuelve errores JSON consistentes y resuelve rutas inexistentes. |

Las clases `HealthController`, `HealthService`, `MySqlHealthRepository` y `Database` tienen responsabilidades separadas. El servicio recibe un repositorio por constructor; las pruebas pueden sustituirlo por uno de prueba sin depender de tu servicio MySQL. La reutilización de conexiones evita abrir una conexión nueva desde cero para cada petición. [Grupos de conexiones en MySQL2](https://sidorares.github.io/node-mysql2/docs#using-connection-pools).

## Comandos del proyecto

Ejecuta estos comandos desde la carpeta `backend`:

| Comando | Para qué sirve |
| --- | --- |
| `npm.cmd run dev` | Ejecuta TypeScript durante el desarrollo y observa cambios. |
| `npm.cmd run typecheck` | Comprueba tipos del código y de las pruebas sin generar archivos. |
| `npm.cmd test` | Ejecuta las pruebas automatizadas de configuración y HTTP. No necesita tu contraseña ni una base MySQL real. |
| `npm.cmd run build` | Compila los archivos TypeScript de `src` a JavaScript en `dist`. |
| `npm.cmd start` | Ejecuta `dist/server.js`; primero debes compilar y completar `.env`. |
| `npm.cmd run auth:setup` | Prepara una clave JWT privada en `.env` y conserva una clave válida existente. |
| `npm.cmd run user:promote -- --email "correo registrado"` | Asigna localmente el rol administrador a una cuenta activa existente. |

El proyecto usa Node.js 24 y módulos ESM. Las versiones concretas de dependencias están fijadas en `package.json` y `package-lock.json`. No es necesario instalar Express o TypeScript globalmente.

## Cierre de la fase

La implementación pasó la comprobación de tipos, la compilación y 21 pruebas automatizadas de configuración y HTTP. Además, pasó 13 comprobaciones con una instancia temporal de MySQL 8.4.13: permisos de la cuenta, sesiones UTC, conservación de fechas e importes, liberación de conexiones, errores de inicio, caída y recuperación de MySQL y cierre del servidor. Los procesos temporales se detuvieron y sus archivos privados se retiraron al terminar. Estas pruebas no cambiaron tu servicio `MySQL84` ni configuraron su cuenta `autorent_app`.

La Fase 3 quedó confirmada el 27 de octubre de 2026 a las 04:25 UTC: ambos endpoints respondieron con `success: true` y el segundo incluyó `database: "connected"`. La Fase 4 también quedó confirmada con registro, inicio de sesión y perfil correctos. Continúa con la [guía de la Fase 5](../docs/phase5-catalog-guide.md) y confirma las consultas del catálogo antes de avanzar. Todavía no hay operaciones de reservas ni aplicación Flutter generada.

Contrato de respuestas y códigos HTTP: [documentación de diagnóstico](../docs/api/health.md).
