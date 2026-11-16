# AutoRent

## Actualización: flota del propietario

El catálogo solicitado contiene únicamente **Outlander gris 2017, Outlander roja 2017 y Rogue gris indicada como 2016**. La Rogue azul está excluida. La tarifa, el kilometraje y la versión exacta siguen pendientes. Se prepararon fichas con referencias oficiales, seis fotografías y administración para agregar, editar y retirar más unidades.

Esta actualización requiere aplicar `database/migrations/002_real_fleet.sql` e importar `database/data/real-fleet.json`. El asistente `aplicar-flota.ps1` realiza esos pasos sin repetir la base inicial. Consulta [la guía de flota real](docs/real-fleet.md). Hasta aplicar la migración y reiniciar la API, la instancia en ejecución sigue usando la versión anterior.

Los apartados siguientes conservan el contexto de las fases anteriores y sus datos de demostración; las cantidades y los filtros esperados de esas guías corresponden al catálogo de demostración.

Sistema móvil de gestión y alquiler de vehículos para el proyecto final de la Facultad de Ingeniería y Arquitectura de UNIVO. Fecha de entrega: 30 de noviembre de 2026.

El proyecto comenzó desde cero. La Fase 1 preparó las herramientas y la Fase 2 quedó aplicada y comprobada en el servicio MySQL del estudiante. Las fases 3 y 4 quedaron confirmadas con la conexión MySQL, el registro, el inicio de sesión y la consulta del perfil. La Fase 5 incorpora el catálogo de vehículos, filtros y consulta de disponibilidad; está pendiente de la comprobación local del estudiante. La aplicación móvil y las operaciones del negocio se construirán en fases posteriores, con confirmación al terminar cada fase.

## Tecnologías

| Parte | Tecnología |
| --- | --- |
| Aplicación móvil | Flutter y Dart; Android prioritario |
| API REST | Node.js, Express y TypeScript |
| Persistencia | MySQL con InnoDB |
| Comunicación | HTTP/HTTPS y JSON |
| Autenticación | JWT y hashes de contraseña con bcrypt |
| Mapas previstos | flutter_map con datos OpenStreetMap |

El entorno verificado en la Fase 1 incluye Flutter 3.47.8, Dart 3.13.7, Node.js 24.22.1 y MySQL 8.4.13. El emulador se llama `AutoRent_API_36`.

## Reglas de diseño Flutter

Antes de diseñar o programar cualquier pantalla, widget, componente o tema de AutoRent, consultar y seguir el [SKILL.md indicado por el estudiante](<C:/Users/Ventura/OneDrive/Desktop/Nueva carpeta/.agents/skills/autorent-design-system/SKILL.md>). Esa fuente está en una carpeta externa al proyecto actual.

El sistema establece modo oscuro, paleta negra y dorada, tipografía Inter, estilos centralizados y componentes reutilizables. Primero se entregan los seis archivos de fundamentos indicados en la habilidad y se solicita su aprobación. Antes de implementar cada pantalla nueva, presentar su estructura visual, acción principal, componentes, navegación e interacciones, y esperar la aprobación explícita del estudiante.

## Archivos principales

| Archivo | Para qué sirve |
| --- | --- |
| `database/migrations/001_initial_schema.sql` | Crea la base `autorent` y sus nueve tablas con relaciones, índices y restricciones. |
| `database/seeds/001_demo_catalog.sql` | Agrega un catálogo ficticio para desarrollar y probar. |
| `database/checks/001_verify_setup.sql` | Consulta tablas, cantidades y ejemplos de disponibilidad y cálculo del alquiler. |
| `docs/business-rules.md` | Registra las reglas acordadas y las responsabilidades de la futura API. |
| `docs/database-model.md` | Explica las relaciones y contiene el diagrama entidad-relación en Mermaid. |
| `database/access/001_create_app_user.sql` | Crea una cuenta MySQL para la API con contraseña aleatoria y permisos sobre los datos de `autorent`. |
| `backend/README.md` | Explica cómo completar la configuración local, iniciar la API y comprobar sus dos endpoints. |
| `docs/api/health.md` | Documenta respuestas y códigos HTTP de diagnóstico. |
| `docs/phase4-auth-guide.md` | Conserva las pruebas de registro, inicio de sesión y perfil. |
| `docs/phase5-catalog-guide.md` | Explica cómo consultar y filtrar el catálogo y su disponibilidad. |
| `docs/api/vehicles.md` | Documenta los endpoints públicos de vehículos y sus filtros. |

`backend/` ya contiene una API ejecutable. `mobile/` conserva la organización inicial; todavía no es un proyecto Flutter generado. Las carpetas vacías no se guardan en Git hasta que contienen archivos.

El puerto `3000` sirve la API y devuelve datos JSON. La dirección `/api/v1` es el prefijo de sus rutas y actualmente devuelve `404 NOT_FOUND` al abrirla sola. Para consultar datos en el navegador, usar `/api/v1/health`, `/api/v1/vehicles` o `/api/v1/catalogs`. La interfaz de AutoRent se construirá en Flutter en su fase correspondiente.

## Continuar con la Fase 5

Sigue la [guía del catálogo](docs/phase5-catalog-guide.md): reiniciar la API, consultar vehículos y opciones de filtros, abrir un detalle y buscar disponibilidad entre dos instantes. El [contrato del catálogo](docs/api/vehicles.md) documenta los parámetros. El estudiante eligió mostrar solo vehículos operativos.

Estas operaciones son públicas y solo consultan datos. La disponibilidad sin fechas se indica como `null`; con fechas, la lista incluye únicamente los vehículos disponibles en ese período. La reserva se guardará y validará dentro de una transacción en una fase posterior.

La implementación pasó la comprobación de tipos, la compilación, 78 pruebas automatizadas y 21 comprobaciones con MySQL temporal. La Fase 5 queda pendiente de la confirmación local del estudiante.

## Referencia de Fase 4: autenticación

Sigue la [guía de autenticación](docs/phase4-auth-guide.md): reiniciar la API, registrar un cliente, iniciar sesión y consultar su perfil usando el token. El [contrato de autenticación](docs/api/auth.md) detalla los campos y las respuestas. El registro público crea únicamente clientes. Existe una herramienta local para asignar el rol administrador a una cuenta ya registrada.

La clave privada de JWT se prepara con `npm.cmd run auth:setup`. El comando conserva una clave válida existente y la configuración MySQL. No se deben compartir el contenido de `.env`, contraseñas ni tokens.

La implementación de la Fase 4 pasó la comprobación de tipos, la compilación, 53 pruebas automatizadas y 17 comprobaciones con MySQL temporal. El estudiante confirmó el registro de un cliente, el inicio de sesión con token válido por 3600 segundos y la consulta correcta de `/auth/me`. La Fase 4 está completada.

## Referencia de Fase 3: conexión de la API

La base `autorent` ya tiene sus nueve tablas y el catálogo de demostración. **No repitas la migración ni las semillas.** El error `1050: Table 'usuarios' already exists` apareció al intentar aplicar otra vez la migración y no requiere borrar ni recrear tablas.

Sigue los pasos de [backend/README.md](backend/README.md): crear una vez la cuenta MySQL `autorent_app`, copiar su contraseña aleatoria localmente en `backend/.env`, iniciar la API y consultar sus dos direcciones de diagnóstico. No compartas contraseñas en el chat. La cuenta de conexión MySQL es distinta de los clientes y administradores de la aplicación.

El estudiante confirmó ambas respuestas con `success: true` y la segunda con `database: "connected"`. La Fase 3 está completada; estos pasos se conservan para instalaciones nuevas.

## Referencia de Fase 2: aplicar los scripts en una instalación nueva

Conservamos estos pasos para una base nueva. Tu instalación actual ya los completó; puedes repetir únicamente el archivo de consultas de comprobación del paso 4, que no modifica registros.

Estos pasos usan tu servicio `MySQL84`. Elige la contraseña de `root` localmente cuando MySQL la solicite. No la escribas en comandos, scripts o mensajes del chat.

Ejecuta la migración una sola vez en una base nueva. Si ya tienes una base `autorent` con tablas, revisaremos su estado antes de importar: no borres datos para repetir estos pasos.

1. Abre PowerShell y entra en la carpeta del proyecto:

   ```powershell
   Set-Location "C:\Users\Ventura\OneDrive\Documentos\ChatGPT\AutoRent"
   ```

2. Crea las tablas. MySQL solicitará tu contraseña localmente y terminará al procesar el archivo:

   ```powershell
   & "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p --default-character-set=utf8mb4 --execute="SOURCE database/migrations/001_initial_schema.sql"
   ```

   Si no aparece ningún error y `$LASTEXITCODE` vale `0`, continúa. Si la base ya tiene estas tablas, detente para revisar su estado.

3. Carga el catálogo de demostración. Vuelve a escribir tu contraseña cuando la solicite:

   ```powershell
   & "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p --default-character-set=utf8mb4 --execute="SOURCE database/seeds/001_demo_catalog.sql"
   ```

   Comprueba nuevamente que no haya errores y que `$LASTEXITCODE` sea `0` antes de continuar.

4. Ejecuta las consultas de comprobación. La opción `--table` muestra sus resultados como tablas:

   ```powershell
   & "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p --default-character-set=utf8mb4 --table --execute="SOURCE database/checks/001_verify_setup.sql"
   ```

Cada archivo se ejecuta en una conexión separada con `--execute`. Este modo se detiene ante un error; no agregues `--force`. La carga de semillas está dentro de una transacción: si falla antes de `COMMIT`, el cierre de la conexión revierte esa carga. No uses `SOURCE` en una sesión interactiva para importar estos archivos, porque puede continuar procesando el archivo tras un error.

El resultado inicial debe incluir nueve tablas, tres categorías, tres marcas, seis modelos, dos ubicaciones y seis vehículos. Cinco vehículos son operativos y uno está en mantenimiento. Una duración de 26 horas debe corresponder a dos días cobrados.

Las cuentas de usuario y sus reservas se crearán a través de la API cuando implementemos autenticación. Las ubicaciones, matrículas, kilometrajes y tarifas del catálogo son ejemplos ficticios; no representan información verificada de Rent a Car Molina.

Si aparece un error, conserva el mensaje completo y el archivo que estabas ejecutando. Un error de tabla o dato duplicado puede indicar que ya se aplicó un script: no ejecutes los siguientes archivos hasta revisarlo. La creación de tablas no se revierte con `ROLLBACK`; por eso revisaremos cualquier migración incompleta antes de continuar.

Referencia: [ejecución de archivos en modo batch de MySQL](https://dev.mysql.com/doc/refman/8.4/en/batch-mode.html).

## Responsabilidades de cada capa

La API sigue el recorrido `routes -> controllers -> services -> repositories`:

- `routes`: selecciona el controlador de cada dirección HTTP.
- `controllers`: recibe datos de la petición y construye la respuesta.
- `services`: aplica reglas del negocio, autorización y transacciones.
- `repositories`: ejecuta consultas SQL parametrizadas.
- `models`: representa entidades y tipos del dominio.
- `validators`: valida los datos recibidos antes de procesarlos.
- `middlewares`: comparte autenticación y manejo de errores entre rutas.

En Flutter, cada funcionalidad tendrá modelos, repositorios que consultan la API, controladores, pantallas y widgets. La API será la fuente de los datos del negocio.

## Comprobación de la Fase 2

Los archivos pasaron 35 comprobaciones en una instancia temporal de MySQL 8.4.13 en el puerto local 3307. Incluyeron ejecución de los tres SQL, datos iniciales, caracteres UTF-8, claves duplicadas, referencias inexistentes, períodos inválidos, límites exactos de 24 horas, tarifa histórica y devoluciones incoherentes. La instancia temporal se detuvo y sus archivos privados se retiraron al terminar; esta verificación no cargó datos en el servicio `MySQL84` del estudiante.

La migración debe crear las nueve tablas; las semillas deben cargar el catálogo completo, y el archivo de comprobaciones debe devolver resultados coherentes. Las restricciones SQL protegen valores, claves y relaciones. Evitar reservas simultáneas requiere el protocolo transaccional de la API descrito en `docs/business-rules.md`; esa funcionalidad se implementará y probará en su fase correspondiente.

El estudiante confirmó que los scripts funcionan en su instalación: nueve tablas, seis vehículos —cinco operativos—, dos días cobrados para 26 horas y cero incidencias. Las fases 2, 3 y 4 están finalizadas. La Fase 5 queda pendiente de la comprobación local descrita en la guía del catálogo.
