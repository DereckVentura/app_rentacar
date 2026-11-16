# AutoRent

### Reservas con validación administrativa

Las solicitudes nuevas quedan `pendiente` durante tres horas desde su creación. El administrador las confirma con **Validar reserva**. Al vencer el plazo pasan a `vencida`, salen de las reservas activas y liberan el calendario; se conserva el registro para el historial y los reintentos. Las reservas confirmadas anteriormente conservan su estado.

El calendario resalta el rango seleccionado en dorado. En **Administración** se editan los datos de pago (banco, titular, número y tipo de cuenta e instrucciones) y los puntos de entrega (nombre, dirección, coordenadas y estado).

La instalación Express/MySQL requiere aplicar `database/migrations/006_booking_validation.sql` mediante `npm run db:migrate` antes de reiniciar la API. El asistente `actualizar-autorent.ps1` crea un respaldo y ejecuta las migraciones. La versión Sites guarda los datos de pago en `settings` y usa las tablas existentes, sin otra migración.

Pruebas específicas desde la raíz:

```powershell
node --import ./backend/node_modules/tsx/dist/loader.mjs --test sites/autorent/lib/pending-reservations.test.ts sites/autorent/lib/availability.test.ts backend/tests/payment.test.ts backend/tests/booking.test.ts
```

Aplicación de alquiler de vehículos Flutter para Android y web, API Express/TypeScript y MySQL 8.4. Diseño negro y dorado aprobado por el propietario.

Flota: Outlander gris (P 43 9C5) y roja (P 37 DE9), ambas a USD 40 por día; Rogue gris (P 15 F44), a USD 35 por día. Las reservas requieren una licencia de conducir vigente y no permiten cruces de fechas.

## Funciones implementadas

Catálogo con fotos y filtros, registro y acceso con sesión segura, detalle de unidades, cotización, reservas con control de cruces de fechas, historial y cancelación, mapa de ubicaciones, avisos persistentes y administración de vehículos, ubicaciones, entregas y devoluciones. El administrador puede agregar más unidades sin modificar el código. Las contraseñas se procesan con bcrypt, los roles se validan contra MySQL y los cambios de una reserva y sus avisos se guardan juntos.

## Abrir la instalación local

La actualización agrega dos tablas para límites de acceso compartidos y auditoría. Primero crear el respaldo y aplicar esa estructura con el asistente; no se repite la flota inicial ni se elimina el historial:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Ventura\OneDrive\Documentos\ChatGPT\AutoRent\actualizar-autorent.ps1"
```

El asistente solicita la contraseña de MySQL root en la consola si faltan las tablas. No enviarla por chat. La excepción de ejecución afecta únicamente este proceso de PowerShell. Si falla un paso, el asistente se detiene y conserva el respaldo.

Luego abrir `iniciar-servidor.cmd` y `abrir-app.cmd`, y visitar http://127.0.0.1:8080. La API usa el puerto 3000. Mantener ambas ventanas abiertas. Si ya hay una API escuchando en el puerto 3000, reiniciarla antes de abrir otra. MySQL debe estar iniciado.

La aplicación Android se prepara según [mobile/README.md](mobile/README.md). El instalador de desarrollo se conecta al emulador; para un teléfono remoto es necesario configurar la URL pública HTTPS y compilarlo con esa dirección.

## Guías

- [Uso del cliente y la administración](docs/user-guide.md).
- [Alojamiento gratuito, publicación, respaldos y crecimiento](docs/hosting-and-scaling.md).
- [App Flutter y firma Android](mobile/README.md).
- [Reglas del negocio](docs/business-rules.md) y [modelo de datos](docs/database-model.md).
- [API de reservas, alquileres, ubicaciones y avisos](docs/api/operations.md).
- [API de acceso](docs/api/auth.md), [catálogo](docs/api/vehicles.md) y [salud](docs/api/health.md).
- [Flota y referencias técnicas](docs/real-fleet.md).
- [Propuesta visual aprobada](docs/visual-proposal.md).

## Desarrollo y despliegue

```powershell
cd backend
npm ci
npm run typecheck
npm test
npm run build
```

`npm run db:migrate` aplica migraciones en una base nueva o verifica una existente usando una cuenta con permisos de estructura. En producción ejecutar esa tarea separada del inicio de la API. `npm run fleet:import` es únicamente para establecer la flota inicial; no repetirlo en las actualizaciones habituales porque ocultaría otras unidades añadidas posteriormente.

La configuración privada está en `backend/.env`; usar `.env.example` como plantilla para una instalación nueva. Las fotos nuevas usan Cloudinary y la conexión a MySQL en nube admite TLS con verificación de identidad. `Dockerfile`, `compose.yaml`, `render.yaml` y `.github/workflows/verify.yml` preparan contenedores y comprobaciones continuas. Nunca publicar `.env`, respaldos ni llaves de firma.

El cambio de alojamiento conserva la API y MySQL: trasladar la base, cambiar variables y conservar el dominio o actualizar la URL de la app. El alojamiento público requiere conectar las cuentas del propietario y verificar sus direcciones reales. Los archivos preparados no significan que ya esté publicada.

Las guías de fases anteriores se conservan en [previous-phases.md](docs/previous-phases.md) como referencia histórica; sus datos de demostración y pendientes no describen esta entrega.
