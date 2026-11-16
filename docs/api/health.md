# API de diagnóstico — Fase 3

Base local: `http://127.0.0.1:3000/api/v1`. Los endpoints de esta fase son públicos y responden con `Content-Type: application/json; charset=utf-8`.

## GET /health

Comprueba que el servidor HTTP puede responder. No consulta MySQL.

Estado HTTP: `200 OK`.

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

`timestamp` es una fecha ISO 8601 en UTC, calculada para cada respuesta. El valor anterior es un ejemplo.

## GET /health/database

Obtiene una conexión del grupo MySQL, fija la sesión en UTC y ejecuta `SELECT 1 AS connected`. Libera la conexión al terminar, incluso si ocurre un error. No crea tablas ni modifica registros de AutoRent.

Estado HTTP cuando MySQL responde: `200 OK`.

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

Este resultado confirma que las credenciales permiten conectar con la base configurada y ejecutar una consulta. La estructura, restricciones y catálogo se verifican por separado con `database/checks/001_verify_setup.sql`.

Estado HTTP cuando la conexión o consulta falla: `503 Service Unavailable`.

```json
{
  "success": false,
  "error": {
    "code": "DATABASE_UNAVAILABLE",
    "message": "No se pudo conectar con la base de datos. Intenta nuevamente más tarde."
  }
}
```

La respuesta no incluye usuarios MySQL, contraseñas, SQL ni trazas internas. El servidor registra únicamente `[autorent-api] DATABASE_UNAVAILABLE`. `/health` puede continuar respondiendo correctamente mientras falla `/health/database`; consulta ambos para distinguir las dos condiciones.

## Otros errores HTTP

Las respuestas de error usan siempre `success: false` y un objeto `error` con `code` y `message`.

| HTTP | `code` | `message` | Cuándo aparece |
| --- | --- | --- | --- |
| `400` | `INVALID_JSON` | El cuerpo de la solicitud debe contener JSON válido. | El lector JSON recibe un cuerpo inválido con tipo de contenido JSON. |
| `404` | `NOT_FOUND` | La ruta solicitada no existe. | La dirección o el método solicitado no corresponde a las rutas disponibles. |
| `413` | `PAYLOAD_TOO_LARGE` | El cuerpo de la solicitud supera el tamaño permitido. | El cuerpo JSON excede el límite de 16 KB. |
| `500` | `INTERNAL_SERVER_ERROR` | Ocurrió un error inesperado. Intenta nuevamente más tarde. | Ocurre un fallo que no tiene otro error controlado. |

Ejemplo completo al visitar `/api/v1/vehiculos`, que todavía no está implementado:

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "La ruta solicitada no existe."
  }
}
```

No se necesita enviar cuerpo JSON para las dos consultas `GET` de esta fase.

## Prueba en Windows

Con `npm.cmd run dev` activo en una primera ventana, ejecuta desde una segunda PowerShell:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/api/v1/health" | ConvertTo-Json -Depth 5
```

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/api/v1/health/database" | ConvertTo-Json -Depth 5
```

Para crear la cuenta MySQL y preparar `.env`, consulta la [guía del backend](../../backend/README.md).

## Alcance y referencias

Estas comprobaciones permiten validar la base de la API. Todavía no implementan registro, inicio de sesión, roles, catálogo HTTP, reservas ni la protección transaccional contra reservas simultáneas.

La separación entre estado del servidor y disponibilidad de sus dependencias sigue los conceptos de [comprobación de estado de Express](https://expressjs.com/en/advanced/healthcheck-graceful-shutdown/). La implementación de conexiones usa la [API Promise y los grupos de conexiones de MySQL2](https://sidorares.github.io/node-mysql2/docs#using-connection-pools).
