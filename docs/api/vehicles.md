# API del catálogo de vehículos — Fase 5

Base local: `http://127.0.0.1:3000/api/v1`.

Estas consultas son públicas: no requieren JWT, cabecera `Authorization` ni cuerpo JSON. Devuelven JSON y `Cache-Control: no-store` para que una respuesta anterior no se reutilice como comprobación de disponibilidad.

El catálogo del cliente muestra únicamente vehículos `operativo` cuya categoría, marca y ubicación estén activas. Oculta los vehículos en mantenimiento o inactivos. Los datos iniciales son ficticios y no representan el inventario de la empresa.

## GET /catalogs

Entrega las opciones para construir los filtros. No recibe parámetros de consulta.

Estado HTTP: `200 OK`.

```json
{
  "success": true,
  "data": {
    "categorias": [
      { "id": 1, "nombre": "Sedán" },
      { "id": 2, "nombre": "SUV" },
      { "id": 3, "nombre": "Pickup" }
    ],
    "marcas": [
      { "id": 1, "nombre": "Toyota" },
      { "id": 2, "nombre": "Hyundai" },
      { "id": 3, "nombre": "Kia" }
    ],
    "modelos": [
      { "id": 1, "marca_id": 1, "nombre": "Corolla" },
      { "id": 2, "marca_id": 1, "nombre": "RAV4" },
      { "id": 3, "marca_id": 1, "nombre": "Hilux" },
      { "id": 4, "marca_id": 2, "nombre": "Accent" },
      { "id": 5, "marca_id": 2, "nombre": "Tucson" },
      { "id": 6, "marca_id": 3, "nombre": "Rio" }
    ]
  }
}
```

El ejemplo muestra el contenido inicial; el orden puede variar. Las categorías y marcas deben estar activas. Los modelos pertenecen a marcas activas. Una opción puede existir aunque no tenga vehículos operativos: por ejemplo, Kia y Rio aparecen como opciones y el Kia de demostración está en mantenimiento. Seleccionar esa opción puede devolver una lista vacía.

## GET /vehicles

Entrega los vehículos visibles que coinciden con todos los filtros enviados. Los límites de precio y kilometraje son inclusivos. Una consulta sin coincidencias devuelve `200` con `vehicles: []`.

### Parámetros de consulta

| Parámetro | Valor permitido | Comportamiento |
| --- | --- | --- |
| `categoria_id` | Entero entre `1` y `4294967295`. | Filtra por categoría. |
| `marca_id` | Entero entre `1` y `4294967295`. | Filtra por marca. |
| `modelo_id` | Entero entre `1` y `4294967295`. | Filtra por modelo. |
| `precio_min` | Decimal entre `0` y `99999999.99`, con hasta dos decimales. | Tarifa diaria mínima en USD. |
| `precio_max` | Mismo formato que `precio_min`. | Tarifa diaria máxima en USD. |
| `kilometraje_min` | Entero entre `0` y `4294967295`. | Kilometraje mínimo. |
| `kilometraje_max` | Entero entre `0` y `4294967295`. | Kilometraje máximo. |
| `page` | Entero entre `1` y `1000000`. | Página solicitada; valor inicial `1`. |
| `limit` | Entero entre `1` y `100`. | Elementos por página; valor inicial `20`. |
| `inicio` | Fecha con hora, segundos y zona horaria explícita. | Inicio del periodo, acompañado de `fin`. |
| `fin` | Mismo formato que `inicio`; posterior al inicio. | Fin del periodo, acompañado de `inicio`. |

Cada mínimo debe ser menor o igual que su máximo. El dinero admite, por ejemplo, `35`, `35.5` y `35.50`; se normaliza a dos decimales para las consultas. No admite coma decimal, exponentes ni más de dos decimales. Los números no admiten signos, espacios ni ceros iniciales como `01`. Los parámetros desconocidos o repetidos se rechazan con `400 VALIDATION_ERROR`.

Ejemplos:

```text
GET /vehicles
GET /vehicles?categoria_id=2
GET /vehicles?marca_id=1&precio_max=60
GET /vehicles?precio_min=32&precio_max=35
GET /vehicles?kilometraje_max=20000&page=1&limit=2
GET /vehicles?inicio=2026-11-10T14%3A00%3A00Z&fin=2026-11-11T16%3A00%3A00Z
```

### Respuesta

Estado HTTP: `200 OK`.

Ejemplo con `limit=1`, sin periodo y con el catálogo de demostración original:

```json
{
  "success": true,
  "data": {
    "vehicles": [
      {
        "id": 1,
        "placa": "DEMO-001",
        "anio": 2023,
        "kilometraje": 35000,
        "precio_dia": "35.00",
        "moneda": "USD",
        "estado_operativo": "operativo",
        "descripcion": "Vehículo de demostración: Toyota Corolla.",
        "imagen_url": null,
        "categoria": { "id": 1, "nombre": "Sedán" },
        "marca": { "id": 1, "nombre": "Toyota" },
        "modelo": { "id": 1, "nombre": "Corolla" },
        "ubicacion": {
          "id": 1,
          "nombre": "Sucursal de demostración A",
          "tipo": "sucursal",
          "direccion": "Dirección ficticia A. Solo para demostración.",
          "latitud": "13.7000000",
          "longitud": "-88.1000000"
        },
        "disponible": null
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 1,
      "total": 5,
      "totalPages": 5
    },
    "periodo": null
  }
}
```

`total` cuenta las coincidencias de todos los filtros antes de paginar y `totalPages` indica cuántas páginas contienen esas coincidencias. Una página posterior a la última devuelve una lista vacía y conserva el total. Cuando no hay coincidencias, `total` y `totalPages` valen `0`.

`precio_dia` es texto decimal para conservar el importe exacto. La API no calcula un total de alquiler en esta fase. Las coordenadas también se envían como texto decimal; las ubicaciones iniciales son de demostración. `descripcion` e `imagen_url` pueden ser `null`; una imagen configurada se entrega como texto en `imagen_url`.

`disponible: null` significa que no se consultó un periodo. Si se envían `inicio` y `fin`, la lista contiene solamente vehículos libres durante ese periodo, cada uno con `disponible: true`. El objeto `periodo` muestra las fechas normalizadas a UTC:

```json
{
  "inicio_utc": "2026-11-10T14:00:00.000Z",
  "fin_utc": "2026-11-11T16:00:00.000Z"
}
```

## GET /vehicles/:id

Consulta un vehículo visible por su identificador entero entre `1` y `4294967295`. Solo admite los parámetros opcionales `inicio` y `fin`, juntos y con las mismas reglas de fechas del listado.

```text
GET /vehicles/1
GET /vehicles/1?inicio=2026-11-10T14%3A00%3A00Z&fin=2026-11-11T16%3A00%3A00Z
```

Estado HTTP cuando existe y es visible: `200 OK`. La forma es:

```text
{
  "success": true,
  "data": {
    "vehicle": { ...mismos campos de un elemento de vehicles... },
    "periodo": null
  }
}
```

Sin periodo, `vehicle.disponible` vale `null`. Con periodo válido, puede valer `true` o `false`: el detalle permite consultar un vehículo operativo aunque esté ocupado en esas fechas. En ese caso, `periodo` contiene `inicio_utc` y `fin_utc`.

Un identificador inexistente o un vehículo oculto por su estado, categoría, marca o ubicación devuelve `404 VEHICLE_NOT_FOUND`. El vehículo `6` del catálogo inicial está en mantenimiento y devuelve ese error.

## Fechas y disponibilidad

Las fechas deben representar un día real del calendario y contener hora completa con segundos y zona explícita. El año debe quedar entre `1000` y `9999`, también después de convertir a UTC. Se acepta `Z` para UTC o un desplazamiento como `-06:00`; la fracción de segundo es opcional y admite de uno a tres dígitos. El desplazamiento máximo es `14:00`. Ejemplos válidos:

```text
2026-11-10T14:00:00Z
2026-11-10T08:00:00-06:00
2026-11-10T14:00:00.123Z
```

Los dos primeros ejemplos representan el mismo instante. `fin` debe ser estrictamente posterior a `inicio`. Se rechazan fechas imposibles, fechas sin zona, periodos incompletos y horas sin segundos. La consulta del catálogo permite revisar periodos pasados; la regla de inicio futuro se aplicará al crear reservas en una fase posterior.

Codifica los valores al construir una URL. Un `+` de un desplazamiento horario debe enviarse como `%2B`; en PowerShell puede usarse `[Uri]::EscapeDataString($valor)`.

Una reserva bloquea disponibilidad únicamente cuando su estado es `confirmada` o `en_curso` y se cumplen ambas comparaciones:

```text
inicio_solicitado < fin_reserva_existente
fin_solicitado > inicio_reserva_existente
```

Los extremos contiguos son válidos: una reserva que termina exactamente cuando empieza la consulta no la bloquea. Las reservas canceladas, completadas o marcadas como no presentado no bloquean estas consultas.

La disponibilidad es informativa y puede cambiar tras la respuesta. Consultar el catálogo no crea una reserva, no fija una tarifa ni impide que otro cliente reserve. La creación de reservas deberá volver a comprobar el periodo dentro de una transacción.

## Errores

| HTTP | Código | Cuándo aparece |
| --- | --- | --- |
| `400` | `VALIDATION_ERROR` | Identificador o parámetro fuera del contrato, rango incoherente o periodo inválido. |
| `404` | `VEHICLE_NOT_FOUND` | El detalle no corresponde a un vehículo visible. |
| `503` | `DATABASE_UNAVAILABLE` | No se puede completar la consulta a MySQL. |
| `500` | `INTERNAL_SERVER_ERROR` | Se produce un fallo inesperado. |

Las respuestas controladas usan la misma envoltura del resto de la API:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Mensaje que explica el dato que debes corregir."
  }
}
```

El texto anterior ilustra la forma; el mensaje concreto depende del campo. Las respuestas no exponen SQL, credenciales ni trazas internas. Una lista sin coincidencias es una respuesta correcta `200`.

La comprobación guiada en Windows está en [Fase 5: catálogo](../phase5-catalog-guide.md).
