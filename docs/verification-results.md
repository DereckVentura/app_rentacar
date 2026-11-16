# Resultados de verificación

Fecha de entrega: 29 de octubre de 2026. Entorno local Windows con Node.js 24, MySQL 8.4 y Flutter 3.47.8. Las verificaciones utilizan datos ficticios y no acreditan rendimiento comercial ni cumplimiento legal integral.

| Verificación | Resultado comprobado | Alcance |
|---|---|---|
| TypeScript typecheck y build | Correctos | Servidor y pruebas |
| Pruebas automatizadas backend | 93 aprobadas | Acceso, validadores, permisos, catálogo, configuración, dinero y documentos |
| Integración de operaciones MySQL HTTP | 29 comprobaciones aprobadas | Seis intentos simultáneos, reintentos, permisos, tarifas, cancelación, entrega, devolución y avisos |
| Integración de privacidad MySQL HTTP | 18 comprobaciones aprobadas | Rechazo de aceptación ausente o antigua, texto inmutable, aislamiento, exportación, respuestas, constancia de reserva y reintento tras cambio de documentos |
| Análisis Flutter | Sin observaciones en la comprobación final | Código de la aplicación |
| Pruebas Flutter | 5 aprobadas | Horario, sesión, catálogo pendiente, acceso y casillas legales explícitas |
| Compilación web | Correcta | Motor y fuentes incluidos, API de demostración en puerto 3002 |
| Migración de la demo | Versiones 001 a 004 aplicadas | Base independiente autorent_demo en puerto 3319 |

Los archivos verify-operations.mjs y verify-privacy.mjs documentan los casos de integración. El primero exige una base temporal vacía para no borrar datos automáticamente. El segundo utiliza exclusivamente la instancia temporal autorizada y comprueba que las solicitudes de otros usuarios no se muestran.

El respaldo de la base existente se creó antes de preparar actualizaciones. Las migraciones nuevas no se aplicaron a esa base con la cuenta de conexión porque no tiene permisos DDL. El iniciador universitario utiliza una base nueva y no necesita esa contraseña. El procedimiento para la base existente se documenta por separado.

Las comprobaciones de navegador y Android se acompañan de su resultado específico en el acta final de entrega. No se debe interpretar la mera existencia de una carpeta Android como un instalador compilado o una prueba en dispositivo físico. No se efectuaron carga comercial, auditoría de seguridad externa, cobro real ni publicación pública.
