# Guion de demostración y defensa

Duración sugerida: 12 a 15 minutos. Ajustar al tiempo concedido por el docente. No se incluye nombre de universidad o integrantes porque no se proporcionaron.

1. Explicar el problema y el alcance académico. Mostrar el aviso de demostración y los tres vehículos; señalar tarifas y versiones pendientes.
2. Explicar la arquitectura cliente, API y MySQL usando el diagrama. Indicar por qué el servidor conserva las reglas críticas.
3. Abrir ayuda y FAQ. Consultar los documentos antes del registro. Mostrar que ambas casillas empiezan desmarcadas.
4. Ingresar como cliente de prueba. Mostrar historial, solicitudes y exportación. Presentar un reclamo ficticio y anotar la constancia.
5. Ingresar como administración. Abrir la edición de un vehículo y las preguntas frecuentes. No guardar precios reales inexistentes.
6. Para demostrar reservas, configurar previamente un único vehículo con placa, kilometraje, ubicación y tarifa claramente ficticios en la base de demostración. Crear una ubicación de prueba con coordenadas conocidas. No afirmar que representa una sucursal real.
7. Como cliente, elegir fechas futuras, consultar el total, leer y aceptar documentos y confirmar. Mostrar la reserva y su aviso.
8. Explicar que el servidor comprueba solapamientos y tarifa otra vez. Utilizar el informe de pruebas para mostrar la carrera de seis solicitudes, sin ejecutar una prueba destructiva sobre la demostración.
9. Cancelar antes del inicio o utilizar una reserva de prueba preparada para entrega y devolución. Registrar kilómetros crecientes.
10. Explicar límites del alojamiento gratuito y pasos para una comercialización. Cerrar con resultados verificables y pendientes.

## Preguntas que conviene preparar

- ¿Por qué utilizar transacciones? Porque reserva, aviso y constancia deben quedar confirmados juntos; si un paso falla se revierte la operación.
- ¿Por qué bloquear un vehículo? Para que dos confirmaciones simultáneas no aprueben un mismo intervalo basándose en una lectura antigua.
- ¿Por qué no calcular dinero con double? Los decimales binarios pueden introducir errores; se calculan centavos enteros y se almacenan DECIMAL.
- ¿Cómo se revoca un token? La autenticación consulta el estado actual del usuario en cada solicitud; desactivar la cuenta impide seguir utilizándolo.
- ¿Cómo se evita que un cliente se vuelva administrador? El registro público fija el rol cliente y los permisos se comprueban en servidor.
- ¿Qué significa escalable aquí? Se pueden separar alojamientos y ampliar recursos sin reescribir los módulos. No significa que se haya medido capacidad para una cantidad determinada de usuarios.
- ¿La app ya cumple toda la ley? Tiene funciones de información y gestión de derechos, pero la operación comercial requiere datos, procedimientos y revisión profesional adicionales.
- ¿Qué falta para usar teléfonos reales? Una API HTTPS pública o accesible por red, compilación configurada para esa dirección y pruebas en dispositivos.
- ¿Cómo se usó asistencia de IA? Declarar su uso conforme a las reglas de la universidad. Los integrantes deben revisar y comprender código, pruebas y documentación; no atribuir entrevistas o resultados que no se realizaron.

## Revisión antes de presentar

- Ejecutar iniciar-demo.cmd y comprobar la web sin depender de una conexión pública.
- Abrir el archivo privado de accesos fuera de la proyección y luego cerrarlo.
- Abrir el informe PDF y los diagramas; llevar una copia local del código y documentos.
- Confirmar que el docente acepta el formato y completar los campos de portada.
- Mantener separadas la base de demostración, la de pruebas y la base existente.
