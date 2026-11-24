import { env } from 'cloudflare:workers';
import bcrypt from 'bcryptjs';
import { BookingError,DAY,DEPOSIT_WINDOW,activeSql,conflictSql,selectedDates,dayStart,svDay,validDay,iso,cents,amount,deposit,occupiedOn } from './booking-domain';
type J=Record<string,any>;
export type BookingContext={db:()=>D1Database;user:(req:Request,admin?:boolean)=>Promise<J>;vehicle:(id:number)=>Promise<J>;places:()=>Promise<J[]>;text:(value:unknown,max:number,label:string)=>string;consent:(b:J)=>string;sha:(value:string)=>Promise<string>;publicUser:(u:J)=>J;sign:(id:number,version?:number)=>Promise<string>};
const fail=(status:number,message:string,code='VALIDATION_ERROR'):never=>{throw new BookingError(status,message,code);};
export const privateAdmin=(u:J)=>u.rol==='administrador'&&u.private_admin===1;
const demo=(u:J)=>String(u.email).endsWith('@autorent.demo');
async function client(c:BookingContext,req:Request){const u=await c.user(req);if(u.rol!=='cliente')fail(403,'Usa una cuenta de cliente para reservar.');if(demo(u))fail(403,'Crea una cuenta personal para reservar y cargar documentos. Las cuentas Demo son compartidas.','PERSONAL_ACCOUNT_REQUIRED');return u;}
export async function bootstrapPrivateAdmin(c:BookingContext){
 if(!env.ADMIN_BOOTSTRAP_EMAIL||!env.ADMIN_BOOTSTRAP_PASSWORD_HASH)return;
 if(await c.db().prepare("SELECT key FROM settings WHERE key='private_admin_bootstrapped'").first())return;
 await c.db().batch([
  c.db().prepare("INSERT INTO users(email,password_hash,nombres,apellidos,rol,private_admin,token_version) SELECT ?,?,'Administración','AutoRent','administrador',1,0 WHERE NOT EXISTS(SELECT 1 FROM settings WHERE key='private_admin_bootstrapped') ON CONFLICT(email) DO UPDATE SET password_hash=excluded.password_hash,rol='administrador',private_admin=1,token_version=users.token_version+1").bind(env.ADMIN_BOOTSTRAP_EMAIL.toLowerCase(),env.ADMIN_BOOTSTRAP_PASSWORD_HASH),
  c.db().prepare("INSERT OR IGNORE INTO settings(key,data) VALUES('private_admin_bootstrapped',?)").bind(JSON.stringify({at:iso(Date.now())})),
 ]);
}
export async function expireHolds(c:BookingContext){
 await c.db().prepare("UPDATE reservations SET estado='vencida' WHERE estado='pendiente_deposito' AND deposit_due_at<=?").bind(iso(Date.now())).run();
}
async function paymentSettings(c:BookingContext){const row=await c.db().prepare("SELECT data FROM settings WHERE key='payment_settings'").first<{data:string}>();return row?JSON.parse(row.data):{habilitado:false,banco:'',titular:'',cuenta:'',tipo_cuenta:'',instrucciones:'',moneda:'USD'};}
async function owned(c:BookingContext,req:Request,id:number){
 const u=await c.user(req),r=await c.db().prepare('SELECT * FROM reservations WHERE id=?').bind(id).first<J>();
 if(!r)fail(404,'Reserva no encontrada.');if(!privateAdmin(u)&&u.id!==r!.user_id)fail(403,'Esta reserva pertenece a otra cuenta.');return {u,r:r!};
}
const documentView=(d:J)=>({id:d.id,tipo:d.document_type,pais:d.country,titular:d.holder,vencimiento:d.expires_on,estado:d.status,frente:`/driver-documents/${d.id}/image?side=front`,reverso:d.back_key?`/driver-documents/${d.id}/image?side=back`:null});
export async function serializeReservation(c:BookingContext,r:J){
 const v=await c.vehicle(r.vehicle_id),places=await c.places(),u=await c.db().prepare('SELECT nombres,apellidos FROM users WHERE id=?').bind(r.user_id).first<J>();
 const doc=r.document_id?await c.db().prepare('SELECT * FROM driver_documents WHERE id=?').bind(r.document_id).first<J>():null;
 return {id:r.id,codigo:r.codigo,estado:r.estado,vehiculo_id:r.vehicle_id,vehiculo_nombre:v.marca.nombre+' '+v.modelo.nombre,color:v.ficha.color,
  inicio_utc:r.inicio,fin_utc:r.fin,fechas:JSON.parse(r.selected_dates||'[]'),total:amount(r.total),precio_dia_aplicado:amount(r.price),unidades_cobradas:r.days,
  cliente_nombre:`${u?.nombres||''} ${u?.apellidos||''}`,entrega_nombre:places.find(l=>l.id===r.pickup)?.nombre,devolucion_nombre:places.find(l=>l.id===r.dropoff)?.nombre,
  km_salida:r.km_out,km_regreso:r.km_in,creado_en:r.created_at,deposito_requerido:amount(r.deposit_required||0),deposito_limite:r.deposit_due_at,
  datos_deposito:r.bank_snapshot?JSON.parse(r.bank_snapshot):null,comprobante_enviado_en:r.receipt_submitted_at,
  comprobante_url:r.receipt_key?`/reservations/${r.id}/receipt/image`:null,documento:doc?documentView(doc):null,
  deposito_recibido:r.deposit_received==null?null:amount(r.deposit_received),referencia_deposito:r.deposit_reference,nota_revision:r.review_note,revisado_en:r.reviewed_at,hora_servidor:iso(Date.now())};
}
async function quote(c:BookingContext,b:J){
 const dates=selectedDates(b.fechas),v=await c.vehicle(Number(b.vehiculo_id));
 if(!v.reservable||v.precio_dia==null||v.publicado===false||v.estado_operativo!=='disponible')fail(409,'Esta unidad no está habilitada para reservar.');
 const places=await c.places();for(const id of [b.entrega_id,b.devolucion_id])if(!places.some(l=>l.id===Number(id)&&l.activo))fail(400,'Selecciona dos puntos activos.');
 const encoded=JSON.stringify(dates),conflict=await c.db().prepare(`SELECT r.id FROM reservations r WHERE r.vehicle_id=? AND ${activeSql()} AND ${conflictSql()} LIMIT 1`).bind(v.id,iso(Date.now()),encoded,encoded).first();
 if(conflict)fail(409,'Uno o varios días ya están apartados. Actualiza el calendario.','UNAVAILABLE');
 const price=cents(v.precio_dia);if(price<=0)fail(409,'Tarifa pendiente de confirmar.');
 return {dates,encoded,v,price,total:price*dates.length,start:iso(dayStart(dates[0])),end:iso(dayStart(dates.at(-1)!)+DAY)};
}
async function imageFile(value:FormDataEntryValue|null){
 if(!(value instanceof File)||value.size<16||value.size>3*1024*1024)fail(400,'Adjunta una foto JPG, PNG o WebP de hasta 3 MB.');
 const bytes=new Uint8Array(await (value as File).arrayBuffer());let type='';
 if(bytes[0]===255&&bytes[1]===216&&bytes[2]===255)type='image/jpeg';
 else if([137,80,78,71,13,10,26,10].every((v,i)=>bytes[i]===v))type='image/png';
 else if(new TextDecoder().decode(bytes.slice(0,4))==='RIFF'&&new TextDecoder().decode(bytes.slice(8,12))==='WEBP')type='image/webp';
 if(!type)fail(400,'El archivo no es una foto JPG, PNG o WebP válida.');return {bytes,type};
}
function bucket(){if(!env.BUCKET)fail(503,'No se pudo acceder al almacenamiento privado.');return env.BUCKET!;}
async function privateImage(key:string,type:string){
 const file=await bucket().get(key);if(!file)fail(404,'Imagen no encontrada.');
 return new Response(file!.body,{headers:{'Content-Type':type,'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff','Content-Disposition':'inline'}});
}
const handled=(value:J|Response)=>({handled:true as const,value});
export async function bookingRoutes(c:BookingContext,req:Request,path:string,method:string,b:J):Promise<{handled:boolean;value?:J|Response}>{
 if(path==='/auth/account'&&method==='PATCH'){
  const u=await c.user(req);if(demo(u))fail(403,'La cuenta Demo no se puede modificar.');
  if(typeof b.password_actual!=='string'||!await bcrypt.compare(b.password_actual,u.password_hash))fail(403,'La contraseña actual no es correcta.');
  const email=c.text(b.email??u.email,254,'el correo').toLowerCase();if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||email.endsWith('@autorent.demo'))fail(400,'Introduce un correo personal válido.');
  const collision=await c.db().prepare('SELECT id FROM users WHERE email=? AND id<>?').bind(email,u.id).first();if(collision)fail(409,'Ese correo ya pertenece a otra cuenta.');
  let hash=u.password_hash;if(b.password_nueva){const pass=b.password_nueva;if(typeof pass!=='string'||Array.from(pass).length<8||new TextEncoder().encode(pass).length>72)fail(400,'La nueva contraseña debe tener al menos 8 caracteres y un máximo de 72 bytes.');hash=await bcrypt.hash(pass,12);}
  const updated=await c.db().prepare('UPDATE users SET email=?,password_hash=?,token_version=token_version+1 WHERE id=? RETURNING *').bind(email,hash,u.id).first<J>();
  return handled({user:c.publicUser(updated!),accessToken:await c.sign(u.id,updated!.token_version),tokenType:'Bearer',expiresIn:3600});
 }
 if(path==='/admin/payment-settings'){
  await c.user(req,true);
  if(method==='GET')return handled({settings:await paymentSettings(c),deposit_percent:50,deadline_hours:3});
  if(['PUT','PATCH'].includes(method)){
   const enabled=b.habilitado===true,field=(key:string,max:number)=>enabled?c.text(b[key],max,key):String(b[key]??'').trim().slice(0,max);
   const settings={habilitado:enabled,banco:field('banco',120),titular:field('titular',180),cuenta:field('cuenta',100),tipo_cuenta:String(b.tipo_cuenta||'').slice(0,80),instrucciones:String(b.instrucciones||'').slice(0,1200),moneda:'USD'};
   await c.db().prepare("INSERT INTO settings(key,data) VALUES('payment_settings',?) ON CONFLICT(key) DO UPDATE SET data=excluded.data").bind(JSON.stringify(settings)).run();return handled({settings,deposit_percent:50,deadline_hours:3});
  }
 }
 if(path==='/driver-documents'&&method==='POST'){
  const u=await client(c,req);if(!await c.db().prepare('SELECT id FROM users WHERE private_admin=1 LIMIT 1').first())fail(503,'La administración privada todavía no está disponible.');
  if(Number(req.headers.get('Content-Length')||0)>7*1024*1024)fail(413,'Las imágenes son demasiado grandes.');
  const form=await req.formData();if(form.get('consentimiento')!=='true')fail(400,'Autoriza el uso del documento para verificar tu reserva.');
  const type=String(form.get('tipo'));if(!['licencia_sv','licencia_extranjera','permiso_internacional'].includes(type))fail(400,'Selecciona el tipo de licencia o permiso.');
  const country=c.text(form.get('pais'),80,'el país emisor'),holder=c.text(form.get('titular'),180,'el nombre del titular'),expires=String(form.get('vencimiento'));
  if(!validDay(expires)||expires<svDay())fail(400,'El documento debe estar vigente.');
  const count=await c.db().prepare('SELECT COUNT(*) AS total FROM driver_documents WHERE user_id=? AND created_at>?').bind(u.id,iso(Date.now()-DAY)).first<{total:number}>();if((count?.total||0)>=10)fail(429,'Ya cargaste suficientes documentos hoy. Reutiliza uno vigente.');
  const front=await imageFile(form.get('frente')),back=form.get('reverso') instanceof File?(await imageFile(form.get('reverso'))):null,id=crypto.randomUUID(),frontKey=`private/drivers/${u.id}/${id}/front`,backKey=back?`private/drivers/${u.id}/${id}/back`:null;
  await bucket().put(frontKey,front.bytes,{httpMetadata:{contentType:front.type}});if(back&&backKey)await bucket().put(backKey,back.bytes,{httpMetadata:{contentType:back.type}});
  const d=await c.db().prepare("INSERT INTO driver_documents(id,user_id,document_type,country,holder,expires_on,front_key,front_type,back_key,back_type,status,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,'pendiente',?) RETURNING *").bind(id,u.id,type,country,holder,expires,frontKey,front.type,backKey,back?.type??null,iso(Date.now())).first<J>();
  return handled({document:documentView(d!)});
 }
 if(path==='/driver-documents'&&method==='GET'){const u=await client(c,req),rows=await c.db().prepare('SELECT * FROM driver_documents WHERE user_id=? AND expires_on>=? ORDER BY created_at DESC LIMIT 20').bind(u.id,svDay()).all<J>();return handled({documents:rows.results.map(documentView)});}
 if(/^\/driver-documents\/[a-f0-9-]+\/image$/.test(path)&&method==='GET'){
  const u=await c.user(req),d=await c.db().prepare('SELECT * FROM driver_documents WHERE id=?').bind(path.split('/')[2]).first<J>();if(!d)fail(404,'Documento no encontrado.');if(!privateAdmin(u)&&d!.user_id!==u.id)fail(403,'Este documento es privado.');
  const back=new URL(req.url).searchParams.get('side')==='back',key=back?d!.back_key:d!.front_key;if(!key)fail(404,'No se cargó el reverso.');return handled(await privateImage(key,back?d!.back_type:d!.front_type));
 }
 if(/^\/vehicles\/\d+\/availability$/.test(path)&&method==='GET'){
  const id=Number(path.split('/')[2]);await c.vehicle(id);const month=new URL(req.url).searchParams.get('month')||svDay().slice(0,7);if(!/^\d{4}-\d{2}$/.test(month)||!validDay(month+'-01'))fail(400,'Mes no válido.');
  const first=dayStart(month+'-01'),count=new Date(Date.UTC(Number(month.slice(0,4)),Number(month.slice(5,7)),0)).getUTCDate(),days=Array.from({length:count},(_,i)=>iso(first+i*DAY).slice(0,10));
  const rows=await c.db().prepare(`SELECT r.* FROM reservations r WHERE r.vehicle_id=? AND ${activeSql()} AND r.inicio<? AND r.fin>?`).bind(id,iso(Date.now()),iso(first+count*DAY),iso(first)).all<J>();
  return handled({mes:month,fechas_ocupadas:days.filter(day=>rows.results.some(r=>occupiedOn(r,day))),hora_servidor:iso(Date.now()),minimo:svDay(Date.now()+DAY),maximo:svDay(Date.now()+365*DAY)});
 }
 if(path==='/reservations/quote'&&method==='POST'){
  await client(c,req);const q=await quote(c,b),settings=await paymentSettings(c);
  return handled({fechas:q.dates,dias_cobrados:q.dates.length,precio_dia:amount(q.price),total:amount(q.total),deposito_requerido:amount(deposit(q.total)),deposito_porcentaje:50,plazo_horas:3,depositos_habilitados:settings.habilitado===true});
 }
 if(path==='/reservations'&&method==='POST'){
  const u=await client(c,req),dates=selectedDates(b.fechas),accept=c.consent(b.aceptacion),operation=req.headers.get('Idempotency-Key');if(!operation||operation.length>160)fail(400,'Falta la clave de reintento.');
  const fp=await c.sha(JSON.stringify([u.id,Number(b.vehiculo_id),dates,Number(b.entrega_id),Number(b.devolucion_id),b.precio_confirmado,b.documento_id]));
  const old=await c.db().prepare('SELECT * FROM reservations WHERE operation_key=?').bind(operation).first<J>();if(old){if(old.user_id!==u.id||old.fingerprint!==fp)fail(409,'La clave corresponde a otra operación.');return handled({reservation:await serializeReservation(c,old)});}
  const settings=await paymentSettings(c);if(!settings.habilitado)fail(409,'El administrador debe configurar y habilitar los datos de depósito antes de aceptar reservas.','PAYMENTS_NOT_CONFIGURED');
  const doc=await c.db().prepare('SELECT * FROM driver_documents WHERE id=? AND user_id=?').bind(String(b.documento_id||''),u.id).first<J>();
  if(!doc)fail(400,'Adjunta tu licencia o documento extranjero equivalente antes de reservar.','LICENSE_REQUIRED');if(doc!.status==='rechazado'||doc!.expires_on<dates.at(-1)!)fail(400,'El documento debe estar vigente durante todos los días seleccionados.','LICENSE_EXPIRED');
  const q=await quote(c,b);if(String(b.precio_confirmado)!==amount(q.price))fail(409,'La tarifa cambió. Consulta el total nuevamente.');
  const now=iso(Date.now()),due=iso(Date.now()+DEPOSIT_WINDOW),code='AR-'+crypto.randomUUID().slice(0,8).toUpperCase();
  try{
   const r=await c.db().prepare(`INSERT INTO reservations(codigo,user_id,vehicle_id,inicio,fin,estado,price,days,total,pickup,dropoff,operation_key,fingerprint,acceptance,created_at,selected_dates,document_id,deposit_required,deposit_due_at,bank_snapshot) SELECT ?,?,?,?,?,'pendiente_deposito',?,?,?,?,?,?,?,?,?,?,?,?,?,? FROM vehicles current WHERE current.id=? AND json_extract(current.data,'$.precio_dia')=? AND json_extract(current.data,'$.reservable')=1 AND json_extract(current.data,'$.publicado')=1 AND json_extract(current.data,'$.estado_operativo')='disponible' AND NOT EXISTS(SELECT 1 FROM reservations r WHERE r.vehicle_id=current.id AND ${activeSql()} AND ${conflictSql()}) RETURNING *`)
    .bind(code,u.id,q.v.id,q.start,q.end,q.price,q.dates.length,q.total,Number(b.entrega_id),Number(b.devolucion_id),operation,fp,accept,now,q.encoded,doc!.id,deposit(q.total),due,JSON.stringify(settings),q.v.id,amount(q.price),now,q.encoded,q.encoded).first<J>();
   if(!r)fail(409,'Uno de los días acaba de ser apartado o cambió la tarifa. Actualiza el calendario.','UNAVAILABLE');return handled({reservation:await serializeReservation(c,r!)});
  }catch(error){if(error instanceof BookingError)throw error;const repeat=await c.db().prepare('SELECT * FROM reservations WHERE operation_key=?').bind(operation).first<J>();if(repeat&&repeat.user_id===u.id&&repeat.fingerprint===fp)return handled({reservation:await serializeReservation(c,repeat)});throw error;}
 }
 if(path==='/reservations'&&method==='GET'){
  const u=await c.user(req),isAdmin=privateAdmin(u),params=new URL(req.url).searchParams,page=Math.max(1,Number(params.get('page'))||1),limit=Math.min(100,Math.max(1,Number(params.get('limit'))||20));
  const rows=await c.db().prepare(isAdmin?'SELECT * FROM reservations ORDER BY id DESC':'SELECT * FROM reservations WHERE user_id=? ORDER BY id DESC').bind(...(isAdmin?[]:[u.id])).all<J>();const list=rows.results.filter(r=>!params.get('estado')||r.estado===params.get('estado'));
  return handled({reservations:await Promise.all(list.slice((page-1)*limit,page*limit).map(r=>serializeReservation(c,r))),pagination:{page,limit,total:list.length,totalPages:Math.max(1,Math.ceil(list.length/limit))}});
 }
 if(/^\/reservations\/\d+\/receipt\/image$/.test(path)&&method==='GET'){const {r}=await owned(c,req,Number(path.split('/')[2]));if(!r.receipt_key)fail(404,'No hay comprobante.');return handled(await privateImage(r.receipt_key,r.receipt_type));}
 if(/^\/reservations\/\d+\/receipt$/.test(path)&&method==='POST'){
  const {u,r}=await owned(c,req,Number(path.split('/')[2]));if(u.id!==r.user_id||demo(u))fail(403,'El comprobante debe enviarlo el titular de la reserva.');
  if(!['pendiente_deposito','en_revision'].includes(r.estado)||r.deposit_due_at<=iso(Date.now()))fail(409,'El plazo de 3 horas terminó. No envíes un depósito para esta reserva.','DEPOSIT_EXPIRED');
  if(Number(req.headers.get('Content-Length')||0)>4*1024*1024)fail(413,'La foto es demasiado grande.');
  const form=await req.formData(),file=await imageFile(form.get('comprobante')),key=`private/receipts/${u.id}/${r.id}/${crypto.randomUUID()}`;await bucket().put(key,file.bytes,{httpMetadata:{contentType:file.type}});
  const now=iso(Date.now()),updated=await c.db().prepare("UPDATE reservations SET receipt_key=?,receipt_type=?,receipt_submitted_at=?,estado='en_revision' WHERE id=? AND user_id=? AND estado IN ('pendiente_deposito','en_revision') AND deposit_due_at>? RETURNING *").bind(key,file.type,now,r.id,u.id,now).first<J>();
  if(!updated){await bucket().delete(key);fail(409,'El plazo terminó mientras se enviaba el archivo. Las fechas ya no están apartadas.','DEPOSIT_EXPIRED');}
  return handled({reservation:await serializeReservation(c,updated!)});
 }
 if(/^\/reservations\/\d+(\/cancel)?$/.test(path)){
  const {u,r}=await owned(c,req,Number(path.split('/')[2]));
  if(path.endsWith('/cancel')&&method==='POST'){
   if(!['confirmada','pendiente_deposito','en_revision'].includes(r.estado)||!privateAdmin(u)&&r.inicio<=iso(Date.now()))fail(409,'Esta reserva ya no se puede cancelar.');
   const changed=await c.db().prepare("UPDATE reservations SET estado='cancelada' WHERE id=? AND estado=? RETURNING *").bind(r.id,r.estado).first<J>();if(!changed)fail(409,'La reserva cambió. Actualiza la pantalla.');return handled({reservation:await serializeReservation(c,changed!)});
  }
  if(method==='GET')return handled({reservation:await serializeReservation(c,r)});
 }
 if(/^\/admin\/reservations\/\d+\/review$/.test(path)&&method==='POST'){
  const admin=await c.user(req,true),{r}=await owned(c,req,Number(path.split('/')[3]));
  if(!['pendiente_deposito','en_revision'].includes(r.estado))fail(409,'La reserva ya fue revisada o venció.');
  const approve=b.accion==='aprobar';if(!approve&&b.accion!=='rechazar')fail(400,'Selecciona aprobar o rechazar.');
  let received:number|null=null,reference:string|null=null;
  const note=approve?String(b.nota||'').slice(0,600):c.text(b.nota,600,'el motivo de rechazo');
  if(approve){
   if(r.estado!=='en_revision'||!r.receipt_key||!r.receipt_submitted_at||r.receipt_submitted_at>r.deposit_due_at)fail(409,'No se recibió un comprobante dentro de las 3 horas.');
   if(b.licencia_valida!==true||b.deposito_confirmado!==true)fail(400,'Confirma que verificaste la licencia y que el depósito está recibido en la cuenta.');
   received=cents(b.monto_recibido);if(received<r.deposit_required)fail(400,'El importe recibido no alcanza el anticipo del 50%.');reference=c.text(b.referencia,160,'la referencia del depósito');
   const doc=await c.db().prepare('SELECT * FROM driver_documents WHERE id=?').bind(r.document_id).first<J>();if(!doc||doc.expires_on<JSON.parse(r.selected_dates).at(-1))fail(409,'La licencia no cubre todas las fechas de la reserva.');
  }
  const changed=await c.db().prepare('UPDATE reservations SET estado=?,deposit_received=?,deposit_reference=?,review_note=?,reviewed_by=?,reviewed_at=? WHERE id=? AND estado=? RETURNING *').bind(approve?'confirmada':'rechazada',received,reference,note,admin.id,iso(Date.now()),r.id,r.estado).first<J>();if(!changed)fail(409,'La reserva cambió durante la revisión.');
  if(approve||b.rechazar_licencia===true)await c.db().prepare('UPDATE driver_documents SET status=? WHERE id=?').bind(approve?'verificada':'rechazado',r.document_id).run();
  return handled({reservation:await serializeReservation(c,changed!)});
 }
 if(/^\/admin\/reservations\/\d+\/(checkout|return)$/.test(path)&&method==='POST'){
  await c.user(req,true);const {r}=await owned(c,req,Number(path.split('/')[3])),returning=path.endsWith('/return'),km=Number(b.kilometraje),dates=JSON.parse(r.selected_dates||'[]') as string[];
  if(!Number.isSafeInteger(km)||km<0||returning&&km<(r.km_out||0))fail(400,'Kilometraje no válido.');
  if(r.estado!==(returning?'en_curso':'confirmada'))fail(409,'Primero confirma la licencia y el anticipo.');
  if(!returning&&dates.length&&!dates.includes(svDay()))fail(409,'Hoy no es uno de los días seleccionados.');
  const next=returning?(dates.some(d=>d>svDay())?'confirmada':'completada'):'en_curso';
  const updated=await c.db().prepare(`UPDATE reservations SET estado=?,${returning?'km_in':'km_out'}=? WHERE id=? AND estado=? RETURNING id`).bind(next,km,r.id,r.estado).first();if(!updated)fail(409,'El estado cambió.');return handled({ok:true,estado:next});
 }
 return {handled:false};
}
