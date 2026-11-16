# Propuesta visual para AutoRent

Los fundamentos se encuentran en `mobile/lib/core/theme/` y `mobile/lib/shared/widgets/`: colores, tipografía Inter, tema Material 3 y botones, campos y tarjetas compartidos. El negro deja protagonismo a las fotos; el dorado identifica acciones y tarifas. Las tarifas pendientes dicen «Tarifa por confirmar».

## Recorrido del cliente

1. **Acceso y registro:** marca AutoRent, título grande, campos claros y botón principal dorado para iniciar sesión o crear la cuenta. Acceso al catálogo sin cuenta; solo reservar exige iniciar sesión.
2. **Catálogo:** encabezado «Encuentra tu próximo viaje», las tres unidades reales en tarjetas con fotografías grandes, filtros de categoría/marca/modelo, precio, kilometraje y fechas en una hoja inferior. Acción principal: ver vehículo. Navegación inferior: Vehículos, Reservas, Mapa y Cuenta.
3. **Detalle:** galería horizontal, nombre y color, ficha técnica con pendientes visibles, tarifa y estado. Acción principal: seleccionar fechas. No presentar como comprobada una especificación que solo sea una referencia del modelo.
4. **Reserva:** fecha y hora de inicio y fin, puntos de entrega y devolución, desglose de días y total devuelto por el servidor. Acción principal: confirmar reserva. Una misma operación conserva su identificador al reintentar para evitar duplicados.
5. **Historial y detalle de reserva:** tarjetas con código, vehículo, período, estado y total. Cancelación con confirmación cuando corresponda. Entregas y devoluciones se muestran como eventos del alquiler.
6. **Mapa:** ubicaciones reales activas y atribución OpenStreetMap. Seleccionar un punto muestra dirección; si no hay ubicaciones configuradas, se explica sin mostrar direcciones ficticias.
7. **Cuenta y avisos:** perfil, acceso a notificaciones, cierre de sesión y acceso a administración solo para administradores.

## Administración

1. **Flota:** lista paginada de unidades con botones «Agregar vehículo» y «Editar». Formularios para datos, estado, publicación, fotos y ficha; no hay límite fijo de tres unidades.
2. **Reservas:** todas las operaciones con filtro de estado, detalle del cliente y botones de entrega/devolución según el estado.
3. **Entrega/devolución:** formulario corto para kilómetros y observaciones; en devolución, ubicación actual. Acción principal: registrar operación.
4. **Ubicaciones:** lista y formulario de nombre, dirección y coordenadas, con estado activo. Las ubicaciones de demostración permanecen desactivadas.

Los formularios y tarjetas reutilizan los seis fundamentos. Las pantallas incluyen carga, vacío, error recuperable y adaptación a teléfonos y pantallas anchas. Se respeta el escalado de texto y las preferencias de movimiento reducido. La propuesta requiere aprobación antes de implementar estas pantallas Flutter.
