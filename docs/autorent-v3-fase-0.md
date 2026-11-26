# AutoRent v3 · Diagnóstico de Fase 0

26 de noviembre de 2026 · Sitio de referencia v14, commit `9887846d9fad730c33ad8205867703d8e49618fa` · Android público `0.3.1+4`.

Se leyeron las seis habilidades adjuntas sobre reservas, validación de licencias, chatbot, notificaciones, QA y diseño. El archivo independiente `autorent-foto-licencia` no venía en la carpeta recibida. Para ese flujo se usaron los requisitos de la sección 6.8 del prompt. Esta fase registra diagnóstico y pruebas aisladas. Los cambios del producto requieren confirmar la Fase 1.

## 1. Mapa del proyecto

| Componente | Estado comprobado | Código |
|---|---|---|
| Web y API de producción | Vinext, React, TypeScript y Vite. La API comparte el origen de la web en `/api/v1`. Cloudflare Worker con D1 para datos y R2 para archivos. Migraciones SQL con Drizzle. | [Sitio publicado, checkout de trabajo](../.tmp/autorent-sites-sync-53e4015246/), [configuración](../.tmp/autorent-sites-sync-53e4015246/.openai/hosting.json), [API](../.tmp/autorent-sites-sync-53e4015246/app/api/v1/%5B...path%5D/route.ts), [migraciones](../.tmp/autorent-sites-sync-53e4015246/drizzle/) |
| Autenticación | Correo y contraseña con bcrypt, token JWT firmado y con expiración. Cookie HTTP-only y Secure en web, Bearer en Flutter. El servidor verifica el rol para operaciones administrativas. | [API](../.tmp/autorent-sites-sync-53e4015246/app/api/v1/%5B...path%5D/route.ts), [sesión Flutter](../mobile/lib/core/session.dart) |
| Chatbot | Flujos guiados, análisis local de fechas y coincidencia por palabras en una base de conocimiento editable. Consulta precios, flota y disponibilidad por la API. Todavía faltan entrenamiento conversacional, bandeja de preguntas y consulta web restringida. | [Chat](../.tmp/autorent-sites-sync-53e4015246/components/customer-chat.tsx), [editor](../.tmp/autorent-sites-sync-53e4015246/components/chat-knowledge-editor.tsx) |
| Web instalada e iOS | Manifiesto `standalone` y perfil Web Clip de iOS. En el sitio no se encontró registro de service worker ni suscripción Web Push. | [Manifiesto](../.tmp/autorent-sites-sync-53e4015246/public/manifest.webmanifest), [layout](../.tmp/autorent-sites-sync-53e4015246/app/layout.tsx), [perfil iOS](../output/AutoRent-iOS-Installer.mobileconfig) |
| Android | Flutter/Dart y Gradle, con pantalla nativa y la misma API HTTPS. Release firmado con la configuración privada de Gradle. El APK se entrega desde R2 a través de Sites. | [Cliente HTTP](../mobile/lib/core/api.dart), [Gradle](../mobile/android/app/build.gradle.kts), [guía de compilación](../mobile/README.md) |
| Backend separado | Express/TypeScript con MySQL, configuración Docker/Render y soporte de demo. El APK de producción y la web publicada usan la API en Sites. | [Backend](../backend/), [datos MySQL](../database/) |

La copia visible en `sites/autorent` contiene cambios locales sobre una versión anterior. El checkout de trabajo identificado en la tabla estaba limpio y coincide con el commit publicado. Conviene partir de ese checkout y preservar los cambios locales. Sites compila el Worker, prepara el archivo de despliegue y publica la versión guardada sobre el mismo proyecto y dominio. [AutoRent en producción](https://autorent-molina.lovosdavid.chatgpt.site/)

## 2. Fallas y brechas observadas

| Hallazgo | Evidencia y causa probable |
|---|---|
| Fallo del APK reportado | La descarga respondió 200. El tamaño de 61 628 263 bytes y el ETag multipart de ocho partes coinciden con el APK local firmado. Las herramientas del SDK confirmaron el paquete `sv.autorent.autorent`, Android mínimo 24, objetivo 36 y arquitecturas ARMv7, ARM64 y x86_64. El binario contiene la URL HTTPS de Sites, declara Internet y deshabilita HTTP sin cifrar. En Android 16 x86_64 la instalación limpia pasó. El primer arranque agotó 11,5 s de espera de ADB, pero la actividad abrió el catálogo y mostró tres vehículos. Hubo advertencias de Flutter y del sistema, sin entrada en el búfer de fallos. El arranque lento se reprodujo en el emulador. La causa del fallo del dispositivo reportado queda sin confirmar. |
| Diferencia concreta en notificaciones Android | Flutter intenta marcar avisos con `/notifications/{id}/read`. La API activa en el código inspeccionado solo implementa la lectura de la lista de avisos. Falta completar el contrato y probarlo en el APK. |
| Licencias | La prueba anterior con la clave existente devolvió `credit_balance_exhausted`. El código todavía intenta el servicio externo si hay clave y deriva una respuesta ausente a revisión manual. El flujo actual solicita **frente y reverso** en ambas plataformas. En web, cámara con marco y recorte centrado, galería con confirmación de vista previa sin editor obligatorio. El servidor valida tipo y tamaño, sin comprobar normalización a 1280 × 807 ni un paso de recorte. |
| Reservas y pago | La lógica vigente vence solicitudes en espera de revisión y conserva el plazo anterior. Esto contradice v3, que inicia el plazo para **depositar** cuando administración confirma. Hace falta transicionar datos históricos, separar el depósito del estado de revisión y mantener la protección contra fechas superpuestas. |
| Push y cuenta | Hay avisos ligados a reservas, pero falta el centro completo por rol, suscripciones, push y pruebas con la app cerrada. En producción `GET /sw.js` respondió 404. No se encontró integración de Google. El servidor permite registrarse sin celular. |
| Formularios | Agregar unidad usa el mismo editor extenso que editar. La ubicación web pide coordenadas, tipo y dirección en el formulario principal. Registro, reserva y licencia requieren separación en pasos breves para mantener consentimiento, accesibilidad y validación sin concentrar todos los campos en una pantalla. |

Las comprobaciones HTTP de producción devolvieron salud de API `ok`, catálogo de tres unidades, manifiesto y descargas accesibles. Pasaron 15 pruebas automatizadas de fechas, disponibilidad, expiración y decisión de licencia. En Miniflare con D1/R2 de prueba pasaron la carga privada de licencia, la reserva pendiente sin OpenAI, los borradores del chatbot y la modificación con controles de propietario y solapamiento.

En un segundo arranque, después de detener únicamente AutoRent y con Android ya iniciado, ADB volvió a devolver `timeout` (12,4 s). El árbol de accesibilidad volvió a mostrar el catálogo y el búfer de fallos registró 0 entradas. Esto confirma que el timeout se repite en el entorno de prueba y que la aplicación finalmente abre allí. La hora exacta del primer fotograma y la causa del retraso no quedaron establecidas.

Evidencia Android: [primer catálogo](../.tmp/autorent-v3-diagnostico/app-view.xml), [catálogo tras reiniciar](../.tmp/autorent-v3-diagnostico/app-restart.xml) y [advertencias del proceso](../.tmp/autorent-v3-diagnostico/apk-logcat.txt). La prueba se realizó sin sesión. Quedan por comprobar con cuentas de prueba el registro, la reserva y la cámara o galería en Android físico.

## 3. Viabilidad de la lectura automática de licencia

Se probaron 40 imágenes ficticias generadas con nombres y vencimientos de muestra, dos distribuciones de texto y cinco condiciones simuladas: limpia, luz baja y ángulo, reflejo, desenfoque y compresión, y captura pequeña. Hubo 30 casos de coincidencia y 10 negativos en los que se cambió el nombre o vencimiento ingresado. La prueba se ejecutó en Windows, Node.js 24.22.1, Tesseract.js 6.0.1 y modelo español local. Los tiempos corresponden al equipo de pruebas. No se usaron licencias de clientes.

| Opción | Titular | Vencimiento | Ambos | Falsos positivos | Tiempo p95 |
|---|---:|---:|---:|---:|---:|
| Tesseract.js, lectura directa | 18/30 (60 %) | 21/30 (70 %) | 15/30 (50 %) | 0/10 | 790 ms |
| Tesseract.js, escalado, gris, contraste y nitidez | 9/30 (30 %) | 17/30 (57 %) | 8/30 (27 %) | 0/10 | 1 483 ms |
| Tesseract nativo en servidor propio | Sin medir | Sin medir | Sin medir | Sin medir | Sin medir |
| ML Kit nativo | Sin medir | Sin medir | Sin medir | Sin medir | Sin medir |

Tesseract.js puede procesar imágenes en local. El ensayo de escritorio es una prueba preliminar y no certifica precisión con fotos tomadas desde teléfonos ni rendimiento en la PWA y el APK. Tesseract nativo necesitaría otro entorno para ejecutar el binario. El Worker de Sites no aloja un proceso nativo de Windows o Linux. ML Kit ofrece OCR local para Android/iOS y no cubre la PWA con el mismo SDK. La integración OpenAI existente requiere créditos y envía imágenes al proveedor. [Tesseract.js](https://github.com/naptha/tesseract.js) · [Tesseract](https://github.com/tesseract-ocr/tesseract) · [ML Kit](https://developers.google.com/ml-kit/guides) · [Límites de Workers](https://developers.cloudflare.com/workers/platform/limits/)

Evidencia por imagen y tiempos: [lectura directa](../.tmp/autorent-v3-ocr/resultados.json), [preprocesamiento](../.tmp/autorent-v3-ocr/resultados-mejorado.json), [script de diagnóstico](../.tmp/autorent-v3-ocr/benchmark.cjs).

**Decisión propuesta para v3: revisión manual.** Para habilitar OCR debe demostrarse al menos 90 % de acierto en nombre y vencimiento, cero falsos positivos en una muestra representativa, menos de 10 s en un teléfono de gama media, privacidad, costo cero y paridad. Con la evidencia actual corresponde retirar la llamada de pago en la Fase 3 y mantener la decisión humana, con las dos fotos del mismo tamaño, zoom y «Datos verificados». Se guardarán el titular y mes/año como datos de licencia, con las fotos privadas requeridas para revisar la reserva. El recorte en el cliente se complementará con validación del archivo normalizado en el servidor.

## 4. Plan y riesgos por fase

| Fase | Cambios | Verificación y riesgo principal |
|---|---|---|
| 1 | Investigar el fallo puntual del APK y simplificar la creación de vehículo, ubicación y otros formularios. Entregar tabla antes/después y conservar las opciones avanzadas en edición. | Reproducir en un Android funcional, conservar captura de arranque, API y logcat. Probar alta, edición y catálogo en PWA y Flutter. Para ubicación, propuesta sin clave: elegir el punto en Google Maps, pegar sus coordenadas, validar la vista previa y abrir el punto por URL. |
| 2 | Mi cuenta, cambio de contraseña con autenticación actual, foto, nombre, celular y Google. Mantener correo/contraseña y confirmar el celular en cada reserva. | Migración aditiva y verificación del token de Google en servidor. Vincular una cuenta existente mediante comprobación segura de titularidad, en especial para administradores. Crear clientes OAuth web y Android cuando se autorice configurar la cuenta. |
| 3 | Estados y auditoría, plazo de depósito desde Confirmada, historial Confirmada/Pagada, comprobante, revisión de licencia y borrado con vista previa y CSV. | Probar copias de D1/R2 antes de migrar. Probar transiciones concurrentes, liberación de fechas, órdenes de pago, caducidad y compatibilidad con reservas previas. Proteger fotos compartidas por varias reservas y registrar eliminación de archivos. |
| 4 | Entrenamiento conversacional con guardado explícito, preguntas sin respuesta, 40 casos básicos, cálculo de combustible y consulta controlada. | Probar prioridad de los datos en vivo, bloqueo fuera de ámbito, fuentes comerciales permitidas, citas, límites, caché y ausencia de datos personales en consultas externas. |
| 5 | PWA con service worker, instalación guiada, centro de avisos y Web Push con VAPID. FCM en Flutter si se configura el proyecto gratuito. | Pruebas con PWA cerrada en iPhone y Android y APK Android, apertura de reserva correcta, preferencias, limpieza de suscripciones inválidas y deduplicación. |
| 6 | Limpieza de reservas con inicio desde 01/12/2026. | Mostrar conteo y entregar respaldo antes de esperar la frase de autorización exigida por el prompt. No se ejecutó ninguna limpieza en Fase 0. |
| 7 | APK release firmado, versión incrementada y verificación de paridad con la PWA. | Probar instalación limpia y actualización, registrar dispositivos, versiones y resultados, y comprobar el hash del archivo entregado. |

Google Maps admite enlaces sin clave. El mapa interactivo embebido de Google para producción requiere credenciales y facturación, por lo que la Fase 1 parte de enlaces y confirmación de coordenadas. Para Google Sign-In, la huella SHA-1 del APK actual es `FD:0F:B4:CB:1B:47:17:46:1F:F2:B7:E5:F1:93:AF:43:10:E8:EF:10`. Web Push en iOS requiere abrir la app desde la pantalla de inicio y solicitar permiso tras una acción del usuario. FCM es un producto gratuito que requiere configurar el proyecto y sus credenciales. [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started) · [Facturación de Maps JavaScript](https://developers.google.com/maps/documentation/javascript/usage-and-billing) · [Google Identity](https://developers.google.com/identity/siwg/best-practices) · [WebKit](https://webkit.org/blog/13878/) · [Firebase](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans)
