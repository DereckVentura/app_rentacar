CREATE TABLE reservation_expirations (
 id INTEGER PRIMARY KEY, codigo TEXT NOT NULL UNIQUE, user_id INTEGER NOT NULL,
 vehicle_id INTEGER NOT NULL, inicio TEXT NOT NULL, fin TEXT NOT NULL,
 operation_key TEXT NOT NULL UNIQUE, fingerprint TEXT NOT NULL,
 cliente TEXT NOT NULL, vehiculo TEXT NOT NULL, expired_at TEXT NOT NULL
);
--> statement-breakpoint
CREATE TABLE reservation_notifications (
 id INTEGER PRIMARY KEY AUTOINCREMENT, event_key TEXT NOT NULL UNIQUE,
 user_id INTEGER NOT NULL, codigo TEXT NOT NULL, message TEXT NOT NULL,
 created_at TEXT NOT NULL, read_at TEXT
);
--> statement-breakpoint
CREATE INDEX reservations_validation_deadline ON reservations(estado,deposit_due_at);
