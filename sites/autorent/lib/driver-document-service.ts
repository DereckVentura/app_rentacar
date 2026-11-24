import { env } from 'cloudflare:workers';
import { assessLicense, monthEnd, type LicenseReading } from './license-assessment';
import { assessLicenseWithAI, readLicenseWithAI } from './license-ai';
type J=Record<string,any>;
export class DocumentError extends Error { constructor(public status:number,message:string,public code='LICENSE_REQUIRED'){super(message);} }
const fail=(status:number,message:string):never=>{throw new DocumentError(status,message);};
export const documentView=(d:J)=>({id:d.id,titular:d.holder,pais:d.country,vencimiento:d.expires_on,estado:d.status,evaluacion:d.assessment?JSON.parse(d.assessment):null});
async function photo(value:FormDataEntryValue|null){
 if(!(value instanceof File)||value.size<16||value.size>3*1024*1024)fail(400,'Adjunta ambas caras de la licencia, hasta 3 MB por imagen.');
 const bytes=new Uint8Array(await (value as File).arrayBuffer());let type='';
 if(bytes[0]===255&&bytes[1]===216&&bytes[2]===255)type='image/jpeg';
 else if([137,80,78,71,13,10,26,10].every((n,i)=>bytes[i]===n))type='image/png';
 else if(new TextDecoder().decode(bytes.slice(0,4))==='RIFF'&&new TextDecoder().decode(bytes.slice(8,12))==='WEBP')type='image/webp';
 if(!type)fail(400,'La licencia debe ser una imagen JPG, PNG o WebP válida.');
 return {bytes,type};
}
export async function driverDocumentRoute(req:Request,path:string,db:D1Database,user:J):Promise<J|Response>{
 if(user.email.endsWith('@autorent.demo'))fail(403,'Ingresa con una cuenta personal para gestionar documentos.');
 if(!env.BUCKET)fail(503,'No se pudo acceder al almacenamiento de documentos.');
 const bucket=env.BUCKET!;
 if(req.method==='POST'&&path==='/driver-documents'){
  if(user.rol!=='cliente')fail(403,'Usa una cuenta cliente para adjuntar la licencia.');
  if(Number(req.headers.get('Content-Length')||0)>9*1024*1024)fail(413,'Las imágenes son demasiado grandes.');
  // Bound the body even when the caller does not send Content-Length.
  const reader=req.body?.getReader();if(!reader)fail(400,'Adjunta la licencia.');let size=0;const chunks:Uint8Array[]=[];
  while(true){const {done,value}=await reader!.read();if(done)break;size+=value.length;if(size>9*1024*1024){await reader!.cancel();fail(413,'Las imágenes son demasiado grandes.');}chunks.push(value);}
  const body=new Uint8Array(size);let offset=0;for(const chunk of chunks){body.set(chunk,offset);offset+=chunk.length;}
  let form:FormData;
  if(req.headers.get('Content-Type')?.includes('application/json')){
   const input=JSON.parse(new TextDecoder().decode(body));form=new FormData();
   for(const field of ['titular','pais','vencimiento'])form.set(field,String(input[field]||''));form.set('consentimiento',input.consentimiento===true?'true':'false');
   form.set('consentimiento_ia',input.consentimiento_ia===true?'true':'false');
   if(input.lectura&&typeof input.lectura==='object')form.set('lectura',JSON.stringify(input.lectura));
   for(const field of ['frente','reverso']){const encoded=input[field];if(typeof encoded!=='string'||encoded.length>4194304||encoded.length%4!==0||!/^[A-Za-z0-9+/]*={0,2}$/.test(encoded))fail(400,'Adjunta imágenes válidas de hasta 3 MB.');let decoded:string;try{decoded=atob(encoded);}catch{fail(400,'Imagen no válida.');}form.set(field,new File([Uint8Array.from(decoded!,c=>c.charCodeAt(0))],'licencia'));}
  }else{form=await new Request(req.url,{method:'POST',headers:{'Content-Type':req.headers.get('Content-Type')||''},body}).formData();}
  const holder=String(form.get('titular')||'').trim(),country=String(form.get('pais')||'El Salvador').trim(),entered=String(form.get('vencimiento')||'');
  const expires=monthEnd(entered) ?? entered;
  if(!holder||holder.length>180||!country||country.length>80||form.get('consentimiento')!=='true')fail(400,'Completa los datos de la licencia y autoriza su revisión.');
  if(!/^\d{4}-\d{2}-\d{2}$/.test(expires)||!Number.isFinite(Date.parse(expires))||new Date(expires).toISOString().slice(0,10)!==expires)fail(400,'Indica el mes y año de vencimiento de la licencia.');
  let reading: LicenseReading = {};
  try { const raw = String(form.get('lectura') || '{}'); if (raw.length < 1500) reading = JSON.parse(raw) ?? {}; } catch { /* OCR unavailable */ }
  const count=await db.prepare('SELECT COUNT(*) total FROM driver_documents WHERE user_id=? AND created_at>?').bind(user.id,new Date(Date.now()-86400000).toISOString()).first<{total:number}>();if((count?.total||0)>=10)fail(429,'Alcanzaste el límite de documentos de hoy. Intenta mañana.');
  const front=await photo(form.get('frente')),back=await photo(form.get('reverso')),id=crypto.randomUUID(),frontKey=`private/drivers/${user.id}/${id}/front`,backKey=`private/drivers/${user.id}/${id}/back`;
  const today = new Date(Date.now()-6*3600000).toISOString().slice(0,10);
  const aiKey = form.get('consentimiento_ia') === 'true' ? env.OPENAI_API_KEY : undefined;
  const assessment = aiKey
    ? assessLicenseWithAI(await readLicenseWithAI(aiKey, front, back), holder, expires, today)
    : assessLicense(reading, holder, expires, today);
  try{await bucket.put(frontKey,front.bytes,{httpMetadata:{contentType:front.type}});await bucket.put(backKey,back.bytes,{httpMetadata:{contentType:back.type}});
   const d=await db.prepare("INSERT INTO driver_documents(id,user_id,document_type,country,holder,expires_on,front_key,front_type,back_key,back_type,status,created_at,assessment) VALUES(?,?,'licencia',?,?,?,?,?,?,?,'pendiente',?,?) RETURNING *").bind(id,user.id,country,holder,expires,frontKey,front.type,backKey,back.type,new Date().toISOString(),JSON.stringify(assessment)).first<J>();return {document:documentView(d!)};
  }catch(e){await Promise.allSettled([bucket.delete(frontKey),bucket.delete(backKey)]);throw e;}
 }
 if(req.method!=='GET')fail(405,'Operación no permitida.');
 const d=await db.prepare('SELECT * FROM driver_documents WHERE id=?').bind(path.split('/')[2]).first<J>();if(!d)fail(404,'Documento no encontrado.');if(user.id!==d!.user_id&&user.rol!=='administrador')fail(403,'Esta licencia es privada.');
 const back=new URL(req.url).searchParams.get('side')==='back',file=await bucket.get(back?d!.back_key:d!.front_key);if(!file)fail(404,'Imagen no encontrada.');
 return new Response(file!.body,{headers:{'Content-Type':back?d!.back_type:d!.front_type,'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'}});
}
