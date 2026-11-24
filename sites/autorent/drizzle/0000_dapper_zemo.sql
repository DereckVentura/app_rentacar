CREATE TABLE `locations` (
	`id` integer PRIMARY KEY NOT NULL,
	`data` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `login_attempts` (
	`key` text PRIMARY KEY NOT NULL,
	`count` integer NOT NULL,
	`expires` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `privacy_requests` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`user_id` integer NOT NULL,
	`data` text NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE TABLE `reservations` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`codigo` text NOT NULL,
	`user_id` integer NOT NULL,
	`vehicle_id` integer NOT NULL,
	`inicio` text NOT NULL,
	`fin` text NOT NULL,
	`estado` text DEFAULT 'confirmada' NOT NULL,
	`price` integer NOT NULL,
	`days` integer NOT NULL,
	`total` integer NOT NULL,
	`pickup` integer NOT NULL,
	`dropoff` integer NOT NULL,
	`operation_key` text NOT NULL,
	`fingerprint` text NOT NULL,
	`acceptance` text NOT NULL,
	`created_at` text NOT NULL,
	`km_out` integer,
	`km_in` integer,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`pickup`) REFERENCES `locations`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`dropoff`) REFERENCES `locations`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE UNIQUE INDEX `reservations_codigo_unique` ON `reservations` (`codigo`);--> statement-breakpoint
CREATE UNIQUE INDEX `reservations_operation_key_unique` ON `reservations` (`operation_key`);--> statement-breakpoint
CREATE TABLE `settings` (
	`key` text PRIMARY KEY NOT NULL,
	`data` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `users` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`email` text NOT NULL,
	`password_hash` text NOT NULL,
	`nombres` text NOT NULL,
	`apellidos` text NOT NULL,
	`telefono` text,
	`rol` text DEFAULT 'cliente' NOT NULL,
	`acceptance` text
);
--> statement-breakpoint
CREATE UNIQUE INDEX `users_email_unique` ON `users` (`email`);--> statement-breakpoint
CREATE TABLE `vehicles` (
	`id` integer PRIMARY KEY NOT NULL,
	`data` text NOT NULL
);
