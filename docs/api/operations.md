# API de reservas y operaciones

Todas las rutas están bajo `/api/v1`. Las respuestas usan `{success:true,data:...}` o `{success:false,error:{code,message}}`. Las rutas privadas requieren `Authorization: Bearer TOKEN`. Los DECIMAL se devuelven como texto y las fechas de reservas como ISO UTC. No hay rutas públicas para asignar roles.

| Método y ruta | Acceso | Resultado |
|---|---|---|
| GET `/locations` | Público | `locations` activas |
| POST `/reservations/quote` | Cuenta | Cotización, días cobrados, tarifa y total |
| POST `/reservations` | Cliente | `reservation`, `replayed` |
| GET `/reservations?page=1&limit=20&estado=confirmada` | Cuenta | Propias para cliente; todas para administrador; `pagination` |
| GET `/reservations/:id` | Propietario/admin | `reservation` |
| POST `/reservations/:id/cancel` | Propietario/admin | `reservation` cancelada |
| POST `/admin/reservations/:id/checkout` | Admin | Entrega y cambio a `en_curso` |
| POST `/admin/reservations/:id/return` | Admin | Devolución y cambio a `completada` |
| GET `/notifications?page=1&limit=20` | Cuenta | `notifications`, `unread`, `page`, `limit` |
| POST `/notifications/:id/read` | Propietario | Marca lectura sin duplicarla |
| GET/POST `/admin/locations` | Admin | Lista completa / crea ubicación |
| PUT `/admin/locations/:id` | Admin | Actualiza todos sus campos; desactivar conserva historial |
| POST `/admin/media/signature` | Admin | Firma SHA256 para subida HTTPS; 503 si no está configurado |

Cotizar y reservar reciben `vehiculo_id`, `entrega_id`, `devolucion_id`, `inicio`, `fin`. Inicio y fin contienen segundos y zona explícita. Máximo 365 días. Para crear, incluir además `precio_confirmado` como tarifa decimal con dos cifras e `Idempotency-Key` de 16–80 caracteres alfanuméricos, guion o guion bajo. La tarifa debe coincidir con la cotizada. La respuesta inicial es 201 y la repetición del mismo intento 200. Reusar la clave con otra unidad o período produce 409.

La cancelación acepta `{motivo:null}` o texto de hasta 500 caracteres; repetir la cancelación es idempotente. La entrega acepta `{kilometraje:12345,observaciones:null}`. La devolución agrega `ubicacion_id`. El cliente no puede cancelar desde la hora exacta de inicio; el administrador puede cancelar una reserva todavía confirmada. Ninguno puede cancelar un alquiler en curso para eludir su devolución.

Ubicaciones: `nombre`, `tipo` (`sucursal` o `punto_autorizado`), `direccion`, `latitud` y `longitud` como texto decimal de hasta siete cifras decimales, `activo` booleano.

Los códigos relevantes incluyen `RESERVATION_CONFLICT`, `PRICE_CHANGED`, `VEHICLE_INCOMPLETE`, `INVALID_STATE`, `CHECKOUT_TIME`, `OPEN_RENTAL`, `INVALID_MILEAGE`, `ACTIVE_RESERVATIONS` y `RETRY_OPERATION`. Un conflicto de fechas o estado devuelve 409; datos inválidos 400; falta de acceso 401/403; recurso ajeno 404. Un error de base devuelve 503 sin SQL ni credenciales. Un error de red al crear no demuestra que la reserva haya fallado: reintentar con la misma clave o leer el historial.

Registro y acceso comparten 30 intentos por ventana de 15 minutos e IP. En el servidor principal el contador está en MySQL y se comparte entre instancias. Respuesta 429 incluye `Retry-After`. Configurar solo el número de proxies confiables de la infraestructura; no aceptar direcciones remitidas por clientes directos como si fueran proxies.
