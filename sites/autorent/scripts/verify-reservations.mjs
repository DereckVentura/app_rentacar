import assert from 'node:assert/strict';
// Isolated local preview only; never creates test users or bookings on the public site.
const base='http://127.0.0.1:5173/api/v1';
const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aK1sAAAAASUVORK5CYII=','base64');
const stamp=crypto.randomUUID();
async function request(path,{token,body,key,form}={}){
 const response=await fetch(base+path,{method:body||form?'POST':'GET',headers:{...(token?{Authorization:'Bearer '+token}:{}),...(!form?{'Content-Type':'application/json'}:{}),...(key?{'Idempotency-Key':key}:{})},body:form|| (body?JSON.stringify(body):undefined)});
 const data=response.headers.get('content-type')?.includes('application/json')?await response.json():null;return {status:response.status,data:data?.data,error:data?.error,response};
}
const content=(await request('/content')).data;
const consent={version:content.version,privacidad:true,terminos:true};
async function account(i){const email=`qa-${stamp}-${i}@example.test`,password=crypto.randomUUID()+'Aa1!';let r=await request('/auth/register',{body:{email,password,nombres:'QA',apellidos:'Local',aceptacion:consent}});assert.equal(r.status,200,JSON.stringify(r.error));r=await request('/auth/login',{body:{email,password}});assert.equal(r.status,200);return r.data.accessToken;}
function form(){const f=new FormData();f.set('titular','Prueba local');f.set('pais','El Salvador');f.set('vencimiento','2035-12-31');f.set('consentimiento','true');f.set('frente',new Blob([png],{type:'image/png'}),'frente.png');f.set('reverso',new Blob([png],{type:'image/png'}),'reverso.png');return f;}
const token=await account(1),other=await account(2);
const cars=(await request('/vehicles')).data.vehicles;assert.deepEqual(cars.map(v=>v.precio_dia),['40.00','40.00','35.00']);assert.deepEqual(cars.map(v=>v.placa),['P 43 9C5','P 37 DE9','P 15 F44']);assert(cars.every(v=>v.reservable));
const day=new Date(Date.now()+45*86400000).toISOString().slice(0,10),next=new Date(Date.now()+46*86400000).toISOString().slice(0,10);
const input={vehiculo_id:3,inicio:day+'T09:00:00-06:00',fin:next+'T09:00:00-06:00',entrega_id:1,devolucion_id:1,precio_confirmado:'35.00',aceptacion:consent};
let r=await request('/reservations',{token,body:input,key:crypto.randomUUID()});assert.equal(r.status,400);assert.equal(r.error.code,'LICENSE_REQUIRED');
const missing=form();missing.delete('reverso');r=await request('/driver-documents',{token,form:missing});assert.equal(r.status,400);
const bad=form();bad.set('frente',new Blob(['not an image']),'frente.png');r=await request('/driver-documents',{token,form:bad});assert.equal(r.status,400);
r=await request('/driver-documents',{token,form:form()});assert.equal(r.status,200,JSON.stringify(r.error));const document=r.data.document;
const jsonDocument={titular:'Otro conductor',pais:'El Salvador',vencimiento:'2035-12-31',consentimiento:true,frente:png.toString('base64'),reverso:png.toString('base64')};
r=await request('/driver-documents',{token:other,body:jsonDocument});assert.equal(r.status,200,JSON.stringify(r.error));const otherDocument=r.data.document;
const image=`/driver-documents/${document.id}/image?side=front`;
r=await request(image);assert.equal(r.status,401);r=await request(image,{token:other});assert.equal(r.status,403);r=await request(image,{token});assert.equal(r.status,200);assert.equal(r.response.headers.get('cache-control'),'private, no-store');assert.deepEqual(Buffer.from(await r.response.arrayBuffer()),png);
const key=crypto.randomUUID(),body={...input,documento_id:document.id};
r=await request('/reservations',{token,body,key});assert.equal(r.status,200,JSON.stringify(r.error));const booking=r.data.reservation;
r=await request('/reservations',{token,body,key});assert.equal(r.data.reservation.id,booking.id);
r=await request('/vehicles/3/availability');assert(r.data.periods.some(p=>p.inicio_utc===booking.inicio_utc));assert(r.data.periods.every(p=>Object.keys(p).sort().join(',')==='fin_utc,inicio_utc'));
r=await request('/reservations',{token:other,body:{...input,documento_id:otherDocument.id},key:crypto.randomUUID()});assert.equal(r.status,409);assert.match(r.error.message,/Las fechas seleccionadas ya están reservadas/);
r=await request(`/reservations/${booking.id}/cancel`,{token,body:{}});assert.equal(r.status,200);
r=await request('/vehicles/3/availability');assert(!r.data.periods.some(p=>p.inicio_utc===booking.inicio_utc));
const concurrent=await Promise.all([request('/reservations',{token,body,key:crypto.randomUUID()}),request('/reservations',{token:other,body:{...input,documento_id:otherDocument.id},key:crypto.randomUUID()})]);
assert.deepEqual(concurrent.map(r=>r.status).sort(),[200,409]);for(let i=0;i<concurrent.length;i++)if(concurrent[i].status===200)await request(`/reservations/${concurrent[i].data.reservation.id}/cancel`,{token:i===0?token:other,body:{}});
console.log('PASS: tarifas y placas; licencia obligatoria; imágenes válidas; captura y carga; acceso privado; reintentos; calendario; cancelación; reservas simultáneas.');
