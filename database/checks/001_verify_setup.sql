-- AutoRent | Consultas de comprobación: no modifican datos del proyecto.
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET time_zone = '+00:00';

USE autorent;

SELECT DATABASE() AS base_de_datos,
       VERSION() AS version_mysql,
       @@session.time_zone AS zona_horaria_sesion;

-- Cantidades esperadas inmediatamente después de cargar el catálogo inicial.
-- Cambiarán cuando la API permita registrar usuarios y operaciones.
SELECT 'usuarios' AS tabla, COUNT(*) AS filas, 0 AS filas_iniciales_esperadas FROM usuarios
UNION ALL SELECT 'categorias', COUNT(*), 3 FROM categorias
UNION ALL SELECT 'marcas', COUNT(*), 3 FROM marcas
UNION ALL SELECT 'modelos', COUNT(*), 6 FROM modelos
UNION ALL SELECT 'ubicaciones', COUNT(*), 2 FROM ubicaciones
UNION ALL SELECT 'vehiculos', COUNT(*), 6 FROM vehiculos
UNION ALL SELECT 'reservas', COUNT(*), 0 FROM reservas
UNION ALL SELECT 'alquileres', COUNT(*), 0 FROM alquileres
UNION ALL SELECT 'notificaciones', COUNT(*), 0 FROM notificaciones;

-- Relación del vehículo con marca, modelo, categoría y ubicación.
SELECT v.placa,
       ma.nombre AS marca,
       mo.nombre AS modelo,
       c.nombre AS categoria,
       v.anio,
       v.precio_dia,
       v.estado_operativo,
       u.nombre AS ubicacion
FROM vehiculos AS v
JOIN modelos AS mo ON mo.id = v.modelo_id
JOIN marcas AS ma ON ma.id = mo.marca_id
JOIN categorias AS c ON c.id = v.categoria_id
JOIN ubicaciones AS u ON u.id = v.ubicacion_actual_id
ORDER BY v.id;

-- Ejemplo fijo: del 10/11/2026 a las 14:00 UTC al 11/11/2026 a las 16:00 UTC.
-- Son 26 horas: se cobran 2 bloques de 24 horas. Con el catálogo inicial
-- aparecerán 5 vehículos; DEMO-006 no aparece porque está en mantenimiento.
-- DIV calcula el redondeo hacia arriba sin aproximaciones de punto flotante.
-- Los períodos se comparan como [inicio, fin): se permite empezar justo al
-- terminar otra reserva. Confirmadas y en curso bloquean el calendario.
WITH periodo AS (
    SELECT CAST('2026-11-10 14:00:00' AS DATETIME(6)) AS inicio_utc,
           CAST('2026-11-11 16:00:00' AS DATETIME(6)) AS fin_utc
), duracion AS (
    SELECT inicio_utc,
           fin_utc,
           TIMESTAMPDIFF(MICROSECOND, inicio_utc, fin_utc) AS microsegundos
    FROM periodo
), cotizacion AS (
    SELECT inicio_utc,
           fin_utc,
           microsegundos,
           (microsegundos + 86399999999) DIV 86400000000 AS unidades_cobradas
    FROM duracion
)
SELECT v.placa,
       c.inicio_utc,
       c.fin_utc,
       c.microsegundos / 3600000000 AS horas,
       c.unidades_cobradas,
       v.precio_dia,
       CAST(v.precio_dia * c.unidades_cobradas AS DECIMAL(12, 2)) AS total_usd
FROM vehiculos AS v
CROSS JOIN cotizacion AS c
WHERE v.estado_operativo = 'operativo'
  AND NOT EXISTS (
      SELECT 1
      FROM reservas AS r
      WHERE r.vehiculo_id = v.id
        AND r.estado IN ('confirmada', 'en_curso')
        AND c.inicio_utc < r.fin_utc
        AND c.fin_utc > r.inicio_utc
  )
ORDER BY v.id;

-- Todas las cantidades siguientes deben ser 0.
-- Algunas reglas entre tablas se comprobarán en la API, además de estas
-- consultas. Detectarlas aquí no implementa su validación al guardar.
SELECT 'usuarios_activo_invalido' AS comprobacion, COUNT(*) AS incidencias
FROM usuarios WHERE activo NOT IN (0, 1)
UNION ALL
SELECT 'categorias_activo_invalido', COUNT(*)
FROM categorias WHERE activo NOT IN (0, 1)
UNION ALL
SELECT 'marcas_activo_invalido', COUNT(*)
FROM marcas WHERE activo NOT IN (0, 1)
UNION ALL
SELECT 'ubicaciones_datos_invalidos', COUNT(*)
FROM ubicaciones
WHERE activo NOT IN (0, 1) OR latitud NOT BETWEEN -90 AND 90
   OR longitud NOT BETWEEN -180 AND 180
UNION ALL
SELECT 'vehiculos_datos_invalidos', COUNT(*)
FROM vehiculos WHERE anio < 1886 OR kilometraje < 0 OR precio_dia < 0
UNION ALL
SELECT 'reservas_periodo_o_importes_invalidos', COUNT(*)
FROM reservas
WHERE fin_utc <= inicio_utc OR precio_dia_aplicado < 0
   OR unidades_cobradas < 1 OR total < 0
   OR total <> precio_dia_aplicado * unidades_cobradas
UNION ALL
SELECT 'reservas_unidades_incorrectas', COUNT(*)
FROM reservas
WHERE unidades_cobradas <>
    (TIMESTAMPDIFF(MICROSECOND, inicio_utc, fin_utc) + 86399999999) DIV 86400000000
UNION ALL
SELECT 'reservas_cancelacion_incoherente', COUNT(*)
FROM reservas
WHERE NOT (
    (estado = 'cancelada' AND cancelada_en IS NOT NULL)
    OR (estado <> 'cancelada' AND cancelada_en IS NULL AND motivo_cancelacion IS NULL)
)
UNION ALL
SELECT 'reservas_cliente_con_rol_incorrecto', COUNT(*)
FROM reservas AS r
JOIN usuarios AS u ON u.id = r.cliente_id
WHERE u.rol <> 'cliente'
UNION ALL
SELECT 'alquileres_cierre_incoherente', COUNT(*)
FROM alquileres
WHERE NOT (
    (devolucion_real_utc IS NULL AND km_regreso IS NULL AND recibido_por IS NULL)
    OR (devolucion_real_utc IS NOT NULL AND km_regreso IS NOT NULL AND recibido_por IS NOT NULL)
)
UNION ALL
SELECT 'alquileres_fechas_o_kilometraje_invalidos', COUNT(*)
FROM alquileres
WHERE devolucion_real_utc < salida_real_utc OR km_salida < 0 OR km_regreso < km_salida
UNION ALL
SELECT 'notificaciones_lectura_anticipada', COUNT(*)
FROM notificaciones WHERE leida_en < creada_en;

-- Inspección de solapamientos: el resultado esperado es 0.
-- Esta consulta no impide carreras entre solicitudes. La API deberá adquirir
-- el bloqueo del vehículo dentro de una transacción antes de reservar.
SELECT COUNT(*) AS pares_de_reservas_solapadas
FROM reservas AS a
JOIN reservas AS b
    ON b.vehiculo_id = a.vehiculo_id
   AND b.id > a.id
   AND b.estado IN ('confirmada', 'en_curso')
   AND a.inicio_utc < b.fin_utc
   AND a.fin_utc > b.inicio_utc
WHERE a.estado IN ('confirmada', 'en_curso');
