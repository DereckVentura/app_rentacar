'use client';
import { FormEvent, useEffect, useRef, useState } from 'react';
import { Camera, ImagePlus, RotateCcw } from 'lucide-react';
import { canvasPhoto, imageCanvas, photoCanvas, readLicense } from '../lib/browser-photos';

type Row = Record<string, any>;

function usePreview(file: File | null) {
  const [url, setUrl] = useState('');
  useEffect(() => {
    if (!file) {setUrl('');return;}
    const next = URL.createObjectURL(file);
    setUrl(next);
    return () => URL.revokeObjectURL(next);
  }, [file]);
  return url;
}

function LicensePhoto({label, value, onChange}: {label:string; value:File|null; onChange:(file:File|null)=>void}) {
  const [camera, setCamera] = useState(false), [frameWidth, setFrameWidth] = useState(92);
  const [draft, setDraft] = useState<File|null>(null), [error, setError] = useState('');
  const video = useRef<HTMLVideoElement>(null), gallery = useRef<HTMLInputElement>(null);
  const preview = usePreview(draft ?? value);
  useEffect(() => {
    if (!camera) return;
    let stopped = false, stream:MediaStream|undefined;
    async function start() {
      try {
        stream = await navigator.mediaDevices.getUserMedia({video:{facingMode:{ideal:'environment'}},audio:false});
        if (stopped) stream.getTracks().forEach(track=>track.stop());
        else if (video.current) video.current.srcObject = stream;
      } catch { if(!stopped){setError('No se pudo abrir la cámara. Puedes usar la galería.');setCamera(false);} }
    }
    void start();
    return () => {stopped=true;stream?.getTracks().forEach(track=>track.stop());};
  },[camera]);

  async function prepare(file:File) {
    setError('');
    try {setDraft(await canvasPhoto(await imageCanvas(file),'licencia.jpg'));}
    catch(e) {setError((e as Error).message);}
  }

  async function capture() {
    setError('');
    try {setDraft(await canvasPhoto(photoCanvas(video.current!,true),'licencia.jpg'));setCamera(false);}
    catch(e) {setError((e as Error).message);}
  }

  return <fieldset className="license-photo">
    <legend>{label} de la licencia</legend>
    <input type="file" ref={gallery} hidden accept="image/jpeg,image/png,image/webp" onChange={e=>{const file=e.target.files?.[0];e.target.value='';if(file)void prepare(file);}}/>
    {camera ? <>
      <p>Coloca tu licencia dentro del marco.</p>
      <div className="license-camera"><video ref={video} autoPlay muted playsInline onLoadedMetadata={()=>{const v=video.current!;setFrameWidth(Math.min(1,v.videoHeight*(85.6/53.98)/v.videoWidth)*92);}}/><span className="license-frame" style={{width:`${frameWidth}%`}} aria-hidden="true"/></div>
      <div className="control-row"><button type="button" className="button gold small" onClick={capture}>Tomar foto</button><button type="button" className="text-button" onClick={()=>setCamera(false)}>Cerrar cámara</button></div>
    </> : <>
      {preview && <img className="license-preview" src={preview} alt={`Vista previa del ${label.toLowerCase()} de la licencia`}/>}
      {draft ? <div className="control-row">
        <button type="button" className="button gold small" onClick={()=>{onChange(draft);setDraft(null);}}>Usar esta foto</button>
        <button type="button" className="button outline small" onClick={()=>{setDraft(null);setCamera(true);}}><RotateCcw size={16}/> Repetir foto</button>
        <button type="button" className="text-button" onClick={()=>setDraft(null)}>Descartar vista previa</button>
      </div> : <div className="control-row">
        <button type="button" className="button outline small" onClick={()=>{setError('');setCamera(true);}}><Camera size={16}/> Cámara</button>
        <button type="button" className="button outline small" onClick={()=>gallery.current?.click()}><ImagePlus size={16}/> Galería</button>
        {value&&<button type="button" className="text-button" onClick={()=>onChange(null)}>Quitar foto</button>}
      </div>}
    </>}
    {error&&<p role="alert">{error}</p>}
  </fieldset>;
}

export function DriverLicense({token,onSaved}: {token:string; onSaved:(document:Row|null)=>void}) {
  const [busy,setBusy]=useState(false),[error,setError]=useState(''),[saved,setSaved]=useState(false);
  const [front,setFront]=useState<File|null>(null),[back,setBack]=useState<File|null>(null);
  async function submit(e:FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if(!front||!back){setError('Toma o selecciona ambas fotos y pulsa Usar esta foto.');return;}
    const form=new FormData(e.currentTarget);
    form.set('frente',front);form.set('reverso',back);form.set('vencimiento',`${form.get('anio')}-${form.get('mes')}`);
    setBusy(true);setError('');
    try {
      form.set('lectura',JSON.stringify(await readLicense(front,back)));
      const r=await fetch('/api/v1/driver-documents',{method:'POST',headers:token?{Authorization:`Bearer ${token}`}:{},body:form});
      const data=await r.json() as Row;
      if(!r.ok)throw new Error(data.error?.message||'No se pudo guardar la licencia.');
      onSaved(data.data.document);setSaved(true);
    }catch(e){setError((e as Error).message);onSaved(null);}
    finally{setBusy(false);}
  }
  const year = new Date().getFullYear();
  return <section className="license-panel"><h3>Licencia de conducir</h3>
    {saved ? <><p role="status">Licencia adjunta.</p><button type="button" className="text-button" onClick={()=>{setSaved(false);onSaved(null);}}>Cambiar licencia</button></> :
      <form onSubmit={submit}>
        <label>Nombre completo del titular<input name="titular" autoComplete="name" maxLength={180} required/></label>
        <div className="form-grid">
          <label>Mes de vencimiento<select name="mes" defaultValue="" required><option value="" disabled>Mes</option>{Array.from({length:12},(_,i)=>String(i+1).padStart(2,'0')).map(month=><option key={month}>{month}</option>)}</select></label>
          <label>Año de vencimiento<input name="anio" type="number" inputMode="numeric" min={2000} max={year+30} placeholder="AAAA" required/></label>
        </div>
        <LicensePhoto label="Frente" value={front} onChange={setFront}/><LicensePhoto label="Reverso" value={back} onChange={setBack}/>
        <label className="checkbox-label"><input type="checkbox" name="consentimiento" value="true" required/>Autorizo el uso de mi licencia para verificar esta reserva.</label>
        <label className="checkbox-label"><input type="checkbox" name="consentimiento_ia" value="true"/>Autorizo el envío de las fotos de mi licencia a OpenAI para revisar automáticamente mi solicitud.</label>
        <button className="button outline full" disabled={busy}>{busy?'Revisando y adjuntando…':'Adjuntar licencia'}</button>
      </form>}
    {error&&<p role="alert">{error}</p>}
  </section>;
}

export function PrivateLicense({document,token}: {document:Row;token:string}) {
  const [urls,setUrls]=useState<string[]>([]),[error,setError]=useState(''),[zoom,setZoom]=useState<number|null>(null);
  useEffect(()=>{
    const controller=new AbortController(), created:string[]=[];
    Promise.all(['front','back'].map(async side=>{
      const r=await fetch(`/api/v1/driver-documents/${document.id}/image?side=${side}`,{signal:controller.signal,headers:token?{Authorization:`Bearer ${token}`}:{}});
      if(!r.ok)throw new Error('No se pudo cargar la licencia.');
      const blob=await r.blob();
      if(controller.signal.aborted)return '';
      const url=URL.createObjectURL(blob);created.push(url);return url;
    })).then(images=>{if(!controller.signal.aborted)setUrls(images);}).catch(e=>{if(!controller.signal.aborted)setError(e.message);});
    return()=>{controller.abort();created.forEach(URL.revokeObjectURL);};
  },[document.id,token]);
  const assessment=document.evaluacion;
  return <div className="license-review">
    <p>Titular: {document.titular} · Vence {document.vencimiento?.slice(0,7).split('-').reverse().join('/')}</p>
    {assessment&&<div className="review-reading"><strong>Verificación automática</strong><p>{assessment.motivo || (assessment.estado==='lista'?'El nombre y el vencimiento coinciden.':'La lectura requiere revisión manual.')}</p>{assessment.nombre&&<p>Nombre leído: {assessment.nombre} ({assessment.nombreCoincide?'coincide':'no coincide'})</p>}{assessment.vencimiento&&<p>Vencimiento leído: {assessment.vencimiento} ({assessment.fechaCoincide?'coincide':'no coincide'})</p>}</div>}
    {error&&<p role="alert">{error}</p>}
    {urls.map((url,i)=><button type="button" className={zoom===i?'license-zoom':''} key={url} onClick={()=>setZoom(zoom===i?null:i)} aria-pressed={zoom===i} aria-label={`${zoom===i?'Reducir':'Ampliar'} ${i?'reverso':'frente'} de la licencia`}><img src={url} alt={i?'Reverso de licencia':'Frente de licencia'}/></button>)}
  </div>;
}
