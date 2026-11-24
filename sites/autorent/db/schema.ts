import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core';
export const users = sqliteTable('users', {
  id: integer('id').primaryKey({autoIncrement:true}), email: text('email').notNull().unique(),
  passwordHash: text('password_hash').notNull(), nombres: text('nombres').notNull(), apellidos: text('apellidos').notNull(),
  telefono: text('telefono'), rol: text('rol').notNull().default('cliente'), acceptance: text('acceptance'),
  privateAdmin: integer('private_admin').notNull().default(0), tokenVersion: integer('token_version').notNull().default(0),
});
export const driverDocuments = sqliteTable('driver_documents', {
 id:text('id').primaryKey(),userId:integer('user_id').notNull().references(()=>users.id),
 documentType:text('document_type').notNull(),country:text('country').notNull(),holder:text('holder').notNull(),expiresOn:text('expires_on').notNull(),
 frontKey:text('front_key').notNull(),frontType:text('front_type').notNull(),backKey:text('back_key'),backType:text('back_type'),
 status:text('status').notNull().default('pendiente'),createdAt:text('created_at').notNull(),
 assessment:text('assessment'),
});
export const vehicles = sqliteTable('vehicles', { id:integer('id').primaryKey(), data:text('data').notNull() });
export const locations = sqliteTable('locations', { id:integer('id').primaryKey(), data:text('data').notNull() });
export const reservations = sqliteTable('reservations', {
  id:integer('id').primaryKey({autoIncrement:true}), codigo:text('codigo').notNull().unique(),
  userId:integer('user_id').notNull().references(()=>users.id), vehicleId:integer('vehicle_id').notNull().references(()=>vehicles.id),
  inicio:text('inicio').notNull(), fin:text('fin').notNull(), estado:text('estado').notNull().default('confirmada'),
  price:integer('price').notNull(), days:integer('days').notNull(), total:integer('total').notNull(),
  pickup:integer('pickup').notNull().references(()=>locations.id), dropoff:integer('dropoff').notNull().references(()=>locations.id),
  operationKey:text('operation_key').notNull().unique(), fingerprint:text('fingerprint').notNull(),
  acceptance:text('acceptance').notNull(), createdAt:text('created_at').notNull(), kmOut:integer('km_out'), kmIn:integer('km_in'),
  selectedDates:text('selected_dates'),documentId:text('document_id').references(()=>driverDocuments.id),
  depositRequired:integer('deposit_required').notNull().default(0),depositDueAt:text('deposit_due_at'),bankSnapshot:text('bank_snapshot'),
  receiptKey:text('receipt_key'),receiptType:text('receipt_type'),receiptSubmittedAt:text('receipt_submitted_at'),
  depositReceived:integer('deposit_received'),depositReference:text('deposit_reference'),reviewNote:text('review_note'),
  reviewedBy:integer('reviewed_by').references(()=>users.id),reviewedAt:text('reviewed_at'),
 validationDueAt:text('validation_due_at'),
});
export const settings = sqliteTable('settings',{ key:text('key').primaryKey(), data:text('data').notNull() });
export const privacyRequests = sqliteTable('privacy_requests', {
  id:integer('id').primaryKey({autoIncrement:true}), userId:integer('user_id').notNull().references(()=>users.id), data:text('data').notNull(),
});
export const loginAttempts = sqliteTable('login_attempts', { key:text('key').primaryKey(), count:integer('count').notNull(), expires:integer('expires').notNull() });
