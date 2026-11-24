import { awaitingReviewSql, deadlineSql, expireReservationsStatement } from './pending-reservations';

// D1 batches keep expiration, its audit entry and the customer notice together.
export async function expireReservations(db: D1Database) {
  const where = `${awaitingReviewSql} AND ${deadlineSql}<=julianday(?)`;
  const now = new Date().toISOString();
  if (!await db.prepare(`SELECT 1 FROM reservations WHERE ${where} LIMIT 1`).bind(now).first()) return;
  await db.batch([
    db.prepare(`INSERT OR IGNORE INTO reservation_expirations(id,codigo,user_id,vehicle_id,inicio,fin,operation_key,fingerprint,cliente,vehiculo,expired_at)
      SELECT r.id,r.codigo,r.user_id,r.vehicle_id,r.inicio,r.fin,r.operation_key,r.fingerprint,
      u.nombres||' '||u.apellidos,json_extract(v.data,'$.marca.nombre')||' '||json_extract(v.data,'$.modelo.nombre'),datetime('now')
      FROM reservations r JOIN users u ON u.id=r.user_id JOIN vehicles v ON v.id=r.vehicle_id
      WHERE ${where.replaceAll(/\b(estado|inicio|validation_due_at|deposit_due_at|created_at)\b/g, 'r.$1')}`).bind(now),
    db.prepare(expireReservationsStatement('?')).bind(now, now),
    db.prepare(`INSERT OR IGNORE INTO reservation_notifications(event_key,user_id,codigo,message,created_at)
      SELECT 'expired:'||a.id,a.user_id,a.codigo,r.review_note,r.reviewed_at
      FROM reservation_expirations a JOIN reservations r ON r.id=a.id AND r.codigo=a.codigo
      WHERE r.estado='vencida' AND r.review_note IS NOT NULL AND r.reviewed_at=?`).bind(now),
  ]);
}
