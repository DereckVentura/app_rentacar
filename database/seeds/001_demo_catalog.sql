-- AutoRent | Catálogo de demostración. Ejecutar una sola vez tras la migración.
-- Todos los vehículos, placas, direcciones y coordenadas son datos de ejemplo.
-- No representan el inventario ni las ubicaciones de Rent a Car Molina.
-- No se crean usuarios, contraseñas, administradores, reservas ni alquileres.
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET time_zone = '+00:00';

USE autorent;

START TRANSACTION;

INSERT INTO categorias (id, nombre, descripcion, activo) VALUES
    (1, 'Sedán', 'Automóviles de demostración para uso urbano y viajes.', TRUE),
    (2, 'SUV', 'Vehículos utilitarios de demostración.', TRUE),
    (3, 'Pickup', 'Vehículos de demostración con área de carga.', TRUE);

INSERT INTO marcas (id, nombre, activo) VALUES
    (1, 'Toyota', TRUE),
    (2, 'Hyundai', TRUE),
    (3, 'Kia', TRUE);

INSERT INTO modelos (id, marca_id, nombre) VALUES
    (1, 1, 'Corolla'),
    (2, 1, 'RAV4'),
    (3, 1, 'Hilux'),
    (4, 2, 'Accent'),
    (5, 2, 'Tucson'),
    (6, 3, 'Rio');

-- Coordenadas ficticias para practicar el mapa; deben sustituirse por datos
-- verificados de la empresa antes de usar el sistema con clientes reales.
INSERT INTO ubicaciones
    (id, nombre, tipo, direccion, latitud, longitud, activo)
VALUES
    (1, 'Sucursal de demostración A', 'sucursal',
        'Dirección ficticia A. Solo para demostración.',
        13.7000000, -88.1000000, TRUE),
    (2, 'Punto autorizado de demostración B', 'punto_autorizado',
        'Dirección ficticia B. Solo para demostración.',
        13.7050000, -88.0950000, TRUE);

-- Cinco vehículos operativos y uno en mantenimiento.
INSERT INTO vehiculos
    (id, placa, categoria_id, modelo_id, ubicacion_actual_id, anio,
     kilometraje, precio_dia, estado_operativo, descripcion, imagen_url)
VALUES
    (1, 'DEMO-001', 1, 1, 1, 2023, 35000, 35.00, 'operativo',
        'Vehículo de demostración: Toyota Corolla.', NULL),
    (2, 'DEMO-002', 2, 2, 1, 2024, 18000, 60.00, 'operativo',
        'Vehículo de demostración: Toyota RAV4.', NULL),
    (3, 'DEMO-003', 3, 3, 2, 2022, 52000, 65.00, 'operativo',
        'Vehículo de demostración: Toyota Hilux.', NULL),
    (4, 'DEMO-004', 1, 4, 2, 2023, 28000, 32.00, 'operativo',
        'Vehículo de demostración: Hyundai Accent.', NULL),
    (5, 'DEMO-005', 2, 5, 1, 2024, 15000, 58.00, 'operativo',
        'Vehículo de demostración: Hyundai Tucson.', NULL),
    (6, 'DEMO-006', 1, 6, 2, 2022, 45000, 30.00, 'mantenimiento',
        'Vehículo de demostración: Kia Rio en mantenimiento.', NULL);

COMMIT;
