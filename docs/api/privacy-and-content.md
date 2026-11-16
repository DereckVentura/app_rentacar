# API de ayuda contenido y privacidad

Todas las rutas usan /api/v1. Las respuestas JSON contienen success y data o error. La API de exportación conserva este envoltorio y responde con Content-Disposition para permitir descarga. No colocar tokens en parámetros de URL.

| Método y ruta | Acceso | Función |
|---|---|---|
| GET /content | Público | Datos del negocio FAQ aviso de privacidad condiciones y versión SHA-256 |
| GET /legal/privacidad | Público | Descargar aviso vigente como texto |
| GET /legal/terminos | Público | Descargar condiciones vigentes como texto |
| PUT /admin/content | Administración | Actualizar contacto y preguntas frecuentes |
| GET /privacy/export | Autenticado | Exportar perfil reservas alquileres avisos aceptaciones y solicitudes propios |
| GET /privacy/requests?page=1&limit=20 | Autenticado | Cliente ve sus solicitudes; administración ve las que debe gestionar |
| POST /privacy/requests | Autenticado | Registrar solicitud y devolver constancia |
| PUT /admin/privacy/requests/:id | Administración | Responder y emitir un aviso privado al solicitante |

Registro y creación de reservas requieren un objeto aceptacion con version vigente, privacidad true y terminos true. Las casillas de la interfaz están desmarcadas inicialmente. Una versión antigua produce 409 LEGAL_VERSION_CHANGED; el cliente debe consultar y revisar los documentos antes de confirmar de nuevo. El texto, hash, contexto y fecha se guardan con el registro o la reserva en su transacción.

El cuerpo para una solicitud contiene tipo y detalle de hasta 2000 caracteres. Tipos: acceso, rectificacion, supresion, oposicion, portabilidad, olvido, limitacion, retiro_consentimiento y reclamo. Se permiten diez solicitudes por cuenta al día; los listados usan páginas de máximo 50.

Una respuesta administrativa contiene estado en_revision o respondida y respuesta de hasta 3000 caracteres. Cambiar el estado no ejecuta eliminación o rectificación automática de datos. La gestión y cualquier excepción deben documentarse conforme al procedimiento y al marco aplicable. Las respuestas previas no se versionan en su texto; la acción se registra en auditoría.

El contenido público permite hasta 30 preguntas con sus respuestas. La aplicación sigue siendo académica. Activar oferta comercial requiere modificar y revisar el alcance de los documentos y las condiciones del negocio; no hay un interruptor de cumplimiento automático.
