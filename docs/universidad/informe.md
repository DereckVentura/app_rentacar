# AutoRent para Rent a Car Molina

Sistema académico para la gestión de una flota y reservas de vehículos

Universidad: [Completar]
Facultad y carrera: [Completar]
Asignatura: [Completar]
Docente: [Completar]
Integrantes y carnés: [Completar]
Lugar y fecha: La Unión, El Salvador, 29 de octubre de 2026
Versión de entrega: demostración académica 0.1

## Resumen

AutoRent es una aplicación de demostración para consultar vehículos y administrar reservas, entregas, devoluciones y solicitudes de usuarios. El caso de estudio utiliza el nombre Rent a Car Molina y una flota inicial de tres unidades proporcionadas por el solicitante. La solución reúne una aplicación Flutter para web y Android, una API en Express y TypeScript y una base de datos MySQL.

El resultado permite separar la información pública de las operaciones privadas y administrar una flota que puede crecer sin modificar el código del catálogo. La gestión de reservas utiliza transacciones, validación de precios y control de coincidencias de fechas. Las funciones de privacidad incluyen documentos accesibles, constancias de aceptación y solicitudes privadas con seguimiento. La entrega incorpora código, migraciones, pruebas, manuales y configuración de despliegue. La publicación en internet y la habilitación comercial no forman parte de los resultados verificados: requieren cuentas de alojamiento, datos del negocio y decisiones adicionales.

## Introducción

La administración de alquileres requiere coordinar información que cambia con frecuencia: vehículos disponibles, fechas, lugares de entrega, precios y kilometraje. Cuando estos datos se conservan en registros separados resulta difícil conocer su estado y evitar asignar el mismo vehículo a dos reservas que coinciden. Este proyecto propone un punto de consulta para clientes y un espacio de administración con permisos diferenciados.

El trabajo se desarrolla como proyecto universitario y no como estudio de campo del negocio. Los datos de contacto y las fotografías proceden del solicitante; no se realizaron entrevistas, encuestas ni mediciones de rentabilidad. Tampoco se atribuye al negocio una aprobación contractual que no se haya documentado. Los resultados describen el software construido y las verificaciones efectuadas.

## Planteamiento del problema

El problema de ingeniería consiste en mantener coherencia entre catálogo, reservas y alquileres mientras varios usuarios realizan operaciones. Una pantalla puede mostrar información antigua si otro cliente reserva primero o si la administración cambia una tarifa. Confiar únicamente en el estado visible del dispositivo permitiría reservas solapadas, precios distintos de los confirmados y modificaciones indebidas del kilometraje.

La pregunta que orienta el proyecto es cómo implementar una aplicación accesible desde web y Android que conserve la integridad de estas operaciones y permita trasladar el servicio a un alojamiento con mayor capacidad. La respuesta propuesta combina una API central, una base de datos relacional y reglas que se comprueban nuevamente al ejecutar cada operación.

## Objetivos

### Objetivo general

Desarrollar una demostración funcional para consultar y administrar una flota de vehículos, reservas y alquileres, con control de acceso, persistencia y una estructura que permita evolucionar hacia un servicio comercial.

### Objetivos específicos

- Presentar únicamente los tres vehículos seleccionados y distinguir la información confirmada de los datos pendientes.
- Implementar cuentas de cliente y administración con permisos comprobados por el servidor.
- Registrar reservas con cálculo monetario exacto, control de solapamientos y reintentos seguros.
- Registrar entregas y devoluciones manteniendo coherencia entre alquiler, kilometraje y ubicación.
- Incorporar preguntas frecuentes, documentos de uso académico y gestión de solicitudes de privacidad y reclamos.
- Entregar pruebas, instrucciones de instalación, respaldos y una ruta de despliegue y escalado.

## Justificación y alcance

El proyecto permite aplicar desarrollo de interfaces, servicios web, modelado relacional, programación transaccional y pruebas automatizadas a un caso comprensible. Su aporte es integrar estas áreas en un flujo completo y documentar las limitaciones de una demostración antes de convertirla en producto.

El alcance incluye catálogo con filtros y fotografías, ficha de vehículo, acceso, reservas e historial, mapa de puntos configurados, avisos, administración de flota y ubicaciones, entrega y devolución y funciones de información y privacidad. Los vehículos iniciales son Mitsubishi Outlander gris 2017 4×2, Mitsubishi Outlander roja 2017 4×2 y Nissan Rogue gris indicada como 2016. La Rogue azul fue excluida por decisión expresa del solicitante.

No se implementan cobros con tarjetas, verificación oficial de identidad, carga de DUI o licencia, rastreo GPS del cliente, facturación electrónica ni comprobación automática de seguros. No se declaran confirmadas las versiones exactas sin VIN o documentación. La flota inicial no acepta reservas hasta completar tarifa, placa, kilometraje y ubicación. Para una presentación se pueden introducir datos ficticios claramente identificados en la base de demostración.

## Método de desarrollo

El desarrollo siguió incrementos verificables: fundamentos visuales, autenticación, catálogo, operaciones de reserva, administración y documentación. Las decisiones de alcance se tomaron a partir de las instrucciones del solicitante. Se aprobó el conjunto de pantallas y posteriormente se incorporaron preguntas frecuentes y privacidad.

Cada incremento se verificó en el nivel correspondiente. Las validaciones de entradas y cálculos se probaron de forma aislada; la integridad de reservas se comprobó contra MySQL temporal; las pantallas se analizaron y probaron con Flutter y se revisaron en navegador. No se presenta este proceso como una certificación ni como una evaluación de usuarios reales. Las versiones y dependencias quedan registradas en los archivos de bloqueo del proyecto.

## Requisitos del sistema

| Código | Requisito | Criterio de aceptación |
|---|---|---|
| RF01 | Catálogo público | Mostrar tres unidades iniciales y permitir nuevas altas desde administración |
| RF02 | Autenticación y permisos | El registro público crea clientes y una cuenta cliente no administra flota |
| RF03 | Cotización | Mostrar fechas, días, tarifa y total antes de confirmar |
| RF04 | Reserva coherente | Ante solicitudes simultáneas para un mismo período, confirmar solo una |
| RF05 | Historial y cancelación | Cada cliente consulta sus reservas y cancela antes del inicio |
| RF06 | Entrega y devolución | Solo administración registra el movimiento y no disminuye el kilometraje |
| RF07 | Ubicaciones y mapa | Mostrar puntos activos configurados sin inventar coordenadas del negocio |
| RF08 | Avisos | Cada usuario consulta y marca sus propios avisos |
| RF09 | Ayuda y documentos | FAQ y condiciones accesibles incluso sin iniciar sesión |
| RF10 | Privacidad y reclamos | Emitir constancia, limitar acceso por usuario y permitir respuesta administrativa |
| RNF01 | Integridad | Operaciones relacionadas dentro de una transacción MySQL |
| RNF02 | Seguridad | Validación en servidor, consultas parametrizadas y secretos fuera del código |
| RNF03 | Portabilidad | Configuración por entorno y compilación web independiente del servidor |
| RNF04 | Mantenibilidad | Capas separadas, pruebas y migraciones versionadas |

## Arquitectura de la solución

La aplicación Flutter concentra las pantallas y utiliza una API HTTP JSON. El servidor organiza las rutas, validadores, servicios y repositorios. Los repositorios ejecutan consultas parametrizadas y las operaciones que requieren atomicidad. MySQL almacena los datos; el dispositivo conserva únicamente el token necesario para mantener la sesión.

Esta separación evita depender de una carpeta local para las nuevas imágenes del catálogo: existe una integración opcional con Cloudinary mediante firmas generadas en el servidor. Las fotografías iniciales forman parte de los recursos públicos. En un despliegue público se deben utilizar HTTPS, verificación TLS para MySQL y una lista explícita de orígenes permitidos.

La solución corresponde a un monolito modular con un cliente independiente. No se requieren microservicios para la escala académica. El control compartido de intentos de acceso en MySQL permite varias instancias de la API. El número de conexiones debe ajustarse a los límites de la base; la posibilidad de crecer no equivale a una capacidad medida de miles de usuarios.

## Modelo de datos e integridad

El núcleo relacional contiene usuarios, categorías, marcas, modelos, ubicaciones, vehículos, reservas, alquileres y notificaciones. Se agregan auditoría, control compartido de intentos, contenido del negocio, aceptaciones legales y solicitudes de privacidad. La tabla de migraciones registra versiones aplicadas y sus huellas.

Una reserva pertenece a un cliente y a un vehículo y referencia los puntos de entrega y devolución. Un alquiler referencia una reserva y conserva kilometraje de salida y regreso. Las aceptaciones conservan el texto de los documentos y la versión que el usuario confirmó; una edición del contacto público produce una versión diferente para aceptaciones futuras. Las solicitudes guardan detalle, estado, respuesta y fechas.

La ficha técnica variable del vehículo se almacena en JSON validado. Las relaciones que determinan reservas, precios, permisos y movimientos se mantienen en columnas y claves foráneas. Este uso acotado de JSON permite incorporar características sin debilitar el núcleo transaccional. El diccionario de datos y las migraciones se incluyen en la documentación técnica.

### Reserva y concurrencia

El servidor bloquea la fila del vehículo durante la creación, vuelve a comprobar su estado y consulta reservas activas que se solapan. Los intervalos adyacentes están permitidos porque el final de uno puede coincidir con el inicio del siguiente. La tarifa confirmada por el cliente debe coincidir con la vigente. El identificador de operación permite reconocer un reintento y evita duplicar una reserva cuando se pierde la respuesta.

Los importes se calculan con centavos enteros utilizando BigInt y se conservan en DECIMAL en MySQL. Las fechas se guardan en UTC y se muestran en horario de El Salvador. La devolución actualiza el alquiler, la reserva, el kilometraje y la ubicación en la misma transacción. Las pruebas incluyen intentos simultáneos y un vehículo que aún no ha sido devuelto.

## Interfaz y accesibilidad

La interfaz utiliza fondo negro, superficies oscuras y acentos dorados. Inter se utiliza para información y controles; Cormorant Garamond distingue el nombre Rent a Car Molina. Ambas tipografías se incluyen con sus licencias, por lo que la marca no requiere descargar una fuente al abrir la app.

Las secciones principales son Flota, Reservas, Mapa, Cuenta y Admin para cuentas autorizadas. Se incluyen estados de carga, mensajes de error y contenido vacío. Los datos no suministrados se muestran como pendientes y los errores de permisos se explican sin revelar información privada del servidor. La revisión visual incluye tamaños de móvil y escritorio; no sustituye una auditoría completa con tecnologías de asistencia.

## Pruebas y resultados

Las pruebas verifican normalización y rechazo de entradas, contraseñas, tokens, permisos, filtros, cálculo monetario, operaciones concurrentes, cancelación, entrega, devolución y avisos. La privacidad añade comprobaciones de aceptación explícita, versiones, aislamiento de solicitudes y exportación propia. El archivo de resultados de la entrega contiene los conteos finales y las salidas resumidas.

Las pruebas de integración utilizan una instancia temporal en un puerto separado. No se borran registros de clientes ni se emplea la base existente como entorno de pruebas. Las capturas y los recorridos del navegador constituyen evidencia funcional de la interfaz. Los importes que aparezcan en pruebas aisladas son datos ficticios y no tarifas del negocio.

La entrega no demuestra disponibilidad pública, rendimiento bajo carga comercial ni cumplimiento jurídico integral. Esas conclusiones requieren pruebas y decisiones que no pueden deducirse únicamente de una compilación exitosa. Tampoco se atribuye al negocio una mejora porcentual de eficiencia o ingresos, puesto que no se midió una operación real.

## Instalación y demostración

La demostración Windows utiliza Node.js 24 y MySQL 8.4 instalados. El iniciador crea una base local independiente en el puerto 3319, aplica migraciones y carga exclusivamente las tres unidades elegidas. El servidor de demostración utiliza el puerto 3002 y la web el 8082. Las credenciales se generan aleatoriamente y se guardan en un archivo privado local; no se incluyen en este informe.

El acceso se realiza mediante iniciar-demo.cmd. Para trabajar con la base preexistente se utiliza la actualización respaldada y la contraseña administrativa de MySQL introducida localmente. Son dos entornos distintos. Las instrucciones completas de instalación y las rutas de los archivos están en el manual de entrega. Para Android debe configurarse una dirección de API accesible desde el dispositivo: 10.0.2.2 corresponde al emulador, mientras que un teléfono real necesita una dirección de red o HTTPS público.

## Alojamiento y escalabilidad

La opción inicial preparada combina un servicio de API en Render y MySQL administrado en Aiven. Ambos publican modalidades gratuitas con límites que deben comprobarse al activar las cuentas. Render suspende el servicio gratuito tras inactividad; Aiven ofrece recursos reducidos y su plan gratuito no constituye alta disponibilidad. La guía de alojamiento explica las variables, migraciones, publicación web y configuración de fotografías.

Para crecer se propone medir latencia, errores, consumo de conexiones y tiempo de las consultas; contratar una base y servidor adecuados; ajustar índices con datos representativos; distribuir imágenes en almacenamiento externo y ejecutar respaldos comprobados. Las notificaciones actuales son internas y se consultan periódicamente; correo, SMS y notificaciones push requieren componentes adicionales. No existe una cifra de capacidad comercial certificada.

## Privacidad y preparación comercial

La demostración ofrece aviso de privacidad, condiciones académicas, documentos consultables y descargables en web y un registro de aceptación. Permite obtener los datos propios en JSON, presentar solicitudes y consultar respuestas. La administración debe ejecutar la gestión correspondiente: responder una solicitud no equivale a borrar, corregir o anonimizar automáticamente toda la información almacenada.

Se consultaron fuentes oficiales de El Salvador, incluida la Ley para la Protección de Datos Personales y la reforma de septiembre de 2026. Para operar con datos reales aún deben definirse responsable, correo, proveedores, ubicaciones de tratamiento, plazos de conservación y procedimientos. El calendario comercial debe considerar las obligaciones de conservar comprobantes y atender derechos; no se promete eliminación inmediata de registros sujetos a conservación legítima.

Antes de vender el proyecto deben aclararse los derechos sobre código, marca y fotografías y las reglas de propiedad intelectual de la universidad. La empresa debe validar condiciones de alquiler, identidad fiscal, contrato, precios finales, seguros, asistencia y medios de pago. La guía de comercialización propone un acuerdo de licencia o cesión, soporte, aceptación de entrega y tratamiento de datos. Los textos incluidos no certifican que una explotación comercial sea legal.

## Conclusiones

La solución integra los módulos principales de una demostración de alquiler de vehículos y conserva la coherencia de las operaciones en el servidor. La administración de la flota permite incorporar unidades y completar su información sin editar las tarjetas del catálogo. La separación entre cliente, API y almacenamiento facilita trasladar el servicio cuando cambie el alojamiento.

El principal límite de la entrega no es el número inicial de vehículos, sino la falta de condiciones comerciales y la ausencia de validación en una operación real. Mantener estos datos como pendientes y presentar el sistema como académico evita confundir una demostración con un servicio disponible para contratar. El paso siguiente es completar los datos, activar alojamiento, verificar seguridad y restauración y validar el producto con usuarios autorizados.

## Recomendaciones

- Completar la portada y adaptar el formato a la guía específica de la universidad.
- Revisar código, diagramas y casos de prueba para poder explicar las decisiones durante la defensa.
- Usar cuentas y datos ficticios en la exposición y no mostrar archivos de contraseñas o respaldos privados.
- Comprobar los datos técnicos con VIN o documentación del vehículo antes de convertirlos en afirmaciones comerciales.
- Establecer criterios de aceptación y una prueba piloto antes de recibir pagos o documentos reales.

## Referencias

Asamblea Legislativa de El Salvador. Ley para la Protección de Datos Personales, Decreto Legislativo 144. https://www.asamblea.gob.sv/leyes-y-decretos/view/6054

Asamblea Legislativa de El Salvador. Reforma a la Ley para la Protección de Datos Personales, Decreto Legislativo 659, septiembre de 2026. https://www.asamblea.gob.sv/leyes-y-decretos/view/7022

Asamblea Legislativa de El Salvador. Reformas a la Ley de Protección de Datos Personales agilizarán la gestión de solicitudes, 17 de septiembre de 2026. https://www.asamblea.gob.sv/node/14116

Defensoría del Consumidor. Obligaciones especiales en comercio electrónico. https://www.defensoria.gob.sv/obligaciones/

Render. Deploy for Free. https://render.com/docs/free

Aiven. Aiven for MySQL free tier. https://aiven.io/docs/products/mysql/concepts/mysql-free-tier

Cloudinary. Billing and plans. https://cloudinary.com/documentation/billing_and_plans

OpenStreetMap Foundation. Tile Usage Policy. https://operations.osmfoundation.org/policies/tiles/

Flutter. Documentación oficial. https://docs.flutter.dev/

Node.js. Documentación oficial. https://nodejs.org/docs/latest-v24.x/api/

Oracle. MySQL 8.4 Reference Manual. https://dev.mysql.com/doc/refman/8.4/en/

Nissan. 2016 Nissan Rogue Press Kit. https://usa.nissannews.com/en-US/releases/us-2016-nissan-rogue-press-kit

Mitsubishi Motors. 2017 Outlander, folleto de fabricante distribuido por Dealer eProcess. https://cdn.dealereprocess.org/cdn/brochures/mitsubishi/2017-outlander.pdf

Fuentes consultadas al 29 de octubre de 2026. Las referencias técnicas explican tecnologías y modelos generales; no acreditan la versión exacta de una unidad sin su documentación.
