import { env } from 'cloudflare:workers';
export const dynamic='force-dynamic';
// Installer publication requires its own secret.
async function handle(req:Request){
 if(!env.UPLOAD_SECRET||req.headers.get('Authorization')!==`Bearer ${env.UPLOAD_SECRET}`)return new Response('No autorizado',{status:403});
 if(!env.BUCKET)return new Response('Sin almacenamiento',{status:503});
 const url=new URL(req.url),name=url.searchParams.get('name')||'';
 if(!['AutoRent.apk','AutoRent-iOS-Installer.mobileconfig'].includes(name))return new Response('Nombre no válido',{status:400});
 const type=name.endsWith('.apk')?'application/vnd.android.package-archive':'application/x-apple-aspen-config';
 if(req.method==='POST'&&!url.searchParams.has('uploadId')){const upload=await env.BUCKET.createMultipartUpload(name,{httpMetadata:{contentType:type}});return Response.json({uploadId:upload.uploadId});}
 const id=url.searchParams.get('uploadId');if(!id)return new Response('Falta uploadId',{status:400});
 const upload=env.BUCKET.resumeMultipartUpload(name,id);
 const part=Number(url.searchParams.get('part'));
 const segmentKey=(segment:number)=>`__upload/${name}/${id}/${part}/${segment}`;
 if(req.method==='PUT'){
  const part=Number(url.searchParams.get('part'));
  if(!Number.isInteger(part)||part<1||!req.body)return new Response('Parte no válida',{status:400});
  const stream=req.headers.get('X-Artifact-Encoding')==='gzip'?req.body.pipeThrough(new DecompressionStream('gzip')):req.body;
  const payload=await new Response(stream).arrayBuffer();
  if(payload.byteLength>8*1024*1024)return new Response('Parte demasiado grande',{status:413});
  if(url.searchParams.has('segment')){
   const segment=Number(url.searchParams.get('segment'));
   if(!Number.isInteger(segment)||segment<1||segment>16||payload.byteLength>512*1024)return new Response('Segmento no válido',{status:400});
   await env.BUCKET.put(segmentKey(segment),payload);return Response.json({ok:true});
  }
  const done=await upload.uploadPart(part,payload);return Response.json(done);
 }
 if(req.method==='POST'&&url.searchParams.has('part')){
  const count=Number(url.searchParams.get('segments'));
  if(!Number.isInteger(part)||part<1||!Number.isInteger(count)||count<1||count>16)return new Response('Parte no válida',{status:400});
  const keys=Array.from({length:count},(_,i)=>segmentKey(i+1));
  const chunks=await Promise.all(keys.map(async key=>{const chunk=await env.BUCKET!.get(key);if(!chunk)throw Error('Segmento pendiente');return new Uint8Array(await chunk.arrayBuffer());}));
  const payload=new Uint8Array(chunks.reduce((sum,chunk)=>sum+chunk.length,0));let offset=0;
  for(const chunk of chunks){payload.set(chunk,offset);offset+=chunk.length;}
  const done=await upload.uploadPart(part,payload);return Response.json(done);
 }
 if(req.method==='POST'){const body=await req.json() as {parts:R2UploadedPart[]};await upload.complete(body.parts);return Response.json({ok:true});}
 return new Response('Método no permitido',{status:405});
}
export const POST=handle,PUT=handle;
