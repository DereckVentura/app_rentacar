import { env } from 'cloudflare:workers';
export const dynamic='force-dynamic';
async function download(req:Request){
 const name=decodeURIComponent(new URL(req.url).pathname.split('/').pop()||'');
 if(!['AutoRent.apk','AutoRent-iOS-Installer.mobileconfig'].includes(name))return new Response('Archivo no encontrado',{status:404});
 if(!env.BUCKET)return new Response('Almacenamiento no disponible',{status:503});
 const wantsRange=req.method!=='HEAD'&&req.headers.has('Range');
 const object=req.method==='HEAD'?await env.BUCKET.head(name):wantsRange?await env.BUCKET.get(name,{range:req.headers}):await env.BUCKET.get(name);
 if(!object)return new Response('La descarga aún se está preparando. Intenta nuevamente en unos minutos.',{status:503,headers:{'Retry-After':'120'}});
 const headers=new Headers();object.writeHttpMetadata(headers);
 headers.set('Content-Type',name.endsWith('.apk')?'application/vnd.android.package-archive':'application/x-apple-aspen-config');
 headers.set('Content-Disposition',`${name.endsWith('.apk')?'attachment':'inline'}; filename="${name}"`);
 headers.set('ETag',object.httpEtag);headers.set('X-Content-Type-Options','nosniff');headers.set('Cache-Control','public, max-age=0, must-revalidate');headers.set('Accept-Ranges','bytes');
 const range=wantsRange&&'range' in object?object.range:undefined;
 const offset=range&&'offset' in range?range.offset:undefined,length=range&&'length' in range?range.length:undefined;
 if(offset!==undefined&&length!==undefined){headers.set('Content-Range',`bytes ${offset}-${offset+length-1}/${object.size}`);headers.set('Content-Length',String(length));}
 else headers.set('Content-Length',String(object.size));
 return new Response(req.method==='HEAD'?null:(object as R2ObjectBody).body,{status:offset!==undefined?206:200,headers});
}
export const GET=download,HEAD=download;
