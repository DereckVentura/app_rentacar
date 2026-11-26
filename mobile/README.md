# Aplicación AutoRent

Flutter 3.47.8 / Dart 3.13.7. Pantallas aprobadas por el propietario: catálogo, filtros, detalle y galería, acceso y registro, reserva y total, historial y cancelación, avisos, mapa y administración de flota, ubicaciones, entregas y devoluciones. Tema negro y dorado con Inter incluida en el paquete.

## Desarrollo

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d edge --web-port=8080 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

Mantener la API y MySQL iniciados. El navegador debe abrirse con `http://127.0.0.1:8080` o agregar su origen exacto a `CORS_ORIGINS`. En emulador Android la URL predeterminada es `http://10.0.2.2:3000/api/v1`; la variante debug permite HTTP para desarrollo. Para un teléfono real usar una URL alcanzable desde ese teléfono; la versión pública usa HTTPS.

## Compilar

```powershell
flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=https://TU-SERVICIO/api/v1
flutter build apk --debug
```

La web se genera en `build/web`; el APK debug en `build/app/outputs/flutter-apk/app-debug.apk`. El APK de desarrollo apunta al emulador si no se define otra URL y no representa una app publicada.

Para un instalador firmado propio, ejecutar **una sola vez** desde la raíz del proyecto:

```powershell
node backend/scripts/setup-android-signing.mjs
```

La herramienta genera una llave privada y contraseña aleatoria que conserva en `android/.private/autorent-upload.jks` y `android/key.properties`. No los muestra y no reemplaza llaves anteriores. Respaldar ambos en un lugar privado antes de distribuir la app: las actualizaciones futuras deben mantener la firma. No subirlos al repositorio ni al alojamiento web. Luego:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://TU-SERVICIO/api/v1
```

El APK release se genera en `build/app/outputs/flutter-apk/app-release.apk`. La configuración evita firmar una versión release accidentalmente con la llave de debug. Antes de compartirla, verificar registro, acceso, reserva, cancelación y operaciones con la API pública.

## Estructura y configuración

- `lib/core`: cliente HTTP, sesión segura, colores, tema y tipografía.
- `lib/features`: pantallas de catálogo, acceso, reservas, ubicaciones, cuenta y administración.
- `lib/shared/widgets`: campos, botones, tarjetas, formularios y estados de carga/error reutilizables.
- `assets/fonts`: Inter con su licencia OFL. No requiere descargar fuentes al abrir la app.
- `test`: comprobaciones de zona horaria, manejo de sesión, catálogo y acceso.

`API_BASE_URL` cambia el servidor sin modificar código. Nunca introducir secretos de MySQL o Cloudinary en la app. `MAP_TILE_URL` permite cambiar las teselas del mapa al compilar. Los puntos se leen de la API; no se inventan coordenadas de sucursales.

Los tokens se guardan con `flutter_secure_storage`. La sesión se valida contra el servidor al restaurarse y requiere ingresar de nuevo si expiró. Para web se necesita HTTPS o localhost.

AutoRent 0.4.1 usa el flujo de reservas de la API v3. La pantalla de cuenta permite activar avisos en segundo plano en Android cuando el servidor tiene configurado Firebase Cloud Messaging. El centro de avisos dentro de la app también funciona con el sondeo de la API.
