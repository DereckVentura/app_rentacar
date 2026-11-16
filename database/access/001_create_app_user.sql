-- Ejecutar UNA vez con la cuenta root, después de crear la base autorent.
-- MySQL mostrará una contraseña aleatoria: guardarla localmente en backend/.env.
-- No pegar la contraseña en el chat ni guardarla en este script.
-- Si la cuenta ya existe, detenerse: este archivo no restablece contraseñas.
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION generated_random_password_length = 32;

CREATE USER 'autorent_app'@'127.0.0.1' IDENTIFIED BY RANDOM PASSWORD;

-- La API administra datos; las migraciones se aplican por separado con root.
GRANT SELECT, INSERT, UPDATE, DELETE
    ON autorent.*
    TO 'autorent_app'@'127.0.0.1';
