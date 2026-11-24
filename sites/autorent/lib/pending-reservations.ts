// The database clock decides expiry, including when every client is closed.
// Reads and conditional writes use the deadline as part of the state itself.
const validationDueSql = "COALESCE(julianday(validation_due_at), julianday(deposit_due_at), julianday(created_at) + 0.125)";
export const deadlineSql = `MIN(${validationDueSql}, julianday(inicio))`;
export const awaitingReviewSql = "estado IN ('pendiente','lista_para_aprobar')";
export const activeReservationSql = `(estado IN ('confirmada','en_curso') OR (${awaitingReviewSql} AND ${deadlineSql}>julianday('now')))`;
export const expirationMessage = 'Tu reserva expiró por falta de validación.';
const expirationReasonSql = `CASE WHEN julianday(inicio)<=${validationDueSql} THEN 'Tu reserva expiró al llegar la hora de recogida.' ELSE '${expirationMessage}' END`;
export function expireReservationsStatement(timestamp = "strftime('%Y-%m-%dT%H:%M:%fZ','now')") {
  return `UPDATE reservations SET estado='vencida',review_note=${expirationReasonSql},reviewed_at=${timestamp}
   WHERE ${awaitingReviewSql} AND ${deadlineSql}<=julianday(${timestamp})`;
}
export const expireReservationsSql = expireReservationsStatement();
export const createReservationSql = `WITH decision AS (
  SELECT CASE WHEN ?='confirmada' AND EXISTS(SELECT 1 FROM settings WHERE key='payment')
    THEN 'lista_para_aprobar' ELSE ? END AS estado
 )
 INSERT INTO reservations(codigo,user_id,vehicle_id,inicio,fin,price,days,total,pickup,dropoff,operation_key,fingerprint,acceptance,created_at,document_id,estado,validation_due_at,review_note,reviewed_at)
 SELECT ?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,decision.estado,?,
   CASE WHEN decision.estado='lista_para_aprobar' THEN 'La licencia pasó la revisión con IA. El pago está pendiente de verificación.' ELSE ? END,?
 FROM vehicles AS current CROSS JOIN decision
 WHERE current.id=? AND CAST(json_extract(current.data,'$.precio_dia') AS REAL)=? AND json_extract(current.data,'$.reservable')=1 AND json_extract(current.data,'$.publicado')=1 AND json_extract(current.data,'$.estado_operativo')='disponible'
   AND julianday(?)>julianday('now')
   AND EXISTS(SELECT 1 FROM locations WHERE id=? AND json_extract(data,'$.activo')=1 AND json_extract(data,'$.eliminado') IS NOT 1)
   AND EXISTS(SELECT 1 FROM locations WHERE id=? AND json_extract(data,'$.activo')=1 AND json_extract(data,'$.eliminado') IS NOT 1)
   AND NOT EXISTS(SELECT 1 FROM reservations WHERE vehicle_id=? AND ${activeReservationSql} AND inicio<? AND fin>?) RETURNING *`;
export const validateReservationSql = `UPDATE reservations SET estado='confirmada',review_note='Tu reserva fue aprobada.',reviewed_by=?,reviewed_at=?
 WHERE id=? AND ((${awaitingReviewSql} AND ${deadlineSql}>julianday('now')) OR ((estado='denegada_automatica' OR (estado='denegada' AND reviewed_by IS NULL)) AND ${deadlineSql}>julianday('now') AND julianday(fin)>julianday('now')))
 AND EXISTS (SELECT 1 FROM vehicles WHERE id=reservations.vehicle_id AND json_extract(data,'$.eliminado') IS NOT 1)
 AND (document_id IS NULL OR EXISTS (SELECT 1 FROM driver_documents WHERE id=reservations.document_id AND expires_on>=date(reservations.fin,'-6 hours','-0.001 seconds')))
 AND NOT EXISTS (SELECT 1 FROM reservations AS other WHERE other.id<>reservations.id AND other.vehicle_id=reservations.vehicle_id
 AND ${activeReservationSql.replaceAll(/\b(estado|validation_due_at|deposit_due_at|created_at|inicio)\b/g, 'other.$1')} AND other.inicio<reservations.fin AND other.fin>reservations.inicio) RETURNING *`;
export function validationDeadline(createdAt: string, minutes = 180): string {
  return new Date(Date.parse(createdAt) + minutes * 60_000).toISOString();
}

export async function reservationMinutes(db: D1Database): Promise<number> {
  const setting = await db.prepare("SELECT data FROM settings WHERE key='reservation_minutes'").first<{data: string}>();
  const minutes = Number(setting?.data);
  if (Number.isInteger(minutes) && minutes >= 1 && minutes <= 4320) return minutes;
  const legacy = await db.prepare("SELECT json_extract(data,'$.hours') AS hours FROM settings WHERE key='reservation_config' AND json_valid(data)").first<{hours: number}>();
  const hours = legacy?.hours ?? 3;
  return Number.isInteger(hours) && hours >= 1 && hours <= 72 ? hours * 60 : 180;
}
