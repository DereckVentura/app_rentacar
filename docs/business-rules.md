# Reglas iniciales de AutoRent

Reglas acordadas con el estudiante el 26 de octubre de 2026 para construir el MVP. Se validarán con la empresa si se concreta la alianza propuesta con Rent a Car Molina.

## Confirmación de reservas

Una reserva se confirma automáticamente cuando el servidor valida al cliente, los datos solicitados y la disponibilidad del vehículo. Su estado inicial es `confirmada`.

La comprobación definitiva ocurre dentro de la transacción que guarda la reserva. La lista de vehículos disponibles es informativa: otro cliente puede reservar mientras se está consultando el catálogo.

## Tiempo y disponibilidad

- Cada reserva tiene inicio y fin, con fecha y hora.
- El fin debe ser estrictamente posterior al inicio.
- La API recibirá fechas ISO 8601 con zona o desplazamiento explícito y trabajará con instantes UTC.
- Los campos `DATETIME(6)` se guardan bajo la convención UTC; MySQL no convierte automáticamente su zona horaria.
- Cada conexión de la API a MySQL deberá configurar `time_zone = '+00:00'`. Los scripts de esta fase también lo hacen.
- La app mostrará las fechas en la zona `America/El_Salvador`.
- Al crear una reserva, la API rechazará un inicio pasado usando la hora del servidor.

Los períodos se consideran de inicio incluido y fin excluido. Una reserva que termina a las 12:00 puede ser seguida por otra que empieza exactamente a las 12:00. Todavía no se incorpora un margen adicional entre reservas.

Existe solapamiento cuando se cumplen ambas condiciones:

```text
nuevo_inicio < fin_existente
nuevo_fin > inicio_existente
```

Las reservas `confirmada` y `en_curso` bloquean su período. Una reserva cancelada, completada o marcada como ausencia no bloquea un nuevo período por su estado.

El estado operativo del vehículo se guarda como `operativo`, `mantenimiento` o `inactivo`. La disponibilidad para fechas se obtiene combinando ese estado con las reservas. El estado de alquilado se conoce a partir de un alquiler abierto.

## Catálogo del cliente

El estudiante confirmó que el catálogo mostrará únicamente vehículos `operativo`. También se omiten vehículos cuya categoría, marca o ubicación esté desactivada. Las opciones de filtros incluyen categorías y marcas activas y los modelos de marcas activas, aunque una opción no tenga vehículos operativos en ese momento.

Sin un período solicitado, `disponible` se devuelve como `null`: el estado operativo no garantiza disponibilidad para cualquier fecha. Con inicio y fin, la lista conserva solo vehículos sin reservas activas que se solapen. El detalle de un vehículo operativo conserva su información y devuelve `disponible: false` si está ocupado en ese período.

La consulta acepta períodos pasados para inspeccionar disponibilidad y no crea reservas. El registro futuro de una reserva aplicará por separado la validación de inicio y el protocolo transaccional acordado. Los precios y coordenadas `DECIMAL` se envían como texto para conservar su precisión.

## Precio del alquiler

Se cobra por bloques de 24 horas, redondeando cualquier fracción hacia arriba:

```text
dias_cobrados = techo(duracion / 24 horas)
total = dias_cobrados * precio_dia_aplicado
```

| Duración | Días cobrados |
| --- | --- |
| 1 hora | 1 |
| 24 horas exactas | 1 |
| 24 horas y 1 minuto | 2 |
| 26 horas | 2 |
| 48 horas exactas | 2 |

La reserva conserva la tarifa utilizada, las unidades cobradas, el importe y la moneda. Una modificación posterior del precio del vehículo no altera una reserva existente. La moneda inicial del catálogo es USD.

Los campos monetarios usan `DECIMAL`. La futura API deberá calcular con centavos enteros o aritmética decimal y evitar errores de coma flotante. Esta fórmula representa el precio del alquiler del MVP; cualquier cargo adicional necesitará una regla y un modelo explícitos antes de incorporarse.

## Cancelación del cliente

El cliente puede cancelar gratuitamente una reserva propia que siga en estado `confirmada` si la hora actual del servidor es estrictamente anterior a `inicio_utc`.

En el instante exacto de inicio ya no se permite la cancelación del cliente. El servidor comprobará nuevamente la hora y el estado dentro de la transacción. La cancelación conserva el registro histórico y guarda su fecha; el motivo puede ser opcional.

El importe original se conserva como dato de la reserva. El estado `cancelada` indica que la reserva ya no se ejecutará; ese importe no representa un cobro ni una deuda de cancelación.

## Entrega y devolución

La entrega registra un alquiler asociado a una reserva confirmada. Una reserva puede tener como máximo un alquiler. La API comprobará que la persona que registra la operación tenga rol administrador y que el vehículo no tenga otro alquiler abierto.

La salida real, el kilometraje inicial y el administrador que entrega quedan registrados. El cambio de la reserva a `en_curso` y la creación del alquiler se realizan en una sola transacción.

Al devolver el vehículo se registran juntos la fecha real, el kilometraje final y el administrador que recibe. El kilometraje final no puede ser menor que el inicial. La misma transacción actualiza el alquiler, completa la reserva y actualiza el kilometraje y la ubicación del vehículo.

Un alquiler abierto bloquea una nueva entrega del mismo vehículo. Los retrasos no cambian automáticamente las reservas posteriores. Los cargos por retraso y las excepciones administrativas se definirán antes de implementar esas operaciones.

## Protocolo contra reservas simultáneas

Toda operación que modifique el calendario de un vehículo seguirá este orden en la misma conexión a MySQL:

1. Iniciar una transacción.
2. Bloquear la fila del vehículo con `SELECT ... FOR UPDATE`.
3. Comprobar las condiciones de la operación: al reservar, vehículo operativo y cliente autorizado; al cancelar, propiedad de la reserva, estado confirmado y hora anterior al inicio.
4. Si se crea una reserva o se modifica su período o vehículo, consultar otras reservas activas que se solapen mediante una lectura actual con `FOR UPDATE`. Al modificar, excluir la propia reserva de esa consulta. La cancelación no necesita comprobar solapamientos.
5. Rechazar un nuevo período si existe conflicto; si se cumplen las condiciones de la operación, guardar el cambio y su notificación.
6. Confirmar la transacción; ante un error, revertirla.

Bloquear primero el vehículo protege también el caso en el que todavía no existe ninguna reserva. Un índice de fechas acelera las consultas, pero no impide por sí mismo que dos filas representen períodos solapados.

La creación, cancelación y cualquier futura extensión o reasignación deben compartir este protocolo. Cuando intervengan varios vehículos, sus filas se bloquearán en orden de identificador para reducir interbloqueos.

## Usuarios e historial

El registro público creará usuarios con rol `cliente`. La asignación del rol `administrador` será una operación controlada del servidor. La API verificará que el cliente de una reserva tenga el rol correspondiente; una clave foránea por sí sola solo comprueba que el usuario existe.

Las contraseñas se procesarán con bcrypt en la fase de autenticación y se guardará solo su hash. Esta fase no crea cuentas con credenciales de demostración.

Vehículos, usuarios y elementos de catálogo relacionados con operaciones históricas se desactivarán cuando corresponda. Las claves foráneas restringen borrados que destruirían esas relaciones.

## Notificaciones

El servidor guardará confirmaciones y cambios asociados a cada usuario. La app consultará esos avisos en la API y podrá mostrar notificaciones locales cuando los reciba. Los avisos de cambios remotos con la app cerrada requerirían incorporar push o correo en su fase de implementación.
