# Diccionario de datos

Estructura comprobada en la base de demostración. No contiene registros de usuarios. Los importes DECIMAL se manejan como cadenas y las fechas de operación se interpretan en UTC.


## alquileres

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | int unsigned | NO | PRI |
| reserva_id | int unsigned | NO | UNI |
| salida_real_utc | datetime(6) | NO | — |
| devolucion_real_utc | datetime(6) | YES | — |
| km_salida | int unsigned | NO | — |
| km_regreso | int unsigned | YES | — |
| entregado_por | int unsigned | NO | MUL |
| recibido_por | int unsigned | YES | MUL |
| observaciones_salida | text | YES | — |
| observaciones_devolucion | text | YES | — |

## api_rate_limits

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| key_hash | char(64) | NO | PRI |
| window_start | bigint unsigned | NO | PRI |
| requests | int unsigned | NO | — |

## audit_events

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | bigint unsigned | NO | PRI |
| actor_id | int unsigned | NO | MUL |
| entity_type | varchar(40) | NO | MUL |
| entity_id | int unsigned | NO | — |
| action | varchar(60) | NO | — |
| created_at | datetime(6) | NO | — |

## business_content

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | tinyint unsigned | NO | PRI |
| contenido | json | NO | — |
| actualizado_en | datetime(6) | NO | — |

## categorias

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | int unsigned | NO | PRI |
| nombre | varchar(80) | NO | UNI |
| descripcion | text | YES | — |
| activo | tinyint(1) | NO | — |

## legal_acceptances

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | bigint unsigned | NO | PRI |
| usuario_id | int unsigned | NO | MUL |
| reserva_id | int unsigned | YES | MUL |
| contexto | enum('registro','reserva') | NO | — |
| version | char(64) | NO | — |
| documentos | json | NO | — |
| aceptado_en | datetime(6) | NO | — |

## marcas

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | int unsigned | NO | PRI |
| nombre | varchar(80) | NO | UNI |
| activo | tinyint(1) | NO | — |

## modelos

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | int unsigned | NO | PRI |
| marca_id | int unsigned | NO | MUL |
| nombre | varchar(80) | NO | — |

## notificaciones

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | int unsigned | NO | PRI |
| usuario_id | int unsigned | NO | MUL |
| reserva_id | int unsigned | YES | MUL |
| titulo | varchar(150) | NO | — |
| mensaje | text | NO | — |
| creada_en | datetime(6) | NO | — |
| leida_en | datetime(6) | YES | — |

## privacy_requests

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | bigint unsigned | NO | PRI |
| usuario_id | int unsigned | NO | MUL |
| tipo | enum('acceso','rectificacion','supresion','oposicion','portabilidad','olvido','limitacion','retiro_consentimiento','reclamo') | NO | — |
| detalle | varchar(2000) | NO | — |
| estado | enum('recibida','en_revision','respondida') | NO | MUL |
| respuesta | varchar(3000) | YES | — |
| respondida_por | int unsigned | YES | MUL |
| creado_en | datetime(6) | NO | — |
| actualizado_en | datetime(6) | NO | — |

## reservas

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | int unsigned | NO | PRI |
| codigo | varchar(24) | NO | UNI |
| cliente_id | int unsigned | NO | MUL |
| vehiculo_id | int unsigned | NO | MUL |
| entrega_id | int unsigned | NO | MUL |
| devolucion_id | int unsigned | NO | MUL |
| inicio_utc | datetime(6) | NO | — |
| fin_utc | datetime(6) | NO | — |
| estado | enum('confirmada','en_curso','completada','cancelada','no_presentado') | NO | — |
| precio_dia_aplicado | decimal(10,2) | NO | — |
| unidades_cobradas | int unsigned | NO | — |
| total | decimal(12,2) | NO | — |
| moneda | char(3) | NO | — |
| cancelada_en | datetime(6) | YES | — |
| motivo_cancelacion | varchar(500) | YES | — |
| creado_en | datetime(6) | NO | — |
| actualizado_en | datetime(6) | NO | — |

## schema_migrations

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| version | varchar(80) | NO | PRI |
| checksum | char(64) | NO | — |
| applied_at | datetime(6) | YES | — |

## ubicaciones

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | int unsigned | NO | PRI |
| nombre | varchar(120) | NO | — |
| tipo | enum('sucursal','punto_autorizado') | NO | — |
| direccion | varchar(255) | NO | — |
| latitud | decimal(10,7) | NO | — |
| longitud | decimal(10,7) | NO | — |
| activo | tinyint(1) | NO | — |

## usuarios

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | int unsigned | NO | PRI |
| nombres | varchar(100) | NO | — |
| apellidos | varchar(100) | NO | — |
| email | varchar(254) | NO | UNI |
| password_hash | varchar(255) | NO | — |
| telefono | varchar(25) | YES | — |
| rol | enum('cliente','administrador') | NO | — |
| activo | tinyint(1) | NO | — |
| creado_en | datetime(6) | NO | — |
| actualizado_en | datetime(6) | NO | — |

## vehiculos

| Campo | Tipo | Nulo | Clave |
|---|---|---|---|
| id | int unsigned | NO | PRI |
| placa | varchar(20) | YES | UNI |
| categoria_id | int unsigned | NO | MUL |
| modelo_id | int unsigned | NO | MUL |
| ubicacion_actual_id | int unsigned | YES | MUL |
| anio | smallint unsigned | NO | — |
| kilometraje | int unsigned | YES | — |
| precio_dia | decimal(10,2) | YES | — |
| estado_operativo | enum('operativo','mantenimiento','inactivo') | NO | — |
| descripcion | text | YES | — |
| imagen_url | varchar(2048) | YES | — |
| creado_en | datetime(6) | NO | — |
| actualizado_en | datetime(6) | NO | — |
| codigo_interno | varchar(64) | YES | UNI |
| publicado | tinyint(1) | NO | — |
| ficha | json | YES | — |
