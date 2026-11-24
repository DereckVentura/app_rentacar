import { env } from 'cloudflare:workers';
import bcrypt from 'bcryptjs';
import { driverDocumentRoute, DocumentError, documentView } from '../../../../lib/driver-document-service';
import { reservationDecision } from '../../../../lib/license-ai';
import { activeReservationSql, awaitingReviewSql, createReservationSql, deadlineSql, expirationMessage, reservationMinutes, validateReservationSql, validationDeadline } from '../../../../lib/pending-reservations';
import { expireReservations } from '../../../../lib/reservation-lifecycle';
import { editVehicle, FleetError, saveCatalogRow } from '../../../../lib/fleet-admin';
import { reservedMessage } from '../../../../lib/availability';
import { fleet, locations, documents, business } from '../../../../lib/fleet';

export const dynamic = 'force-dynamic';
type J = Record<string, any>;
class Fault extends Error { constructor(public status:number, message:string, public code='VALIDATION_ERROR'){super(message);} }
const version='autorent-2026-11-10-v2';
const enc=new TextEncoder();
function db(){if(!env.DB)throw new Fault(503,'La base de datos no está disponible.');return env.DB;}
const money=(c:number)=>(c/100).toFixed(2);
const publicUser=(u:J)=>({id:u.id,email:u.email,nombres:u.nombres,apellidos:u.apellidos,telefono:u.telefono,rol:u.rol});
async function sha(value:string){return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(value)))).map(b=>b.toString(16).padStart(2,'0')).join('');}
function b64(value:string|Uint8Array){return btoa(typeof value==='string'?value:String.fromCharCode(...value)).replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');}
async function key(){if(!env.AUTH_SECRET)throw new Fault(503,'Falta configurar la firma de sesiones.');return crypto.subtle.importKey('raw',enc.encode(env.AUTH_SECRET),{name:'HMAC',hash:'SHA-256'},false,['sign','verify']);}
async function sign(id:number,seconds:number){const record=await db().prepare('SELECT token_version FROM users WHERE id=?').bind(id).first<{token_version:number}>();const p=b64(JSON.stringify({alg:'HS256',typ:'JWT'}))+'.'+b64(JSON.stringify({sub:String(id),ver:record?.token_version||0,exp:Math.floor(Date.now()/1000)+seconds,iss:'autorent-sites'}));return p+'.'+b64(new Uint8Array(await crypto.subtle.sign('HMAC',await key(),enc.encode(p))));}
const sessionCookie = (token: string, maxAge?: number) => `autorent_session=${token}; Path=/api/v1; HttpOnly; Secure; SameSite=Strict${maxAge !== undefined ? `; Max-Age=${maxAge}` : ''}`;
async function user(req:Request,admin=false){
 try{
  const bearer=req.headers.get('Authorization')?.match(/^Bearer (.+)$/)?.[1];
  const cookie=req.headers.get('Cookie')?.match(/(?:^|;\s*)autorent_session=([^;]+)/)?.[1];
  if(!bearer&&cookie&&!['GET','HEAD'].includes(req.method)&&req.headers.get('Origin')!==new URL(req.url).origin)throw 0;
  const [h,p,s]=(bearer||cookie||'').split('.');
  if(!h||!p||!s)throw 0;const head=JSON.parse(atob(h.replace(/-/g,'+').replace(/_/g,'/')));if(head.alg!=='HS256')throw 0;
  const bytes=Uint8Array.from(atob(s.replace(/-/g,'+').replace(/_/g,'/')),c=>c.charCodeAt(0));
  if(!await crypto.subtle.verify('HMAC',await key(),bytes,enc.encode(h+'.'+p)))throw 0;
  const claims=JSON.parse(atob(p.replace(/-/g,'+').replace(/_/g,'/')));if(claims.exp<Date.now()/1000||claims.iss!=='autorent-sites')throw 0;
  const u=await db().prepare('SELECT * FROM users WHERE id=?').bind(Number(claims.sub)).first<J>();if(!u||u.email.endsWith('@autorent.demo')||(claims.ver??0)!==(u.token_version||0))throw 0;
  if(admin&&u.rol!=='administrador')throw new Fault(403,'Esta acción requiere administración.','FORBIDDEN');return u;
 }catch(e){if(e instanceof Fault)throw e;throw new Fault(401,'Inicia sesión nuevamente.','INVALID_TOKEN');}
}
async function bootstrap(){
 const seeds=[...fleet.map(v=>db().prepare('INSERT OR IGNORE INTO vehicles(id,data) VALUES(?,?)').bind(v.id,JSON.stringify(v))),...locations.map(l=>db().prepare('INSERT OR IGNORE INTO locations(id,data) VALUES(?,?)').bind(l.id,JSON.stringify(l))),db().prepare('INSERT OR IGNORE INTO settings(key,data) VALUES(?,?)').bind('business',JSON.stringify(business))];
 await db().batch(seeds);
 if(env.ADMIN_BOOTSTRAP_EMAIL&&env.ADMIN_BOOTSTRAP_PASSWORD_HASH){
  const marker='admin-owner-2026-11-10';
  if(!await db().prepare('SELECT key FROM settings WHERE key=?').bind(marker).first())await db().batch([
   db().prepare("INSERT INTO users(email,password_hash,nombres,apellidos,rol,private_admin,token_version) SELECT ?,?,'Administración','AutoRent','administrador',1,1 WHERE NOT EXISTS(SELECT 1 FROM settings WHERE key=?) ON CONFLICT(email) DO UPDATE SET password_hash=excluded.password_hash,rol='administrador',private_admin=1,token_version=users.token_version+1").bind(env.ADMIN_BOOTSTRAP_EMAIL.toLowerCase(),env.ADMIN_BOOTSTRAP_PASSWORD_HASH,marker),
   db().prepare('INSERT OR IGNORE INTO settings(key,data) VALUES(?,?)').bind(marker,new Date().toISOString()),
  ]);
 }

 // Apply the owner's confirmed fleet once; preserve later administration edits.
 const marker='fleet-owner-2026-11-10';
 if(!await db().prepare('SELECT key FROM settings WHERE key=?').bind(marker).first()){
  await db().batch([
   ...fleet.map(v=>db().prepare("UPDATE vehicles SET data=json_set(data,'$.precio_dia',?,'$.placa',?,'$.descripcion',?,'$.reservable',json(CASE WHEN json_extract(data,'$.publicado')=1 AND json_extract(data,'$.estado_operativo')='disponible' THEN 'true' ELSE 'false' END)) WHERE id=? AND NOT EXISTS(SELECT 1 FROM settings WHERE key=?)").bind(v.precio_dia,v.placa,v.descripcion,v.id,marker)),
   ...locations.map(l=>db().prepare("UPDATE locations SET data=json_set(data,'$.direccion',?) WHERE id=? AND data LIKE '%demostraci%' AND NOT EXISTS(SELECT 1 FROM settings WHERE key=?)").bind(l.direccion,l.id,marker)),
   db().prepare("UPDATE settings SET data=? WHERE key='business' AND NOT EXISTS(SELECT 1 FROM settings WHERE key=?) AND (data LIKE '%académi%' OR data LIKE '%P-DEMO%')").bind(JSON.stringify(business),marker),
   db().prepare('INSERT OR IGNORE INTO settings(key,data) VALUES(?,?)').bind(marker,new Date().toISOString()),
  ]);
 }

}
async function cars(){const r=await db().prepare('SELECT data FROM vehicles ORDER BY id').all<{data:string}>();const ls=await places();return r.results.map(r=>{const v=JSON.parse(r.data),ubicacion=ls.find(l=>l.id===v.ubicacion_actual_id)||null;return {...v,categoria_id:v.categoria.id,ubicacion,reservable:!!(v.reservable&&ubicacion?.activo&&!ubicacion.eliminado)};});}
async function catalogs() {
 const vehicles=(await cars()).filter(v=>!v.eliminado);
 const distinct=(values:J[])=>Array.from(new Map(values.map(value=>[value.id,value])).values());
 return {categorias:distinct([{id:1,nombre:'SUV'},...vehicles.map(v=>v.categoria)]),marcas:distinct(vehicles.map(v=>v.marca)),modelos:distinct(vehicles.map(v=>({...v.modelo,marca_id:v.marca.id})))};
}
async function places(){const r=await db().prepare('SELECT data FROM locations ORDER BY id').all<{data:string}>();return r.results.map(r=>JSON.parse(r.data));}
async function vehicle(id:number){const r=await db().prepare('SELECT data FROM vehicles WHERE id=?').bind(id).first<{data:string}>();if(!r)throw new Fault(404,'Vehículo no encontrado.');const v=JSON.parse(r.data);return {...v,ubicacion:(await places()).find(l=>l.id===v.ubicacion_actual_id)||null};}
function consent(b:J){if(b?.version!==version||b.privacidad!==true||b.terminos!==true)throw new Fault(400,'Lee y acepta los dos documentos vigentes.','CONSENT_REQUIRED');return JSON.stringify({...b,at:new Date().toISOString()});}
function text(v:unknown,max:number,label:string){if(typeof v!=='string'||!v.trim()||v.trim().length>max||/[\x00-\x1f]/.test(v))throw new Fault(400,`Revisa ${label}.`);return v.trim();}
function password(v:unknown){if(typeof v!=='string'||Array.from(v).length<8||enc.encode(v).length>72||/\p{Cs}/u.test(v))throw new Fault(400,'La contraseña debe tener al menos 8 caracteres y no superar 72 bytes.');return v;}
function pagination(rows:J[],url:URL){const page=Math.max(1,Number(url.searchParams.get('page'))||1),limit=Math.min(100,Math.max(1,Number(url.searchParams.get('limit'))||20));return {rows:rows.slice((page-1)*limit,page*limit),pagination:{total:rows.length,totalPages:Math.max(1,Math.ceil(rows.length/limit)),page,limit}};}
async function limited(req:Request,email:string){const bucket=Math.floor(Date.now()/900000),k=await sha((req.headers.get('cf-connecting-ip')||'local')+':'+bucket);const res=await db().prepare('INSERT INTO login_attempts(key,count,expires) VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET count=count+1 RETURNING count').bind(k,Date.now()+900000).first<{count:number}>();if((res?.count||0)>40)throw new Fault(429,'Demasiados intentos. Espera 15 minutos.');}
async function quote(b:J){
 const v=await vehicle(Number(b.vehiculo_id));if(v.eliminado||!v.reservable||v.precio_dia==null||v.publicado===false||v.estado_operativo!=='disponible')throw new Fault(409,'Esta unidad no está habilitada para reservar.');
 const start=new Date(b.inicio),end=new Date(b.fin);if(!Number.isFinite(start.getTime())||!Number.isFinite(end.getTime())||start.getTime()<=Date.now()||end<=start||end.getTime()-start.getTime()>90*86400000)throw new Fault(400,'Selecciona fechas futuras, ordenadas y un máximo de 90 días.');
 const locs=await places();for(const id of [b.entrega_id,b.devolucion_id])if(!locs.some(l=>l.id===Number(id)&&l.activo&&!l.eliminado))throw new Fault(400,'Selecciona dos puntos activos.');
 const conflict=await db().prepare(`SELECT id FROM reservations WHERE vehicle_id=? AND ${activeReservationSql} AND inicio<? AND fin>? LIMIT 1`).bind(v.id,end.toISOString(),start.toISOString()).first();if(conflict)throw new Fault(409,reservedMessage,'UNAVAILABLE');
 const days=Math.ceil((end.getTime()-start.getTime())/86400000),price=Math.round(Number(v.precio_dia)*100);if(!Number.isSafeInteger(price)||price<=0)throw new Fault(409,'Tarifa pendiente de confirmar.');
 return {v,start:start.toISOString(),end:end.toISOString(),days,price,total:days*price};
}
async function reservation(r:J){const doc=r.document_id?await db().prepare('SELECT * FROM driver_documents WHERE id=?').bind(r.document_id).first<J>():null;const v=await vehicle(r.vehicle_id),ls=await places(),u=await db().prepare('SELECT nombres,apellidos FROM users WHERE id=?').bind(r.user_id).first<J>();const due=r.validation_due_at||r.deposit_due_at||validationDeadline(r.created_at);return {...r,review_note:r.review_note||(r.estado==='vencida'?expirationMessage:null),vence_en:['pendiente','lista_para_aprobar'].includes(r.estado)?(Date.parse(r.inicio)<Date.parse(due)?r.inicio:due):null,servidor_utc:new Date().toISOString(),documento:doc?documentView(doc):null,vehiculo_id:r.vehicle_id,vehiculo_nombre:v.marca.nombre+' '+v.modelo.nombre,color:v.ficha.color,inicio_utc:r.inicio,fin_utc:r.fin,total:money(r.total),precio_dia_aplicado:money(r.price),unidades_cobradas:r.days,cliente_nombre:`${u?.nombres||''} ${u?.apellidos||''}`.trim(),entrega_nombre:ls.find(l=>l.id===r.pickup)?.nombre,devolucion_nombre:ls.find(l=>l.id===r.dropoff)?.nombre,km_salida:r.km_out,km_regreso:r.km_in};}
async function owned(req:Request,id:number){const u=await user(req),r=await db().prepare('SELECT * FROM reservations WHERE id=?').bind(id).first<J>();if(!r)throw new Fault(404,'Reserva no encontrada.');if(u.rol!=='administrador'&&u.id!==r.user_id)throw new Fault(403,'Esta reserva pertenece a otra cuenta.');return {u,r};}
async function execute(req:Request){
 const url=new URL(req.url),path=url.pathname.replace(/^\/api\/v1/,'').replace(/\/$/,'')||'/',method=req.method;
 if(method==='OPTIONS')return {};
 await bootstrap();
 await expireReservations(db());
 if(path==='/driver-documents'&&method==='POST'||/^\/driver-documents\/[a-f0-9-]+\/image$/.test(path))return driverDocumentRoute(req,path,db(),await user(req));
 if(/^\/fleet-images\/[a-f0-9-]+$/.test(path)&&['GET','HEAD'].includes(method)){
  const object=await env.BUCKET?.get('fleet/'+path.split('/')[2]);
  if(!object)throw new Fault(404,'Foto no encontrada.');
  return new Response(method==='HEAD'?null:object.body,{headers:{'Content-Type':'image/jpeg','Cache-Control':'public,max-age=86400','X-Content-Type-Options':'nosniff','Access-Control-Allow-Origin':'*'}});
 }
 if(/^\/fleet-photos\/[a-f0-9-]{36}$/.test(path)&&['GET','HEAD'].includes(method)){
  const object=await env.BUCKET?.get(`public/fleet/${path.split('/').pop()}`);
  if(!object)throw new Fault(404,'Foto no encontrada.');
  return new Response(method==='HEAD'?null:object.body,{headers:{'Content-Type':object.httpMetadata?.contentType||'image/jpeg','Cache-Control':'public, max-age=31536000, immutable','X-Content-Type-Options':'nosniff'}});
 }
 if(path==='/admin/fleet-photos'&&method==='POST'){
  await user(req,true);
  if(!env.BUCKET)throw new Fault(503,'Almacenamiento no disponible.');
  if(!req.body||Number(req.headers.get('Content-Length')||0)>2_000_000)throw new Fault(413,'La foto debe pesar menos de 2 MB.');
  const reader=req.body.getReader(), chunks:Uint8Array[]=[];
  let size=0;
  for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>2_000_000){await reader.cancel();throw new Fault(413,'La foto debe pesar menos de 2 MB.');}chunks.push(value);}
  const photo=new Uint8Array(size);let offset=0;
  for(const chunk of chunks){photo.set(chunk,offset);offset+=chunk.length;}
  const jpg=photo[0]===255&&photo[1]===216&&photo[2]===255&&photo.at(-2)===255&&photo.at(-1)===217;
  const png=[137,80,78,71,13,10,26,10].every((byte,index)=>photo[index]===byte);
  const webp=new TextDecoder().decode(photo.subarray(0,4))==='RIFF'&&new TextDecoder().decode(photo.subarray(8,12))==='WEBP';
  if(!jpg&&!png&&!webp)throw new Fault(400,'Carga una foto JPG, PNG o WebP válida.');
  const id=crypto.randomUUID();await env.BUCKET.put(`public/fleet/${id}`,photo,{httpMetadata:{contentType:jpg?'image/jpeg':png?'image/png':'image/webp'}});
  return {url:`/api/v1/fleet-photos/${id}`};
 }
 if(Number(req.headers.get('content-length')||0)>20000)throw new Fault(413,'Solicitud demasiado grande.');
 let b:J={};if(!['GET','HEAD'].includes(method)){const raw=await req.text();if(raw.length>20000)throw new Fault(413,'Solicitud demasiado grande.');try{b=raw?JSON.parse(raw):{};}catch{throw new Fault(400,'Solicitud JSON no válida.');}if(!b||Array.isArray(b)||typeof b!=='object')throw new Fault(400,'Se requiere un objeto.');}
 if(path==='/health')return {status:'ok',storage:'D1',service:'AutoRent Sites'};
 if(path==='/content'&&method==='GET')return {version,documents,business:JSON.parse((await db().prepare('SELECT data FROM settings WHERE key=?').bind('business').first<{data:string}>())!.data)};
 if(path==='/auth/register'&&method==='POST'){
  const acceptance=consent(b.aceptacion),email=text(b.email,254,'el correo').toLowerCase();if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))throw new Fault(400,'Introduce un correo válido.');await limited(req,email);
  const hash=await bcrypt.hash(password(b.password),12),names=text(b.nombres,100,'los nombres'),surname=text(b.apellidos,100,'los apellidos');
  if(await db().prepare('SELECT id FROM users WHERE email=?').bind(email).first())throw new Fault(409,'Este correo ya tiene una cuenta.');
  const r=await db().prepare('INSERT INTO users(email,password_hash,nombres,apellidos,telefono,acceptance) VALUES(?,?,?,?,?,?) RETURNING *').bind(email,hash,names,surname,b.telefono?text(b.telefono,25,'el teléfono'):null,acceptance).first<J>();return {user:publicUser(r!)};
 }
 if(path==='/auth/login'&&method==='POST'){
  const email=text(b.email,254,'el correo').toLowerCase();await limited(req,email);if(typeof b.password!=='string'||enc.encode(b.password).length>72)throw new Fault(400,'Revisa la contraseña.');if(email.endsWith('@autorent.demo'))throw new Fault(401,'Ingresa con tu cuenta personal.','INVALID_CREDENTIALS');
  const u=await db().prepare('SELECT * FROM users WHERE email=?').bind(email).first<J>();
  if(!u||!await bcrypt.compare(b.password,u.password_hash))throw new Fault(401,'El correo o la contraseña son incorrectos.','INVALID_CREDENTIALS');
  const remember=b.recordar===true||b.recordar_sesion===true, seconds=remember?(b.web===true?14*86400:30*86400):3600;
  const token=await sign(u.id,seconds), data={user:publicUser(u),expiresIn:seconds};
  if(b.web===true){
   if(req.headers.get('Origin')!==url.origin)throw new Fault(403,'Abre AutoRent para iniciar sesión.');
   return jsonResponse(data,sessionCookie(token,remember?seconds:undefined));
  }
  return {...data,accessToken:token,tokenType:'Bearer'};
 }
 if(path==='/auth/logout'&&method==='POST'){
  if(req.headers.get('Origin')!==url.origin)throw new Fault(403,'Abre AutoRent para cerrar sesión.');
  return jsonResponse({ok:true},sessionCookie('',0));
 }
 if(path==='/auth/me')return {user:publicUser(await user(req))};
 if(path==='/catalogs')return catalogs();
 if(path==='/locations'&&method==='GET')return {locations:(await places()).filter(l=>l.activo&&!l.eliminado)};
 if(path==='/reservation-settings'&&method==='GET')return {minutos:await reservationMinutes(db())};
 if((path==='/vehicles'||path==='/admin/vehicles')&&method==='GET'){
  if(path.startsWith('/admin'))await user(req,true);let rows=(await cars()).filter(v=>!v.eliminado);if(!path.startsWith('/admin'))rows=rows.filter(v=>v.publicado!==false);
  for(const [q,k] of [['marca_id','marca'],['modelo_id','modelo'],['categoria_id','categoria']])if(url.searchParams.get(q))rows=rows.filter(v=>String(v[k].id)===url.searchParams.get(q));
  for(const [q,field,cmp] of [['precio_min','precio_dia','min'],['precio_max','precio_dia','max'],['kilometraje_min','kilometraje','min'],['kilometraje_max','kilometraje','max']])if(url.searchParams.get(q)){const n=Number(url.searchParams.get(q));rows=rows.filter(v=>v[field]!=null&&(cmp==='min'?Number(v[field])>=n:Number(v[field])<=n));}
  const start=url.searchParams.get('inicio'),end=url.searchParams.get('fin');if(start&&end){const blocked=await db().prepare(`SELECT vehicle_id FROM reservations WHERE ${activeReservationSql} AND inicio<? AND fin>?`).bind(new Date(end).toISOString(),new Date(start).toISOString()).all<J>();rows=rows.filter(v=>!blocked.results.some(r=>r.vehicle_id===v.id));}
  const p=pagination(rows,url);return {vehicles:p.rows,pagination:p.pagination};
 }
 if(/^\/vehicles\/\d+\/availability$/.test(path)&&method==='GET'){const id=Number(path.split('/')[2]);await vehicle(id);const rows=await db().prepare(`SELECT inicio AS inicio_utc,fin AS fin_utc FROM reservations WHERE vehicle_id=? AND ${activeReservationSql} AND fin>? ORDER BY inicio`).bind(id,new Date().toISOString()).all();return {periods:rows.results};}
 if(/^\/vehicles\/\d+$/.test(path)&&method==='GET'){const v=await vehicle(Number(path.split('/')[2]));if(v.eliminado||v.publicado===false)throw new Fault(404,'Vehículo no encontrado.');return {vehicle:v};}
 if(path==='/reservations/quote'&&method==='POST'){const u=await user(req);if(u.rol!=='cliente')throw new Fault(403,'Usa una cuenta cliente para reservar.');const q=await quote(b);return {dias_cobrados:q.days,precio_dia:money(q.price),total:money(q.total),minutos:await reservationMinutes(db())};}
 if(path==='/reservations'&&method==='POST'){
  const u=await user(req);if(u.rol!=='cliente')throw new Fault(403,'Usa una cuenta cliente para reservar.');const accept=consent(b.aceptacion),operation=req.headers.get('Idempotency-Key');if(!operation||operation.length>160)throw new Fault(400,'Falta la clave de reintento.');
  const fp=await sha(JSON.stringify([u.id,b.vehiculo_id,b.inicio,b.fin,b.entrega_id,b.devolucion_id,b.precio_confirmado,b.documento_id]));
  const expired=await db().prepare('SELECT user_id,fingerprint FROM reservation_expirations WHERE operation_key=?').bind(operation).first<J>();
  if(expired){if(expired.user_id!==u.id||expired.fingerprint!==fp)throw new Fault(409,'La clave corresponde a otra operación.');throw new Fault(410,expirationMessage,'RESERVATION_EXPIRED');}
  const old=await db().prepare('SELECT * FROM reservations WHERE operation_key=?').bind(operation).first<J>();if(old){if(old.user_id!==u.id||old.fingerprint!==fp)throw new Fault(409,'La clave corresponde a otra operación.');return {reservation:await reservation(old)};}
  const doc=await db().prepare('SELECT * FROM driver_documents WHERE id=? AND user_id=?').bind(String(b.documento_id||''),u.id).first<J>();if(!doc)throw new Fault(400,'Adjunta ambas caras de tu licencia de conducir antes de confirmar.','LICENSE_REQUIRED');
  const q=await quote(b);if(String(b.precio_confirmado)!==money(q.price))throw new Fault(409,'La tarifa cambió. Solicita otra cotización.');
  const assessment=doc.assessment?JSON.parse(doc.assessment):null;
  const lastRentalDay=new Date(Date.parse(q.end)-6*3600000-1).toISOString().slice(0,10);
  const decision=reservationDecision(doc.status,doc.expires_on,assessment,lastRentalDay);
  const createdAt=new Date().toISOString(), deadline=validationDeadline(createdAt,await reservationMinutes(db()));
  const code='AR-'+crypto.randomUUID().slice(0,8).toUpperCase();
  try{
   const r=await db().prepare(createReservationSql)
    .bind(decision.status,decision.status,code,u.id,q.v.id,q.start,q.end,q.price,q.days,q.total,Number(b.entrega_id),Number(b.devolucion_id),operation,fp,accept,createdAt,doc.id,deadline,decision.note,decision.note?createdAt:null,q.v.id,q.price/100,q.start,Number(b.entrega_id),Number(b.devolucion_id),q.v.id,q.end,q.start).first<J>();
   if(!r){await quote(b);throw new Fault(409,'La tarifa cambió. Consulta el total nuevamente.');}return {reservation:await reservation(r)};
  }catch(e){if(e instanceof Fault)throw e;const repeat=await db().prepare('SELECT * FROM reservations WHERE operation_key=?').bind(operation).first<J>();if(repeat&&repeat.user_id===u.id&&repeat.fingerprint===fp)return {reservation:await reservation(repeat)};throw e;}
 }
 if(path==='/reservations'&&method==='GET'){
  const u=await user(req),admin=u.rol==='administrador';
  const rows=await db().prepare(`SELECT r.*,u.nombres||' '||u.apellidos AS customer FROM reservations r JOIN users u ON r.user_id=u.id ${admin?'':'WHERE r.user_id=?'} ORDER BY r.id DESC`).bind(...(admin?[]:[u.id])).all<J>();
  const norm=(value:string)=>value.normalize('NFD').replace(/\p{M}/gu,'').toLowerCase().trim();
  const search=norm((url.searchParams.get('buscar')||url.searchParams.get('q')||'').slice(0,120)),status=url.searchParams.get('estado');
  const hideExpired=url.searchParams.get('vista')==='sin_vencidas';
  const list=rows.results.filter(r=>(!status||r.estado===status)&&(!hideExpired||r.estado!=='vencida')&&(!search||norm(r.codigo).includes(search)||(admin&&norm(r.customer).includes(search))));
  const p=pagination(list,url);return {reservations:await Promise.all(p.rows.map(reservation)),pagination:p.pagination};
 }
 if(/^\/reservations\/\d+(\/cancel)?$/.test(path)){const {u,r}=await owned(req,Number(path.split('/')[2]));if(path.endsWith('/cancel')&&method==='POST'){if(u.rol!=='administrador'&&new Date(r.inicio).getTime()<=Date.now())throw new Fault(409,'Esta reserva ya no se puede cancelar.');const updated=await db().prepare(`UPDATE reservations SET estado='cancelada' WHERE id=? AND (estado='confirmada' OR (${awaitingReviewSql} AND ${deadlineSql}>julianday('now'))) RETURNING *`).bind(r.id).first<J>();if(!updated)throw new Fault(409,'Esta reserva ya no se puede cancelar.');return {reservation:await reservation(updated)};}return {reservation:await reservation(r)};}
 if(/^\/admin\/reservations\/\d+\/(validate|deny)$/.test(path)&&method==='POST'){
  const admin=await user(req,true),id=Number(path.split('/')[3]),now=new Date().toISOString();
  const r=path.endsWith('/deny')
   ? await db().prepare(`UPDATE reservations SET estado='denegada',review_note=?,reviewed_by=?,reviewed_at=? WHERE id=? AND ((${awaitingReviewSql} AND ${deadlineSql}>julianday('now')) OR estado='denegada_automatica' OR (estado='denegada' AND reviewed_by IS NULL AND ${deadlineSql}>julianday('now'))) RETURNING *`).bind(text(b.motivo,400,'el motivo de denegación'),admin.id,now,id).first<J>()
   : await db().prepare(validateReservationSql).bind(admin.id,now,id).first<J>();
  if(!r)throw new Fault(409,'La reserva venció, ya fue procesada o las fechas ya no están disponibles.');
  return {reservation:await reservation(r)};
 }
 if(path==='/payment-details'&&method==='GET'){const row=await db().prepare("SELECT data FROM settings WHERE key='payment'").first<{data:string}>();return {payment:row?JSON.parse(row.data):null};}
 if(path==='/admin/payment-details'&&method==='PUT'){
  await user(req,true);const payment={banco:text(b.banco,100,'el banco'),titular:text(b.titular,160,'el titular'),numero_cuenta:text(b.numero_cuenta,80,'el número de cuenta'),tipo_cuenta:text(b.tipo_cuenta,80,'el tipo de cuenta'),instrucciones:typeof b.instrucciones==='string'?b.instrucciones.trim():''};
  if(payment.instrucciones.length>1000)throw new Fault(400,'Las instrucciones son demasiado largas.');
  await db().prepare("INSERT INTO settings(key,data) VALUES('payment',?) ON CONFLICT(key) DO UPDATE SET data=excluded.data").bind(JSON.stringify(payment)).run();return {payment};
 }
 if(path==='/notifications'&&method==='GET'){
  const u=await user(req);
  const notices=await db().prepare(`SELECT id,codigo,message AS mensaje,created_at AS creado_en,read_at FROM reservation_notifications WHERE user_id=?
    UNION ALL SELECT -r.id,r.codigo,r.review_note,r.reviewed_at,NULL FROM reservations r
    WHERE r.user_id=? AND r.review_note IS NOT NULL AND NOT EXISTS(
      SELECT 1 FROM reservation_notifications n WHERE n.user_id=r.user_id AND n.codigo=r.codigo AND n.message=r.review_note
    ) ORDER BY creado_en DESC, id DESC LIMIT 100`).bind(u.id,u.id).all<J>();
  return {notifications:notices.results.map(n=>({...n,titulo:`Reserva ${n.codigo}`})),unread:notices.results.filter(n=>!n.read_at).length,pagination:{total:notices.results.length,totalPages:1}};
 }
 if(path==='/admin/expired-reservations'&&method==='GET'){
  await user(req,true);
  const rows=await db().prepare('SELECT * FROM reservation_expirations ORDER BY expired_at DESC LIMIT 500').all();
  return {reservations:rows.results};
 }
 if(path==='/reservation-config'&&method==='GET')return {hours:(await reservationMinutes(db()))/60};
 if(path==='/admin/reservation-config'&&method==='PUT'){
  await user(req,true);
  const hours=Number(b.hours);
  if(!Number.isInteger(hours)||hours<1||hours>72)throw new Fault(400,'El plazo debe ser de 1 a 72 horas.');
  await db().prepare("INSERT INTO settings(key,data) VALUES('reservation_minutes',?) ON CONFLICT(key) DO UPDATE SET data=excluded.data").bind(String(hours*60)).run();
  return {hours};
 }
 if(path.startsWith('/admin/')){
  await user(req,true);
  if(path==='/admin/reservation-settings'&&method==='PUT'){
   const minutes=Number(b.minutos);
   if(!Number.isInteger(minutes)||minutes<1||minutes>1440)throw new Fault(400,'Escribe entre 1 y 1440 minutos.');
   await db().prepare("INSERT INTO settings(key,data) VALUES('reservation_minutes',?) ON CONFLICT(key) DO UPDATE SET data=excluded.data").bind(String(minutes)).run();
   return {minutos:minutes};
  }
  if(path==='/admin/locations'&&method==='GET')return {locations:(await places()).filter(l=>!l.eliminado)};
  if(/^\/admin\/locations\/\d+$/.test(path)&&method==='DELETE'){
   const id=Number(path.split('/')[3]);
   const result=await db().prepare(`UPDATE locations SET data=json_set(data,'$.activo',json('false'),'$.eliminado',json('true')) WHERE id=? AND json_extract(data,'$.eliminado') IS NOT 1 AND NOT EXISTS(SELECT 1 FROM reservations WHERE (pickup=locations.id OR dropoff=locations.id) AND ${activeReservationSql} AND (fin>strftime('%Y-%m-%dT%H:%M:%fZ','now') OR estado='en_curso')) RETURNING id`).bind(id).first();
   if(!result)throw new Fault(409,'El punto ya no existe o todavía tiene reservas activas.');return {ok:true};
  }
  if(/^\/admin\/locations(\/\d+)?$/.test(path)&&['POST','PATCH','PUT'].includes(method)){
   const id=Number(path.split('/')[3])||null;
   const l={nombre:text(b.nombre,120,'el nombre'),direccion:text(b.direccion,300,'la dirección'),ciudad:typeof b.ciudad==='string'?b.ciudad.trim().slice(0,120):'',indicaciones:typeof b.indicaciones==='string'?b.indicaciones.trim().slice(0,600):'',latitud:Number(b.latitud),longitud:Number(b.longitud),activo:b.activo!==false,tipo:b.tipo==='punto_autorizado'?b.tipo:'sucursal'};
   if(!Number.isFinite(l.latitud)||Math.abs(l.latitud)>90||!Number.isFinite(l.longitud)||Math.abs(l.longitud)>180)throw new Fault(400,'Coordenadas no válidas.');
   return {location:await saveCatalogRow(db(),'locations',id,l)};
  }
  if(/^\/admin\/vehicles\/\d+$/.test(path)&&method==='DELETE'){
   const id=Number(path.split('/')[3]);
   const result=await db().prepare(`UPDATE vehicles SET data=json_set(data,'$.publicado',json('false'),'$.reservable',json('false'),'$.eliminado',json('true')) WHERE id=? AND json_extract(data,'$.eliminado') IS NOT 1 AND NOT EXISTS(SELECT 1 FROM reservations WHERE vehicle_id=vehicles.id AND ${activeReservationSql} AND (fin>strftime('%Y-%m-%dT%H:%M:%fZ','now') OR estado='en_curso')) RETURNING id`).bind(id).first();
   if(!result)throw new Fault(409,'El vehículo ya no existe o todavía tiene reservas activas.');return {ok:true};
  }
  if(/^\/admin\/vehicles(\/\d+)?$/.test(path)&&['POST','PATCH'].includes(method)){
   const id=Number(path.split('/')[3])||null, old=id?await vehicle(id):{};
   return {vehicle:await saveCatalogRow(db(),'vehicles',id,editVehicle(b,old,await places(),(await catalogs()).categorias))};
  }
  if(/^\/admin\/reservations\/\d+\/(checkout|return)$/.test(path)&&method==='POST'){
   const id=Number(path.split('/')[3]),r=await db().prepare('SELECT * FROM reservations WHERE id=?').bind(id).first<J>();if(!r)throw new Fault(404,'Reserva no encontrada.');const returning=path.endsWith('/return'),km=Number(b.kilometraje);if(!returning&&r.document_id){if(b.licencia_valida!==true)throw new Fault(400,'Revisa la licencia y confirma que es válida antes de entregar el vehículo.');const doc=await db().prepare('SELECT * FROM driver_documents WHERE id=?').bind(r.document_id).first<J>();if(!doc||doc.expires_on<new Date(Date.parse(r.fin)-6*3600000-1).toISOString().slice(0,10))throw new Fault(409,'La licencia no está vigente para esta reserva.');await db().prepare("UPDATE driver_documents SET status='verificada' WHERE id=?").bind(r.document_id).run();}if(!Number.isSafeInteger(km)||km<0||returning&&km<r.km_out)throw new Fault(400,'Kilometraje no válido.');if(r.estado!==(returning?'en_curso':'confirmada'))throw new Fault(409,'El estado cambió.');await db().prepare(`UPDATE reservations SET estado=?,${returning?'km_in':'km_out'}=? WHERE id=? AND estado=?`).bind(returning?'completada':'en_curso',km,id,r.estado).run();return {ok:true};
  }
  if(path==='/admin/business'&&['PUT','PATCH'].includes(method)){await db().prepare('UPDATE settings SET data=? WHERE key=?').bind(JSON.stringify(b),'business').run();return {business:b};}
 }
 if(path==='/privacy/export'){const u=await user(req),r=await db().prepare('SELECT * FROM reservations WHERE user_id=?').bind(u.id).all<J>();return {user:publicUser(u),reservations:await Promise.all(r.results.map(reservation))};}
 if(path==='/privacy/requests'||path==='/admin/privacy/requests'){
  const u=await user(req,path.startsWith('/admin'));if(method==='POST'){const data={tipo:text(b.tipo,40,'el tipo'),detalle:text(b.detalle,2000,'el detalle'),estado:'recibida',creado_en:new Date().toISOString()};const r=await db().prepare('INSERT INTO privacy_requests(user_id,data) VALUES(?,?) RETURNING id').bind(u.id,JSON.stringify(data)).first<J>();return {id:r!.id};}
  const rows=await db().prepare(path.startsWith('/admin')?'SELECT * FROM privacy_requests ORDER BY id DESC':'SELECT * FROM privacy_requests WHERE user_id=? ORDER BY id DESC').bind(...(path.startsWith('/admin')?[]:[u.id])).all<J>();return {requests:rows.results.map(r=>({id:r.id,...JSON.parse(r.data)})),pagination:{total:rows.results.length,totalPages:1}};
 }
 if(/^\/admin\/privacy\/requests\/\d+$/.test(path)&&method==='PUT'){await user(req,true);const id=Number(path.split('/').pop()),old=await db().prepare('SELECT data FROM privacy_requests WHERE id=?').bind(id).first<J>();if(!old)throw new Fault(404,'Solicitud no encontrada.');const data={...JSON.parse(old.data),estado:text(b.estado,40,'el estado'),respuesta:text(b.respuesta,3000,'la respuesta')};await db().prepare('UPDATE privacy_requests SET data=? WHERE id=?').bind(JSON.stringify(data),id).run();return data;}
 throw new Fault(404,'Función no disponible en este despliegue.','NOT_FOUND');
}
const headers={'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','Access-Control-Allow-Origin':'*','Access-Control-Allow-Methods':'GET,HEAD,POST,PATCH,PUT,DELETE,OPTIONS','Access-Control-Allow-Headers':'Authorization,Content-Type,Idempotency-Key','X-Content-Type-Options':'nosniff'};
function jsonResponse(data: unknown, cookie?: string){return new Response(JSON.stringify({success:true,data}),{headers:{...headers,...(cookie?{'Set-Cookie':cookie}:{})}});}
async function handle(req:Request){try{const data=await execute(req);return data instanceof Response?data:jsonResponse(data);}catch(e){const f=e instanceof Fault||e instanceof DocumentError||e instanceof FleetError?e:new Fault(500,'No se pudo completar la operación. Intenta nuevamente.','INTERNAL_ERROR');return new Response(JSON.stringify({success:false,error:{code:f.code,message:f.message}}),{status:f.status,headers});}}
export const GET=handle,HEAD=handle,POST=handle,PATCH=handle,PUT=handle,DELETE=handle,OPTIONS=handle;
