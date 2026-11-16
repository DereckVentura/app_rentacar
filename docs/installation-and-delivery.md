# Instalación y archivos de entrega

## Demostración universitaria en este equipo

Abre iniciar-demo.cmd en la raíz del proyecto. El primer inicio prepara una base propia; los siguientes conservan lo que edites. La web está en http://127.0.0.1:8082 y el servicio en http://127.0.0.1:3002/api/v1. El iniciador abre el navegador cuando termina de comprobar el arranque.

Los accesos de administrador y cliente están en backend/.private/ACCESOS-DEMO.txt. Se generan en este equipo y no se imprimen en los registros. No los incluyas en el informe, las capturas o el repositorio. Para terminar la presentación basta cerrar la ventana; los servicios locales siguen funcionando hasta detenerlos o apagar el equipo.

La demostración utiliza MySQL 8.4 en 127.0.0.1:3319 y base autorent_demo. Sus archivos están en .local/mysql-demo; su configuración privada está en backend/.private/demo.json. No usa backend/.env ni modifica la base existente del puerto 3306. No copies la carpeta de datos MySQL mientras esté encendida como sustituto de un respaldo lógico.

Node.js 24 y MySQL 8.4 deben estar instalados. El iniciador utiliza las rutas encontradas en este equipo. En otro equipo, instala las herramientas y ajusta AUTORENT_MYSQL_HOME o las rutas si son diferentes. El código fuente Flutter necesita su SDK para volver a compilar, pero la web ya compilada se sirve con Node.js.

## Base preexistente

La base del trabajo anterior conserva sus credenciales en backend/.env. Para aplicar las tablas nuevas, utiliza PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\actualizar-autorent.ps1"
```

El script crea un respaldo, solicita localmente la contraseña administrativa de MySQL y ejecuta las migraciones pendientes. La excepción de ejecución solo afecta ese proceso. No cambies la política global del equipo y no publiques la contraseña. La cuenta de conexión de la API tiene permisos de datos; no puede crear tablas por sí misma.

Las cuentas de demostración no se crean en la base existente. Para habilitar un administrador allí, registrar una cuenta propia y utilizar el comando de promoción documentado del backend con autorización del responsable. No promover cuentas de clientes por semejanza de nombre.

La web entregada se compila para el servidor de demostración del puerto 3002. Para utilizar la base existente mediante su API del puerto 3000 o publicar en internet, volver a compilar con API_BASE_URL correspondiente. No asumir que abrir otra API cambia la dirección de una web ya compilada.

## Compilación

Backend: en backend, ejecutar npm ci, npm run typecheck, npm test y npm run build. Para una instalación nueva configurar las variables de .env.example, aplicar npm run db:migrate y cargar la flota una sola vez. Las dependencias se fijan en package-lock.json.

Web, desde mobile:

```powershell
flutter pub get
flutter analyze --fatal-infos
flutter test --no-pub
flutter build web --no-pub --no-wasm-dry-run --no-web-resources-cdn --dart-define=API_BASE_URL=http://127.0.0.1:3002/api/v1
```

Android de prueba para un emulador de este equipo:

```powershell
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:3002/api/v1
```

10.0.2.2 es una dirección especial del emulador Android, no la de un teléfono real. Una entrega para teléfonos reales debe usar la dirección HTTPS pública verificada. La compilación release requiere la llave privada configurada; no se debe compartir key.properties ni el almacén de firma. Una compilación debug sirve para la evaluación y no se presenta como publicación en una tienda.

## Archivos que se pueden compartir

- Informe Word y PDF, manuales, diagramas y evidencia sin datos personales.
- Código fuente, migraciones, fotos autorizadas y archivos de bloqueo de dependencias.
- Configuración de ejemplo, Dockerfile y guías de despliegue sin secretos.

No compartir backend/.env, backend/.private, .local, backups, mobile/android/key.properties, mobile/android/.private, node_modules ni archivos de contraseñas. La carpeta entregables contendrá una copia para la universidad que excluye esos archivos. Revisar de nuevo el contenido antes de compartirlo si se agregan nuevos documentos.

## Incidencias comunes

Si el inicio informa puerto ocupado, comprobar qué servicio está usando 3002, 8082 o 3319; no detener MySQL84 ni borrar bases como solución automática. Si no hay vehículos, comprobar la conexión de la API y que el importador inicial se completó. Si el catálogo dice tarifa pendiente, ese es el estado esperado hasta recibir datos o preparar datos ficticios para una demostración.

Si una reserva recibe conflicto, volver a consultar fechas. Si cambió la tarifa o la versión de los documentos, revisar de nuevo el resumen y las casillas. Si una función de privacidad falla en la base existente, comprobar que se aplicó 004_privacy.sql mediante el ejecutor de migraciones. Consultar los registros locales sin publicar contraseñas ni datos de clientes.
