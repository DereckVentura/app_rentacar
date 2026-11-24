CREATE TABLE `driver_documents` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` integer NOT NULL,
	`document_type` text NOT NULL,
	`country` text NOT NULL,
	`holder` text NOT NULL,
	`expires_on` text NOT NULL,
	`front_key` text NOT NULL,
	`front_type` text NOT NULL,
	`back_key` text,
	`back_type` text,
	`status` text DEFAULT 'pendiente' NOT NULL,
	`created_at` text NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
ALTER TABLE `reservations` ADD `selected_dates` text;--> statement-breakpoint
ALTER TABLE `reservations` ADD `document_id` text REFERENCES driver_documents(id);--> statement-breakpoint
ALTER TABLE `reservations` ADD `deposit_required` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE `reservations` ADD `deposit_due_at` text;--> statement-breakpoint
ALTER TABLE `reservations` ADD `bank_snapshot` text;--> statement-breakpoint
ALTER TABLE `reservations` ADD `receipt_key` text;--> statement-breakpoint
ALTER TABLE `reservations` ADD `receipt_type` text;--> statement-breakpoint
ALTER TABLE `reservations` ADD `receipt_submitted_at` text;--> statement-breakpoint
ALTER TABLE `reservations` ADD `deposit_received` integer;--> statement-breakpoint
ALTER TABLE `reservations` ADD `deposit_reference` text;--> statement-breakpoint
ALTER TABLE `reservations` ADD `review_note` text;--> statement-breakpoint
ALTER TABLE `reservations` ADD `reviewed_by` integer REFERENCES users(id);--> statement-breakpoint
ALTER TABLE `reservations` ADD `reviewed_at` text;--> statement-breakpoint
ALTER TABLE `users` ADD `private_admin` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE `users` ADD `token_version` integer DEFAULT 0 NOT NULL;