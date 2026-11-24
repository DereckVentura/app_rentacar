import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { test } from 'node:test';
import { DatabaseSync } from 'node:sqlite';
import { activeReservationSql, createReservationSql, expireReservationsSql, validateReservationSql, validationDeadline } from './pending-reservations';
import { expireReservations } from './reservation-lifecycle';
import { assessLicense, monthEnd } from './license-assessment';
import { assessLicenseWithAI, readLicenseWithAI, reservationDecision } from './license-ai';

function setup() {
  const db = new DatabaseSync(':memory:');
  const migrations = new URL('../drizzle/',import.meta.url);
  for(const path of readdirSync(migrations).filter(name=>name.endsWith('.sql')).sort())db.exec(readFileSync(new URL(path,migrations),'utf8'));
  db.exec(`INSERT INTO users(email,password_hash,nombres,apellidos) VALUES('test@example.invalid','stub','María','Díaz');
    INSERT INTO vehicles(id,data) VALUES(1,'{"marca":{"nombre":"Kia"},"modelo":{"nombre":"Sportage"}}'); INSERT INTO locations(id,data) VALUES(1,'{}');`);
  const stamp = (hours:number) => new Date(Date.now()+hours*3600000).toISOString();
  function insert(id:number,estado:string,created:number,inicio=24,fin=48,deadline:number|null=null){
    db.prepare(`INSERT INTO reservations(id,codigo,user_id,vehicle_id,inicio,fin,estado,price,days,total,pickup,dropoff,operation_key,fingerprint,acceptance,created_at,validation_due_at) VALUES(?,?,1,1,?,?,?,4000,1,4000,1,1,?,'fp','{}',?,?)`).run(id,`AR-${id}`,stamp(inicio),stamp(fin),estado,`op${id}`,stamp(created),deadline===null?null:stamp(deadline));
  }
  const approve = (id:number) => db.prepare(validateReservationSql).get(1,stamp(0),id);
  return {db,insert,approve};
}

test('el plazo anterior se conserva y el plazo nuevo usa los minutos elegidos', () => {
  assert.equal(validationDeadline('2026-11-11T23:30:00.000Z'), '2026-11-12T02:30:00.000Z');
  assert.equal(validationDeadline('2026-11-11T23:30:00.000Z', 20), '2026-11-11T23:50:00.000Z');
});

test('una solicitud vencida libera fechas sin visitas y deja su aviso al limpiarse', () => {
  const {db,insert,approve} = setup();
  try {
    insert(1,'pendiente',-4);
    insert(2,'lista_para_aprobar',-1,24,48,-0.1);
    insert(3,'confirmada',-4);
    assert.deepEqual(db.prepare(`SELECT id FROM reservations WHERE ${activeReservationSql} ORDER BY id`).all().map(r=>r.id),[3]);
    assert.equal(approve(1),undefined);
    db.exec(expireReservationsSql);db.exec(expireReservationsSql);
    assert.deepEqual(db.prepare('SELECT estado FROM reservations ORDER BY id').all().map(r=>r.estado),['vencida','vencida','confirmada']);
    assert.match(String(db.prepare('SELECT review_note FROM reservations WHERE id=2').get()?.review_note),/expiró/);
  } finally {db.close();}
});

test('la tarea registra un solo aviso y conserva la reserva con su plazo anterior', async () => {
  const {db,insert} = setup();
  const batch = async (statements: Array<{run: () => unknown}>) => {
    db.exec('BEGIN');
    try { statements.forEach(statement => statement.run()); db.exec('COMMIT'); }
    catch (error) { db.exec('ROLLBACK'); throw error; }
  };
  const d1 = {
    batch,
    prepare(sql: string) {
      const statement = db.prepare(sql);
      return {
        bind: (...values: string[]) => ({
          first: async () => statement.get(...values),
          run: () => statement.run(...values),
        }),
      };
    },
  } as unknown as D1Database;
  try {
    insert(1,'pendiente',-4);
    insert(2,'pendiente',-4);
    db.prepare('UPDATE reservations SET deposit_due_at=? WHERE id=?')
      .run(new Date(Date.now()+3600000).toISOString(),2);
    insert(3,'pendiente',-1,-0.5,48,1);
    await expireReservations(d1);
    await expireReservations(d1);
    assert.equal(db.prepare('SELECT estado FROM reservations WHERE id=1').get()?.estado,'vencida');
    assert.equal(db.prepare('SELECT estado FROM reservations WHERE id=2').get()?.estado,'pendiente');
    assert.equal(db.prepare('SELECT COUNT(*) AS total FROM reservation_expirations').get()?.total,2);
    assert.equal(db.prepare('SELECT COUNT(*) AS total FROM reservation_notifications').get()?.total,2);
    assert.match(String(db.prepare("SELECT message FROM reservation_notifications WHERE codigo='AR-3'").get()?.message),/hora de recogida/);
  } finally {db.close();}
});

test('revisar un falso negativo no puede desplazar una reserva y se ejecuta una sola vez', () => {
  const {db,insert,approve} = setup();
  try {
    insert(1,'denegada_automatica',-1);
    insert(2,'pendiente',-0.5);
    assert.equal(approve(1),undefined);
    db.exec("UPDATE reservations SET estado='denegada' WHERE id=2");
    assert.equal(approve(1)?.estado,'confirmada');
    assert.equal(approve(1),undefined);
  } finally {db.close();}
});

test('vencimiento al final del mes, coincidencia sin tildes y revisión de lecturas incompletas', () => {
  assert.equal(monthEnd('2028-02'),'2028-02-29');
  assert.equal(monthEnd('2028-13'),null);
  assert.equal(assessLicense({nombre:'DÍAZ MARIA',vencimiento:'2028-02'},'María Díaz','2028-02-29','2028-02-29').estado,'lista');
  assert.equal(assessLicense({},'María Díaz','2028-02-29','2028-02-29').estado,'revision_manual');
  assert.equal(assessLicense({calidad:'borrosa'},'María Díaz','2028-02-29','2028-02-29').motivo,'Foto borrosa');
  assert.equal(assessLicense({},'María Díaz','2028-02-29','2028-03-01').motivo,'Licencia vencida');
});

test('la hora de recogida puede hacer vencer la solicitud antes que el plazo de validación', () => {
  const {db,insert,approve} = setup();
  try {
    insert(1,'pendiente',-1,-0.5,48,1);
    insert(2,'confirmada',-1,-0.5,48,1);
    assert.deepEqual(db.prepare(`SELECT id FROM reservations WHERE ${activeReservationSql}`).all().map(row=>row.id),[2]);
    assert.equal(approve(1),undefined);
    db.exec(expireReservationsSql);
    const expired = db.prepare('SELECT estado,review_note FROM reservations WHERE id=1').get();
    assert.equal(expired?.estado,'vencida');
    assert.match(String(expired?.review_note),/hora de recogida/);
  } finally {db.close();}
});

test('la confirmación automática respeta el pago, la recogida y las fechas ocupadas', () => {
  const {db} = setup();
  try {
    db.exec(`UPDATE vehicles SET data='{"precio_dia":40,"reservable":true,"publicado":true,"estado_operativo":"disponible"}';
      UPDATE locations SET data='{"activo":true}';`);
    const stamp = (hours:number)=>new Date(Date.now()+hours*3600000).toISOString();
    function create(code:string,start:number,end:number) {
      return db.prepare(createReservationSql).get('confirmada','confirmada',code,1,1,stamp(start),stamp(end),4000,1,4000,1,1,code,'fp','{}',stamp(0),null,stamp(3),'Confirmada con IA',stamp(0),1,40,stamp(start),1,1,1,stamp(end),stamp(start));
    }
    const approved=create('AR-1',5,6);
    assert.equal(approved?.estado,'confirmada');
    assert.equal(approved?.review_note,'Confirmada con IA');
    assert.equal(create('AR-2',5,6),undefined);
    assert.equal(create('AR-3',-1,1),undefined);
    db.exec(`INSERT INTO settings(key,data) VALUES('payment','{"banco":"Prueba"}');`);
    const payment=create('AR-4',8,9);
    assert.equal(payment?.estado,'lista_para_aprobar');
    assert.match(String(payment?.review_note),/pago está pendiente/);
  } finally {db.close();}
});

test('la revisión con IA confirma datos coincidentes, deniega vigencia insuficiente y deriva lecturas dudosas', async (t) => {
  const modelReading = {resultado:'legible',titular:'MARÍA DÍAZ',vencimiento:'2028-02-15'};
  const mockedFetch = t.mock.method(globalThis,'fetch',async ()=>Response.json({status:'completed',output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(modelReading)}]}]}));
  const photo = {bytes:new Uint8Array([255,216,255]),type:'image/jpeg'};
  const review = await readLicenseWithAI('test-only',photo,photo);
  assert.equal(mockedFetch.mock.callCount(),1);
  const verified = assessLicenseWithAI(review,'María Díaz','2028-02-29','2028-02-01');
  assert.equal(reservationDecision('pendiente','2028-02-29',verified,'2028-02-15').status,'confirmada');
  assert.equal(reservationDecision('pendiente','2028-02-29',verified,'2028-02-16').status,'denegada_automatica');
  const differentHolder = assessLicenseWithAI(review,'Otra Persona','2028-02-29','2028-02-01');
  assert.equal(reservationDecision('pendiente','2028-02-29',differentHolder,'2028-02-16').status,'pendiente');
  const monthOnly = assessLicenseWithAI({ ...modelReading, resultado:'legible', vencimiento:'2028-02' },'María Díaz','2028-02-29','2028-02-01');
  assert.equal(reservationDecision('pendiente','2028-02-29',monthOnly,'2028-02-15').status,'pendiente');
  assert.equal(reservationDecision('pendiente','2028-02-29',assessLicenseWithAI(null,'María Díaz','2028-02-29','2028-02-01'),'2028-02-15').status,'pendiente');
  assert.equal(reservationDecision('pendiente','2028-02-29',{estado:'lista'},'2028-02-15').status,'pendiente');
});
