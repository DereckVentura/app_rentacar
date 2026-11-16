# Alojamiento gratuito y crecimiento de AutoRent

La aplicación mantiene Flutter, Express y MySQL. El código no depende de una sola empresa de alojamiento. Las imágenes nuevas van a almacenamiento externo y las reservas y límites de acceso se comparten en MySQL, de modo que varias instancias de la API puedan trabajar sobre los mismos datos.

## Opción inicial sin cuota mensual

| Parte | Servicio | Consideración |
|---|---|---|
| API | Render Web Service, plan Free | Se suspende después de 15 minutos sin tráfico; el primer acceso puede tardar alrededor de un minuto. El disco local no conserva archivos subidos. |
| Base de datos | Aiven for MySQL, Free | Capacidad pequeña: 1 GB de almacenamiento, 1 GB de memoria y una CPU según el plan consultado. Mantener TLS y vigilar capacidad. |
| Nuevas fotos | Cloudinary Free | Usar las cuotas gratuitas disponibles y vigilar consumo. Las seis fotos iniciales están incluidas en el contenedor. |
| App | APK Android | El teléfono se conecta directamente a la API HTTPS; no hace falta alojar una página web para usar Android. |
| Web opcional | Un alojamiento de archivos estáticos | Publicar el contenido de `mobile/build/web` y habilitar su origen exacto en `CORS_ORIGINS`. |

Los planes gratuitos no ofrecen el mismo servicio que un alojamiento de producción con capacidad y disponibilidad contratadas. Los límites pueden cambiar: comprobar [Render Free](https://render.com/docs/free), [Aiven Free MySQL](https://aiven.io/docs/products/mysql/concepts/mysql-free-tier) y [Cloudinary Plans](https://cloudinary.com/documentation/billing_and_plans) antes de activar las cuentas. Nunca seleccionar una mejora de pago automáticamente.

## Preparar las cuentas y publicar

Estos pasos requieren que el propietario tenga acceso a sus cuentas; no se guardan sus contraseñas en el repositorio.

1. Crear un repositorio privado con el código, excluyendo `.env`, respaldos, llaves y los resultados de compilación. `Dockerfile` y `render.yaml` deben quedar en la raíz del repositorio.
2. Crear MySQL Free en Aiven. Conservar el host, puerto, nombre de base, usuario y contraseña de conexión. Descargar su certificado CA. La base proporcionada puede llamarse `defaultdb`; usar ese valor en `DB_NAME`.
3. En una configuración **local y privada** de conexión para la nube, establecer `DB_SSL=true`, los datos de Aiven y `DB_SSL_CA_BASE64` con el certificado CA convertido a base64. La comprobación de identidad TLS permanece activada.
4. Aplicar las migraciones con una cuenta autorizada para modificar la estructura:

   ```powershell
   cd backend
   node scripts/migrate.mjs
   ```

   En base nueva crea las tablas y la categoría SUV; no carga vehículos ficticios. En una instalación existente verifica las fases 001 y 002 y registra su adopción. Conserva las sumas SHA-256 de las migraciones y usa un bloqueo para impedir que dos despliegues migren a la vez. MySQL confirma las operaciones de estructura por separado; si una migración se interrumpe, revisar el esquema o restaurar antes de continuar.

5. Si se trata de una base nueva, cargar **una sola vez** la flota inicial con `node dist/scripts/import-real-fleet.js`. No repetir este importador durante actualizaciones rutinarias: su propósito es establecer el catálogo inicial de tres unidades, y oculta otras unidades previas. Para crecer se usa la administración de la app.
6. Crear Cloudinary Free y configurar `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` en el servidor. El secreto nunca se envía a Flutter. El administrador pide una firma breve y sube las fotos directamente por HTTPS. [Contrato oficial de firmas](https://cloudinary.com/documentation/authentication_signatures).
7. Crear el servicio de Render a partir de `render.yaml` y completar las variables solicitadas. Generar `JWT_SECRET` localmente como 32 bytes aleatorios en base64url (43 caracteres). No usar una contraseña personal como clave. Ejemplo local:

   ```powershell
   node -e "console.log(require('node:crypto').randomBytes(32).toString('base64url'))"
   ```

   Guardar el resultado directamente en los secretos del servicio. `HOST=0.0.0.0`, `NODE_ENV=production`, `TRUST_PROXY_HOPS=1` y `DB_POOL_SIZE=5` ya están previstos. `PORT` lo proporciona Render. Si se ejecuta sin proxy, usar `TRUST_PROXY_HOPS=0`.
8. Comprobar por HTTPS `/api/v1/health/database` y `/api/v1/vehicles`: respuesta correcta de MySQL y tres unidades. No se considera publicada hasta comprobar estas direcciones en el servicio real.
9. Compilar Flutter usando la URL pública definitiva:

   ```powershell
   flutter build apk --release --dart-define=API_BASE_URL=https://TU-SERVICIO.onrender.com/api/v1
   flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=https://TU-SERVICIO.onrender.com/api/v1
   ```

   Configurar antes la firma Android propia siguiendo `mobile/README.md`. El instalador de desarrollo usa el emulador y no sirve para un teléfono remoto sin cambiar la URL. Nunca colocar secretos MySQL o Cloudinary dentro de `--dart-define`.
10. Registrar una cuenta desde la app. Promover únicamente la cuenta del propietario con `node dist/scripts/promote-user.js --email "correo registrado"` desde una conexión privada a esa base. No existe registro público de administradores.
11. Ingresar como administrador, agregar las ubicaciones reales y completar placa, tarifa y kilometraje de las unidades. Crear una reserva de prueba con una cuenta cliente; comprobar su entrega, devolución y aviso. Subir una foto para verificar también el almacenamiento externo.

## Respaldos y traslado a otro servidor

Crear un respaldo antes de cada migración y hacer copias periódicas fuera del equipo y del proveedor. `node scripts/backup.mjs` usa la conexión privada del entorno y escribe un SQL en `backups/`; no muestra la contraseña. Requiere `mysqldump` instalado y conserva una instantánea consistente de las tablas InnoDB. No ejecutar durante cambios de estructura. El respaldo contiene información de los clientes: conservarlo en almacenamiento privado y comprobar su restauración.

Para trasladar la aplicación:

1. Detener temporalmente las escrituras en el servicio anterior y crear un respaldo final. Guardar también variables privadas y configuración de imágenes en un gestor seguro.
2. Crear una base nueva compatible con MySQL 8.4 y restaurar el SQL allí con una cuenta de migraciones. La restauración se realiza en una base vacía o un destino revisado; no ejecutar un volcado sobre datos útiles sin preparar la recuperación.
3. Aplicar solo migraciones pendientes y ejecutar las verificaciones de salud, catálogo, acceso y operaciones. No ejecutar el importador inicial sobre la base restaurada.
4. Desplegar el mismo contenedor de la API apuntando a la nueva base mediante variables. Mantener la misma clave JWT si se desea conservar sesiones, o rotarla para pedir acceso de nuevo.
5. Conservar el mismo dominio público cuando sea posible. Si cambia la URL de la API, recompilar la app y distribuir la actualización. Actualizar CORS si cambia la dirección web.
6. Comprobar el sistema nuevo y luego retirar el anterior. Si hay que volver atrás, impedir escrituras simultáneas en ambas bases y recuperar los cambios ocurridos desde el respaldo; cambiar una dirección por sí solo no sincroniza datos.

## Cómo aumentar capacidad

Primero mejorar MySQL, las copias y la disponibilidad de la API. El diseño permite añadir réplicas de la API porque no guarda sesiones ni fotos subidas en su disco. Todas deben usar la misma base primaria y `JWT_SECRET`; no enviar operaciones de reservas a una réplica de lectura con retraso.

El límite total de conexiones es la suma de `DB_POOL_SIZE` de todas las réplicas más las herramientas de administración. Ajustarlo a la capacidad contratada. Los listados usan páginas de hasta 100 elementos y los cálculos monetarios se hacen con centavos enteros. El bloqueo por vehículo mantiene la exclusión de reservas entre instancias.

Medir tiempos de respuesta, errores, espera de conexiones y uso de disco antes de aumentar tráfico. Las pruebas de seis intentos simultáneos verifican la protección funcional; no representan una certificación de capacidad para miles de usuarios. Antes de ese volumen, hacer pruebas de carga con el alojamiento real y ajustar índices, límites y recursos según lo medido.

Para mapas de uso amplio, contratar un proveedor de teselas con capacidad apropiada o alojarlo, manteniendo atribución. La dirección de teselas puede cambiarse al compilar con `MAP_TILE_URL`; no realizar descargas masivas o uso sin conexión contra los servidores públicos de OpenStreetMap. [Política oficial de teselas](https://operations.osmfoundation.org/policies/tiles/).
