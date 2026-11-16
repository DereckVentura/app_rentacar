ALTER TABLE reservas MODIFY estado ENUM('pendiente', 'confirmada', 'en_curso', 'completada', 'cancelada', 'no_presentado', 'vencida') NOT NULL DEFAULT 'pendiente';

CREATE TABLE payment_details (
  id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
  contenido JSON NOT NULL,
  actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT chk_payment_singleton CHECK (id = 1)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
