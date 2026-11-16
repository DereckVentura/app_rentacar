# Fase 5 — Consultar el catálogo de vehículos

La captura de la Fase 4 confirma que el registro creó un cliente, el login entregó un token con duración de `3600` segundos y `/auth/me` devolvió correctamente su perfil. Ahora comprobaremos el catálogo del cliente.

Elegiste mostrar únicamente vehículos operativos. En esta fase podremos listar los vehículos, consultar su detalle y filtrar por categoría, marca, modelo, precio, kilometraje y periodo. Las consultas son públicas y no necesitan el token de la fase anterior.

## Objetivo y archivos

El recorrido sigue siendo `routes → controllers → services → repositories → MySQL`. Los archivos principales de esta fase se encuentran dentro de `C:\Users\Ventura\OneDrive\Documentos\ChatGPT\AutoRent`:

| Parte | Responsabilidad |
| --- | --- |
| `backend/src/routes/vehicle.routes.ts` y `backend/src/controllers/vehicle.controller.ts` | Reciben el listado, el detalle y las opciones de categoría, marca y modelo. |
| `backend/src/validators/vehicle.validator.ts` | Revisa filtros, identificadores, paginación y fechas. |
| `backend/src/models/vehicle.model.ts` | Define los datos que devuelve el catálogo. |
| `backend/src/services/vehicle.service.ts` | Aplica las reglas del catálogo y presenta errores controlados. |
| `backend/src/repositories/vehicle.repository.ts` | Consulta los vehículos y opciones en MySQL con parámetros SQL. |

El contrato completo está en [API de vehículos](api/vehicles.md). No necesitas repetir migraciones, semillas, crear cuentas MySQL ni modificar `.env`. Esta fase utiliza las mismas dependencias y la conexión ya comprobada.

Primero verificaremos las opciones y los cinco vehículos operativos de demostración. Después comprobaremos los filtros y la disponibilidad durante 26 horas. Las últimas pruebas revisan errores previstos y no modifican registros.

## 1. Reiniciar la API

En la ventana donde corre el servidor, presiona `Ctrl+C`. Si PowerShell pide confirmar la terminación del proceso por lotes, confirma.

Ejecuta:

```powershell
Set-Location "C:\Users\Ventura\OneDrive\Documentos\ChatGPT\AutoRent\backend"
npm.cmd run dev
```

Deja esa ventana abierta y espera el mensaje de servidor disponible en `http://127.0.0.1:3000`.

El navegador también permite abrir `http://127.0.0.1:3000/api/v1/vehicles` para ver los datos JSON. La dirección `http://127.0.0.1:3000/api/v1` es únicamente el prefijo: abrirla sola devuelve `404 NOT_FOUND`. En esta fase todavía no hay una interfaz Flutter ni una página visual del catálogo.

## 2. Consultar las opciones de los filtros

Abre otra ventana de PowerShell y usa esa misma ventana para los pasos siguientes:

```powershell
$baseUrl = "http://127.0.0.1:3000/api/v1"
$catalogs = Invoke-RestMethod "$baseUrl/catalogs"
@{
    success = $catalogs.success
    categorias = @($catalogs.data.categorias).Count
    marcas = @($catalogs.data.marcas).Count
    modelos = @($catalogs.data.modelos).Count
} | ConvertTo-Json
```

Con los datos iniciales debe mostrar `success: true`, `categorias: 3`, `marcas: 3` y `modelos: 6`.

Las opciones describen el catálogo configurado. Kia aparece aunque su único vehículo de demostración esté en mantenimiento; un filtro de Kia devolverá una lista vacía.

## 3. Consultar los vehículos

```powershell
$catalog = Invoke-RestMethod "$baseUrl/vehicles"
@{
    success = $catalog.success
    recibidos = @($catalog.data.vehicles).Count
    pagination = $catalog.data.pagination
    periodo = $catalog.data.periodo
} | ConvertTo-Json -Depth 5
$catalog.data.vehicles | Select-Object id, placa, precio_dia, kilometraje, estado_operativo, disponible | Format-Table
```

Debes recibir cinco vehículos, `DEMO-001` a `DEMO-005`. `DEMO-006` está en mantenimiento y queda fuera. La paginación inicial debe indicar `page: 1`, `limit: 20`, `total: 5` y `totalPages: 1`.

`periodo` y `disponible` aparecen como `null` porque todavía no enviamos fechas. Esto significa que no se evaluó la disponibilidad para un periodo concreto. `precio_dia` se devuelve como texto, por ejemplo `"35.00"`, para conservar el importe decimal exacto.

## 4. Consultar el detalle

```powershell
$detail = Invoke-RestMethod "$baseUrl/vehicles/1"
$detail | ConvertTo-Json -Depth 8
```

Debe mostrar `success: true` y `data.vehicle` con `placa: DEMO-001`, Toyota Corolla y `precio_dia: "35.00"`. Incluye categoría, marca, modelo y ubicación. Las direcciones y coordenadas iniciales son ficticias.

## 5. Probar los filtros

Ejecuta cada consulta. Son lecturas y no cambian tus datos:

```powershell
$suvs = Invoke-RestMethod "$baseUrl/vehicles?categoria_id=2"
$suvs.data.vehicles | Select-Object placa, precio_dia | Format-Table
```

Resultado esperado: `DEMO-002` y `DEMO-005`.

```powershell
$toyotas = Invoke-RestMethod "$baseUrl/vehicles?marca_id=1"
$toyotas.data.vehicles | Select-Object placa, precio_dia | Format-Table
```

Resultado esperado: `DEMO-001`, `DEMO-002` y `DEMO-003`.

```powershell
$prices = Invoke-RestMethod "$baseUrl/vehicles?precio_min=32&precio_max=35"
$prices.data.vehicles | Select-Object placa, precio_dia | Format-Table
```

Resultado esperado: `DEMO-001` y `DEMO-004`. Los límites de precio se incluyen.

```powershell
$kilometers = Invoke-RestMethod "$baseUrl/vehicles?kilometraje_max=20000"
$kilometers.data.vehicles | Select-Object placa, kilometraje | Format-Table
```

Resultado esperado: `DEMO-002` y `DEMO-005`.

Para paginar, limita la primera consulta a dos vehículos:

```powershell
$firstPage = Invoke-RestMethod "$baseUrl/vehicles?page=1&limit=2"
$firstPage.data.pagination | ConvertTo-Json
```

Debe mostrar `page: 1`, `limit: 2`, `total: 5` y `totalPages: 3`. Una lista vacía al aplicar otros filtros también puede ser correcta: indica que no hay coincidencias.

## 6. Consultar un periodo de 26 horas

Este bloque elige un inicio dentro de siete días a partir de la hora actual y construye las fechas en UTC. Así no dependemos de una fecha fija que pueda quedar en el pasado:

```powershell
$inicioFecha = [DateTimeOffset]::UtcNow.AddDays(7)
$finFecha = $inicioFecha.AddHours(26)
$inicio = $inicioFecha.UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
$fin = $finFecha.UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
$periodQuery = "inicio=$([Uri]::EscapeDataString($inicio))&fin=$([Uri]::EscapeDataString($fin))"
$available = Invoke-RestMethod "$baseUrl/vehicles?$periodQuery"
@{
    success = $available.success
    recibidos = @($available.data.vehicles).Count
    periodo = $available.data.periodo
} | ConvertTo-Json -Depth 5
$available.data.vehicles | Select-Object placa, disponible | Format-Table
```

Con el catálogo original y sin reservas deben aparecer los cinco vehículos operativos, todos con `disponible: true`. `periodo` debe incluir `inicio_utc` y `fin_utc` separados por 26 horas. Si ya existen reservas en tu base, el número puede ser menor según sus fechas y estados.

Consulta también el detalle durante ese periodo:

```powershell
$detailWithPeriod = Invoke-RestMethod "$baseUrl/vehicles/1?$periodQuery"
@{
    success = $detailWithPeriod.success
    placa = $detailWithPeriod.data.vehicle.placa
    disponible = $detailWithPeriod.data.vehicle.disponible
    periodo = $detailWithPeriod.data.periodo
} | ConvertTo-Json -Depth 5
```

La lista excluye vehículos ocupados durante el periodo; el detalle de un vehículo operativo permite mostrar `disponible: false` si está ocupado. Bloquean las reservas `confirmada` y `en_curso` que se solapan; una reserva que termina justo cuando inicia la siguiente no se solapa.

Esta consulta informa sobre disponibilidad. Todavía no crea reservas ni calcula su total. La regla acordada sigue siendo cobrar por bloques de 24 horas redondeados hacia arriba: 26 horas serán dos días al implementar la reserva.

## 7. Comprobar errores previstos

Un periodo necesita inicio y fin. El siguiente bloque debe devolver HTTP `400` y `VALIDATION_ERROR`:

```powershell
try {
    Invoke-RestMethod "$baseUrl/vehicles?inicio=$([Uri]::EscapeDataString($inicio))"
} catch {
    Write-Host "HTTP $([int]$_.Exception.Response.StatusCode)"
    $_.ErrorDetails.Message
}
```

Un identificador inexistente debe devolver HTTP `404` y `VEHICLE_NOT_FOUND`:

```powershell
try {
    Invoke-RestMethod "$baseUrl/vehicles/999999"
} catch {
    Write-Host "HTTP $([int]$_.Exception.Response.StatusCode)"
    $_.ErrorDetails.Message
}
```

El vehículo en mantenimiento debe devolver el mismo HTTP `404` y `VEHICLE_NOT_FOUND`:

```powershell
try {
    Invoke-RestMethod "$baseUrl/vehicles/6"
} catch {
    Write-Host "HTTP $([int]$_.Exception.Response.StatusCode)"
    $_.ErrorDetails.Message
}
```

Esos errores son resultados esperados de las pruebas y no significan que el servidor esté fallando.

## Si aparece otro resultado

| Resultado | Qué revisar |
| --- | --- |
| No se pudo establecer conexión | Comprueba que la primera ventana siga ejecutando la API y que uses el puerto configurado. |
| `404 NOT_FOUND` al consultar `/vehicles` o `/catalogs` | Reinicia la API con los archivos de esta fase y comprueba la ruta completa con `/api/v1`. |
| `503 DATABASE_UNAVAILABLE` | Comprueba que MySQL esté iniciado y consulta `/api/v1/health/database`. Conserva tu configuración local. |
| `400 VALIDATION_ERROR` | Revisa el mensaje, los nombres de parámetros y sus límites. Usa punto decimal y envía ambas fechas con zona horaria. |
| Lista vacía con `success: true` | Los filtros pueden no tener coincidencias o el periodo puede estar ocupado. Prueba primero el listado sin filtros. |
| Cantidades distintas de las esperadas | Los valores esperados corresponden a la semilla original; compara si ya cambiaste estados, datos o reservas. |

## Confirmación de esta fase

Comparte el resumen de opciones, el listado de cinco vehículos y el resumen de disponibilidad del paso 6. Puedes incluir los códigos esperados del paso 7. Estas consultas no contienen contraseñas ni tokens.

Esperaremos tu confirmación de que el catálogo funciona en tu instalación antes de comenzar la siguiente fase.

## Verificación de la implementación

La comprobación de tipos y la compilación terminaron correctamente. Pasaron las 78 pruebas automatizadas del backend, incluidas 25 pruebas del catálogo, filtros, fechas y errores HTTP.

También pasaron 21 comprobaciones con MySQL 8.4.13 temporal: filtros combinados, paginación preparada, importes y kilometrajes máximos, estados de reservas, períodos solapados y contiguos, zonas horarias, elementos desactivados y caída y recuperación de MySQL. Los procesos temporales se detuvieron y sus archivos privados se retiraron. Las pruebas no modificaron el servicio `MySQL84` del estudiante.

La Fase 5 sigue pendiente de la comprobación local descrita en esta guía.
