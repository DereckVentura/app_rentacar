# AutoRent v3 · Implementación y pruebas

## Actualización 0.4.1

- Android incorpora edición de cuenta, cambio de contraseña, recorte ajustable de fotografías, confirmación de celular, historial, comprobantes JPG y acciones administrativas de revisión y depósito. Google y las notificaciones en segundo plano dependen de la configuración de producción.
- La API admite el envío de fotos del APK anterior para revisión manual. El APK anterior usa el teléfono registrado cuando no envía uno al reservar. La web y el APK 0.4.1 aplican el encuadre de ambas fotos.
- La migración agrega columnas, tablas y disparadores. Conserva los estados históricos y mantiene las reservas antiguas en la cola de revisión según corresponda.
- Pasaron 12 pruebas unitarias web, seis pruebas Flutter y el análisis Dart. La integración en Miniflare cubrió reservas de ambas versiones, privacidad de fotos en R2, comprobante, depósito, historial, avisos y eliminación de una reserva ficticia.

El resto de este documento conserva la evidencia y los resultados del candidato 0.4.0.

## Alcance

La web candidata parte del commit público `9887846d9fad730c33ad8205867703d8e49618fa`. Su fuente está en `C:/Users/Ventura/OneDrive/Documentos/ChatGPT/AutoRent/.tmp/autorent-sites-sync-53e4015246`. La fuente Flutter está en `C:/Users/Ventura/OneDrive/Documentos/ChatGPT/AutoRent/mobile`. El servidor de producción sigue en v14.

## Cambios por fase

| Fase | Archivos principales y cambios | Estado |
|---|---|---|
| 1 | `components/fleet-controls.tsx`, `components/booking-settings.tsx` y `lib/fleet-admin.ts`: alta breve de unidad y puntos elegidos en Google Maps por coordenadas. | Parcial. El retraso de arranque Android se reprodujo en Fase 0. Falta aislar su causa en un equipo físico y simplificar todo el APK. |
| 2 | `components/account-v3.tsx`, `lib/account-v3.ts` y `app/api/v1/[...path]/route.ts`: datos, foto cuadrada, contraseña, celular, preferencias e integración Google web. Flutter confirma el celular al reservar. | Parcial. Google web requiere cliente OAuth configurado. Google y gestión completa de cuenta nativa pendientes. |
| 3 | `drizzle/0004_autorent_v3.sql`, `lib/pending-reservations.ts`, `components/driver-license.tsx`, `components/reservation-review.tsx` y `components/reservation-removal.tsx`: revisión manual, encuadre, estados, depósito, historial, respaldo CSV y auditoría. | Validado por API local para el ciclo principal. En Android el recorte centrado está integrado. Faltan controles nativos de ajuste y paridad administrativa. |
| 4 | `components/chat-knowledge-editor.tsx`, `components/customer-chat.tsx` y `lib/chat-travel.ts`: aprendizaje desde frases de entrenamiento, bandeja, cálculo de combustible, consulta turística limitada y fuentes citadas. | Parcial. Pasaron 40 consultas en el banco de ayuda y un rechazo fuera de ámbito. Falta la verificación por navegador y ampliar fuentes, rutas y clima. APK sin chat nativo. |
| 5 | `public/sw.js`, `public/offline.html`, `public/manifest.webmanifest`, `lib/web-push.ts`, `worker/index.ts` y `components/notice-center.tsx`: instalación, avisos por rol, tareas de recordatorio y envío Web Push. | Parcial. Centro verificado por API. La entrega Web Push requiere configurar VAPID y probar iPhone y Android. FCM pendiente. |
| 6 | `C:/Users/Ventura/OneDrive/Documentos/ChatGPT/AutoRent/backups/autorent-v3-vista-previa-diciembre-2026.csv`: 10 reservas desde diciembre, 7 cerradas elegibles. | Solo lectura. El CSV cubre los datos de vista previa. La eliminación de producción y un respaldo restaurable de D1/R2 siguen pendientes. |
| 7 | `mobile/lib/features/driver_license.dart`, `mobile/lib/features/reservations.dart` y `mobile/pubspec.yaml`: candidato Flutter 0.4.0+5. | Flutter analyze y 6 pruebas aprobadas. APK compilado, firmado con el certificado de 0.3.1 e instalado en emulador Android 16. Paridad completa pendiente. |

Archivos candidatos para pruebas. El APK sigue apuntando a la URL de producción y necesita un backend v3 compatible para probar los cambios de reservas.

- Web `C:/Users/Ventura/OneDrive/Documentos/ChatGPT/AutoRent/output/autorent-v3-web-candidato.tar`. SHA-256 `1114D6524E2950A52B89DBE72FB58C8A7D76381D15BD28DC47C20788888ADB5D`.
- Android `C:/Users/Ventura/OneDrive/Documentos/ChatGPT/AutoRent/output/AutoRent-v3-0.4.0-candidato.apk`. SHA-256 `73FBE5376B450C6EDBEF008EB0ED7C2D63B21E0DD77E049101C7F8142176CC1D`.

En el emulador Android 16, ADB confirmó la instalación y la actividad principal abrió en el primer intento. La pantalla de prueba mostró que Pixel Launcher dejó de responder. En el reinicio, ADB registró otro timeout y apareció un mensaje de System UI sin respuesta. El catálogo del candidato quedó sin verificar. El éxito de instalación y la coincidencia de firma sí quedaron verificados.

## Formularios web

| Formulario | Antes | Después |
|---|---|---|
| Agregar vehículo | Editor completo con placa, ficha, ubicación, fotografías y campos operativos. | Marca, modelo, año, tarifa, estado y foto principal. Los campos avanzados quedan en Editar unidad. Marca y modelo siguen siendo dos campos. |
| Agregar ubicación | Coordenadas separadas y campos de descripción en el formulario principal. | Nombre, punto mediante coordenadas elegidas en Google Maps y estado. Ciudad, tipo, dirección e indicaciones quedan en Más opciones. |
| Cuenta | Sin pantalla de edición en la web. | Datos y preferencias, foto recortada, y contraseña en secciones independientes. |
| Reserva | Cotización y verificación de licencia con consentimiento para IA. | Cotización, encuadre de ambas fotos y confirmación de celular. La reserva espera revisión manual. |

## Comprobaciones locales

1. Compilar el Worker con `node <plugin-sites>/scripts/build-site.mjs`.
2. Ejecutar `node --import ../autorent-web-test-loader.mjs --test lib/chat-dates.test.ts lib/availability.test.ts lib/pending-reservations.test.ts` desde la fuente de la web.
3. Ejecutar `node ../autorent-v3-diagnostico/qa-v3.mjs` desde la misma carpeta para aplicar las migraciones en Miniflare y probar reservas, revisión, confirmación, depósito, historial, avisos y eliminación en D1/R2 aislados.
4. Desde `mobile`, conservar la configuración de firma privada existente. Ejecutar `flutter analyze`, `flutter test` y `flutter build apk --release --dart-define=API_BASE_URL=https://autorent-molina.lovosdavid.chatgpt.site/api/v1`. El binario queda en `build/app/outputs/flutter-apk/app-release.apk`.
5. Para una prueba en Android con backend compatible, ejecutar `adb install -r <archivo.apk>` y abrir AutoRent. Verificar sesión, galería, cámara, celular, confirmación y comprobante antes de distribuirlo.

## Configuración pendiente

- Google Identity. En Google Cloud, configura Branding y los usuarios de prueba. Crea un cliente OAuth web con el origen `https://autorent-molina.lovosdavid.chatgpt.site`. Configura su identificador como `GOOGLE_CLIENT_ID` en Sites. Para Android, crea también un cliente OAuth Android con el paquete `sv.autorent.autorent` y la huella SHA-1 del certificado release `FD:0F:B4:CB:1B:47:17:46:1F:F2:B7:E5:F1:93:AF:43:10:E8:EF:10`. El cliente Android necesita completar su integración antes de probar el inicio.
- Web Push. Configurar `AUTORENT_VAPID_PUBLIC` con la clave pública P-256 en base64url, `AUTORENT_VAPID_PRIVATE` con el JWK privado como secreto y `AUTORENT_VAPID_SUBJECT` con un contacto `mailto:` o URL HTTPS. Activar el permiso desde Avisos en una PWA ya instalada. Para Flutter, queda configurar Firebase Cloud Messaging e integrar el registro nativo.
- Migración. El archivo `0004_autorent_v3.sql` agrega columnas, auditoría, avisos y suscripciones. Reconduce `lista_para_aprobar` a `pendiente`. Las reservas confirmadas históricas conservan su estado y solo las confirmaciones v3 inician el nuevo plazo. Exportar D1 y respaldar R2 antes de desplegar. Coordinar la actualización del APK porque la API v3 exige nuevo teléfono, encuadre y confirmación administrativa.
- Limpieza. El CSV de vista previa de diciembre contiene 6 canceladas, 1 denegada, 1 completada, 1 en curso y 1 confirmada. Los últimos tres estados quedaron fuera del borrado ordinario. Eliminar únicamente al recibir la frase de autorización y con un respaldo vigente.

## Matriz de verificación

Los resultados web se refieren al candidato local. La prueba en Miniflare no equivale a instalar la PWA ni a recibir un push con la aplicación cerrada.

| # | Requisito | Web instalada | APK |
|---|---|---|---|
| 1 | Cuenta, contraseña y foto | Parcial. Rutas e interfaz implementadas. Falta prueba en dispositivo. | Pendiente de paridad. |
| 2 | Registro e inicio con Google | Parcial. Integración con cliente OAuth pendiente de configuración. | Pendiente. |
| 3 | Licencia automática o revisión manual | Cumplido localmente. OCR descartado con informe, sin llamada OpenAI, carga privada y aprobación manual probadas por API. | Parcial. Carga normalizada y confirmación manual integradas. |
| 4 | Contador de depósito desde Confirmada | Cumplido localmente. Consulta, expiración y reloj sin contador en Pendiente verificados. | Parcial. Consume el contador del servidor v3. |
| 5 | Cambio de estado por administración | Cumplido localmente para revisar, confirmar, marcar pago y expirar. Auditoría comprobada. | Parcial. Validación adaptada al contrato v3. |
| 6 | Historial Confirmada y Pagada | Cumplido localmente por API. | Pendiente de paridad. |
| 7 | Eliminación con vista previa y CSV | Parcial. Vista previa, validación de frase y eliminación de una reserva ficticia verificadas. | Pendiente. |
| 8 | Limpieza desde diciembre | Pendiente. Vista previa y CSV disponibles. | La limpieza corresponde al servidor. |
| 9 | Celular en registro y en cada reserva | Cumplido localmente por API. | Parcial. Confirmación de celular integrada, falta probar cliente real. |
| 10 | Alta de vehículo breve | Parcial. Interfaz aplicada y compilada. | Pendiente. |
| 11 | Ubicación manual en Google Maps | Parcial. Se elige el punto en Maps y se pegan coordenadas, sin clave. | Pendiente. |
| 12 | Formularios simples | Parcial. Alta de unidad y ubicación, cuenta y reserva. | Parcial. Celular y encuadre de licencia. |
| 13 | Chatbot y entrenamiento | Parcial. Aprendizaje guiado, bandeja y banco básico. Falta prueba completa desde navegador. | Pendiente. |
| 14 | Consulta web restringida | Parcial. Turismo acotado, cálculo introduciendo kilómetros y citas. Rutas automáticas y clima pendientes. | Pendiente. |
| 15 | Centro de avisos y push con la app cerrada | Parcial. Centro por rol, lectura y alta del service worker. Push real pendiente. | Parcial. Se conserva el centro móvil. Push nativo pendiente. |
| 16 | APK firmado e instalable con paridad | El paquete de Sites se compila localmente. | Paridad pendiente. |
| 17 | Encuadre y revisión lado a lado | Parcial. UI de recorte y revisión implementadas. Formato y medidas verificados por API. | Parcial. Normalización y confirmación del recorte centrado. |
