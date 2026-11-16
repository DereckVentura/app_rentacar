# Diseño técnico de AutoRent

## Estructura

mobile/lib/core contiene cliente HTTP, sesión, almacenamiento y tema. features contiene catálogo, acceso, reservas, ubicaciones, cuenta, administración y ayuda y privacidad. shared/widgets contiene controles y estructuras reutilizables. El cliente valida para orientar al usuario; el servidor vuelve a validar sin confiar en la interfaz.

backend/src/routes declara endpoints y permisos. controllers adapta HTTP a operaciones. validators rechaza campos y formatos no permitidos. services representa autenticación, contraseñas, tokens y contenido legal. repositories contiene acceso a MySQL. config valida entorno, conexión, TLS y despliegue. No se almacenan secretos de servicios en Flutter.

## Estados

Reserva: confirmada → en_curso → completada. Una reserva confirmada puede pasar a cancelada; se conserva su historial. El esquema admite no_presentado pero no hay automatismo que lo asigne. Solo administración registra salida y devolución. Las reservas que están en curso siguen bloqueando una nueva entrega mientras el vehículo no haya regresado, aunque su hora prevista haya pasado.

Vehículo: operativo, mantenimiento o inactivo según los valores del validador. Publicado es un atributo independiente. Una unidad puede conservarse en historial y ocultarse del catálogo. Los cambios que afectarían una reserva activa se rechazan. No se eliminan arbitrariamente relaciones de alquiler para editar una ficha.

Solicitud: recibida → en_revision o respondida. Una nueva respuesta sustituye la respuesta visible y registra una acción de auditoría; no se implementó un historial completo del texto de todas las respuestas. La constancia del registro y de la aceptación de documentos sí conserva el texto aceptado. Una solicitud tiene límites de longitud y máximo diez altas por cuenta al día.

## Seguridad aplicada

Contraseñas bcrypt con costo 12, longitud mínima de 15 caracteres y límite de 72 bytes. Token firmado con vencimiento de una hora; el estado y rol se leen nuevamente en MySQL. Las respuestas públicas excluyen hash y secretos. El registro no permite elegir rol. Las consultas utilizan parámetros. Se fija límite de tamaño JSON, paginación, cabeceras de seguridad, no-store para la API y lista explícita de orígenes.

El límite de intentos de acceso se comparte mediante MySQL. Las firmas para carga de imágenes se generan solo para administración; la API secreta del proveedor no sale al cliente. La base de producción utiliza TLS con validación de certificado. Los archivos privados y respaldos se excluyen del repositorio. HTTPS, permisos de alojamiento, rotación de secretos y restauración deben verificarse al desplegar; el código por sí solo no comprueba su configuración efectiva.

## Integridad y errores

Una transacción bloquea el vehículo, consulta la cuenta actual y las reservas que se solapan, valida ubicaciones y precio y registra reserva, aviso, auditoría y aceptación. El orden de bloqueo consistente reduce carreras. La clave de idempotencia se deriva junto al usuario en un código y detecta intentos de reutilizarla con datos diferentes. No sustituye la validación de permiso de cada solicitud.

El intervalo se trata como inicio incluido y fin excluido. El cálculo redondea los días hacia arriba; máximo 365 días. Los estados 400 indican entradas inválidas; 401 sesión ausente o inválida; 403 falta de permiso; 404 recursos no existentes o ajenos; 409 conflicto de fechas, estado, tarifa o versión; 429 límites y 503 indisponibilidad prevista. Los errores inesperados no muestran SQL ni contraseñas.

## Migraciones y recuperación

001 define las entidades iniciales. 002 permite fichas reales incompletas y publicación selectiva. 003 añade auditoría y límites compartidos. 004 incorpora contenido, aceptaciones y solicitudes. migrate.mjs calcula huellas SHA-256, toma un bloqueo de migración y registra versiones. Adopta fases anteriores solo después de comprobar los elementos esperados. No ejecutar semillas de ejemplo en una base con datos reales.

MySQL puede confirmar DDL de forma implícita; una interrupción de una migración requiere revisar estado y respaldo. No editar un SQL cuyo checksum ya se registró. Para evolucionar el esquema agregar una versión nueva. El respaldo usa mysqldump consistente para InnoDB; comprobar restauración en otra base antes de confiar en él. Los backups contienen información privada y necesitan protección y calendario de conservación.

## Límites conocidos

La app no verifica correo ni dispone aún de recuperación autoservicio de contraseña. No hay pagos, documentos de identidad, GPS, facturación electrónica, contratos firmados, push ni varias empresas independientes. Los avisos son internos y se consultan periódicamente. La gestión de supresión y rectificación requiere un procedimiento administrativo; la pantalla de respuesta no modifica todas las entidades automáticamente. No se ejecutó prueba de carga comercial ni auditoría externa de seguridad.

Estas limitaciones son requisitos de una etapa comercial, no funciones que deban describirse como implementadas. La API y el modelo actuales sirven como base modular de una empresa. Agregar múltiples empresas necesitaría aislamiento por organización en autorización, índices, consultas, almacenamiento y pruebas.
