'use client';

import { FormEvent, PointerEvent, useEffect, useRef, useState } from 'react';
import { ArrowDown, ArrowUp, Camera, CarFront, ChevronLeft, ChevronRight, ImagePlus, Trash2 } from 'lucide-react';
import { canvasPhoto, imageCanvas } from '../lib/browser-photos';

type Row = Record<string, any>;
type Photo = {url:string; alt:string};
const displayName = (car:Row) => `${car.marca?.nombre ?? ''} ${car.modelo?.nombre ?? ''}`.trim();

export function FleetCarousel({vehicles,onOpen}: {vehicles:Row[];onOpen:(vehicle:Row)=>void}) {
  const rail = useRef<HTMLDivElement>(null);
  const drag = useRef<{x:number;left:number;moved:boolean;samples:{left:number;at:number}[]}|null>(null);
  const skipClick=useRef(false);
  const [index,setIndex]=useState(0);
  const current=Math.min(index,Math.max(0,vehicles.length-1));
  function move(next:number) {
    const el = rail.current;
    if (!el || !vehicles.length) return;
    const i = (next + vehicles.length) % vehicles.length;
    const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
    el.scrollTo({left:i*el.clientWidth,behavior:reduced?'instant':'smooth'});
  }
  function pointerDown(e:PointerEvent<HTMLDivElement>) {
    const el = rail.current;
    if (e.pointerType !== 'mouse' || e.button !== 0 || !el) return;
    el.scrollTo({left:el.scrollLeft,behavior:'instant'});
    skipClick.current = false;
    drag.current = {x:e.clientX,left:el.scrollLeft,moved:false,samples:[{left:el.scrollLeft,at:e.timeStamp}]};
  }
  function pointerMove(e:PointerEvent<HTMLDivElement>) {
    const el=rail.current, start=drag.current;
    if(!el||!start||Math.abs(e.clientX-start.x)<8&&!start.moved)return;
    if(!start.moved)e.currentTarget.setPointerCapture(e.pointerId);
    start.moved=true;
    el.style.scrollSnapType='none';el.scrollLeft=start.left+start.x-e.clientX;
    start.samples.push({left:el.scrollLeft,at:e.timeStamp});
    start.samples=start.samples.filter(sample=>e.timeStamp-sample.at<110);
  }
  function pointerEnd(e:PointerEvent<HTMLDivElement>) {
    const el=rail.current, start=drag.current;
    drag.current=null;
    if (!el || !start?.moved || !el.clientWidth) return;
    skipClick.current=true;
    const sample=start.samples.find(point=>e.timeStamp-point.at<110);
    const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
    const velocity=sample&&!reduced&&e.type!=='pointercancel'?(el.scrollLeft-sample.left)/Math.max(16,e.timeStamp-sample.at):0;
    const momentum=Math.max(-el.clientWidth,Math.min(el.clientWidth,velocity*125));
    const next=Math.max(0,Math.min(vehicles.length-1,Math.round((el.scrollLeft+momentum)/el.clientWidth)));
    el.style.scrollSnapType='';
    move(next);
    setTimeout(()=>{skipClick.current=false;},0);
  }
  return <section className="hero-visual fleet-hero" aria-label="Carrusel de vehículos">
    <div ref={rail} className="fleet-rail" onScroll={e=>{const el=e.currentTarget;if(el.clientWidth)setIndex(Math.round(el.scrollLeft/el.clientWidth));}} onPointerDown={pointerDown} onPointerMove={pointerMove} onPointerUp={pointerEnd} onPointerCancel={pointerEnd} onPointerLeave={()=>{if(!drag.current?.moved)drag.current=null;}}>
      {vehicles.map(car=><button type="button" className="fleet-slide" key={car.id} onClick={()=>{if(!skipClick.current)onOpen(car);}} aria-label={`Ver ${displayName(car)}`}>
        {car.imagen_url?<img src={car.imagen_url} alt="" draggable={false}/>:<span className="fleet-slide-placeholder"><CarFront size={64}/></span>}
        <span className="photo-gradient"/>
        <span className="hero-car"><span><strong>{displayName(car)}</strong><span className="slide-specs">{[car.anio,car.categoria?.nombre,car.ficha?.color].filter(Boolean).join(' · ')}</span></span><span className="slide-action" aria-hidden="true">Ver ficha</span></span>
      </button>)}
    </div>
    {vehicles.length===0&&<div className="fleet-slide-placeholder"><CarFront size={58}/><p>Aún no hay vehículos publicados.</p></div>}
    {vehicles.length>0&&<div className="fleet-carousel-nav">
      {vehicles.length>1&&<button type="button" aria-label="Vehículo anterior" onClick={()=>move(current-1)}><ChevronLeft/></button>}
      <div className="fleet-carousel-dots">{vehicles.map((car,i)=><button type="button" key={car.id} aria-label={`Ir a ${displayName(car)}`} aria-current={i===current?'true':undefined} onClick={()=>move(i)}/>)}</div>
      <span aria-live="polite">{current+1} de {vehicles.length}</span>
      {vehicles.length>1&&<button type="button" aria-label="Vehículo siguiente" onClick={()=>move(current+1)}><ChevronRight/></button>}
    </div>}
  </section>;
}

const fields = [
  ['marca','Marca'],['modelo','Modelo'],['categoria','Tipo'],['anio','Año','number'],['placa','Placa'],['color','Color'],
  ['precio_dia','Tarifa diaria USD','number'],['kilometraje','Kilometraje','number'],['transmision','Transmisión'],['plazas','Asientos','number'],
  ['traccion','Tracción'],['combustible','Combustible'],['version','Versión'],['motor_litros','Motor (litros)','number'],['potencia_hp','Potencia (HP)','number'],
] as const;

export function VehicleEditor({vehicle,api,close,onSaved}: {vehicle:Row;api:(path:string,method?:string,body?:Row)=>Promise<Row>;close:()=>void;onSaved:()=>Promise<void>}) {
  const [photos,setPhotos]=useState<Photo[]>(vehicle.ficha?.fotos??[]),[locations,setLocations]=useState<Row[]>([]);
  const [busy,setBusy]=useState(false),[error,setError]=useState('');
  const camera=useRef<HTMLInputElement>(null), gallery=useRef<HTMLInputElement>(null), replace=useRef<number|null>(null);
  useEffect(()=>{let live=true;api('/admin/locations').then(result=>{if(live)setLocations(result.locations);}).catch(e=>{if(live)setError(e.message);});return()=>{live=false;};},[]);
  async function upload(file?:File) {
    if(!file)return;
    const index=replace.current;replace.current=null;
    if(photos.length>=10&&index===null){setError('Puedes guardar hasta 10 fotos.');return;}
    setBusy(true);setError('');
    try {
      const jpg=await canvasPhoto(await imageCanvas(file,1600),'vehiculo.jpg');
      const response=await fetch('/api/v1/admin/fleet-photos',{method:'POST',headers:{'Content-Type':'image/jpeg'},body:jpg});
      const result=await response.json() as Row;if(!response.ok)throw new Error(result.error?.message||'No se pudo cargar la foto.');
      const next={url:result.data.url,alt:''};
      setPhotos(current=>index===null?[...current,next]:current.map((photo,i)=>i===index?next:photo));
    }catch(e){setError((e as Error).message);}finally{setBusy(false);}
  }
  function reorder(index:number,to:number){setPhotos(current=>{const next=[...current];[next[index],next[to]]=[next[to],next[index]];return next;});}
  async function save(e:FormEvent<HTMLFormElement>) {
    e.preventDefault();setBusy(true);setError('');
    const body=Object.fromEntries(new FormData(e.currentTarget));
    try {
      await api(vehicle.id?`/admin/vehicles/${vehicle.id}`:'/admin/vehicles',vehicle.id?'PATCH':'POST',{...body,publicado:body.publicado==='si',anio_verificado:body.anio_verificado==='on',fotos:photos});
      await onSaved();close();
    }catch(e){setError((e as Error).message);}finally{setBusy(false);}
  }
  async function remove() {
    if(!window.confirm(`¿Eliminar ${displayName(vehicle)} de la flota?`))return;
    setBusy(true);setError('');
    try{await api(`/admin/vehicles/${vehicle.id}`,'DELETE');await onSaved();close();}
    catch(e){setError((e as Error).message);}finally{setBusy(false);}
  }
  return <form className="vehicle-editor" onSubmit={save}>
    <div className="form-grid">{fields.map(([key,label,type='text'])=>{
      const value=vehicle[key]?.nombre??vehicle[key]??vehicle.ficha?.[key]??'';
      return <label key={key}>{label}<input name={key} type={type} defaultValue={value} required={['marca','modelo','categoria','anio','color'].includes(key)} step={['precio_dia','motor_litros'].includes(key)?'0.01':undefined} maxLength={key==='placa'?30:80}/></label>;
    })}
    <label>Ubicación<select name="ubicacion_actual_id" defaultValue={vehicle.ubicacion_actual_id??''}><option value="">Sin ubicación</option>{locations.map(l=><option key={l.id} value={l.id}>{l.nombre}{l.activo?'':' (inactivo)'}</option>)}</select></label>
    <label>Estado operativo<select name="estado_operativo" defaultValue={vehicle.estado_operativo??'disponible'}><option value="disponible">Disponible</option><option value="mantenimiento">En mantenimiento</option><option value="inactivo">Inactivo</option></select></label>
    <label>Publicar en catálogo<select name="publicado" defaultValue={vehicle.publicado===false?'no':'si'}><option value="si">Sí</option><option value="no">No</option></select></label>
    <label className="checkbox-label"><input type="checkbox" name="anio_verificado" defaultChecked={Boolean(vehicle.ficha?.anio_verificado)}/> Año verificado</label></div>
    <label>Descripción<textarea name="descripcion" defaultValue={vehicle.descripcion??''} maxLength={1200}/></label>
    <label>Observaciones<textarea name="observaciones" defaultValue={vehicle.ficha?.observaciones??''} maxLength={500}/></label>
    <h3>Fotos del vehículo</h3>
    <ul className="fleet-photo-list">{photos.map((photo,i)=><li key={`${photo.url}-${i}`}>
      <img src={photo.url} alt={photo.alt||`Foto ${i+1}`}/><div><strong>{i===0?'Foto principal':`Foto ${i+1}`}</strong><div className="control-row">
        <button type="button" disabled={busy||i===0} aria-label={`Subir foto ${i+1} en la lista`} onClick={()=>reorder(i,i-1)}><ArrowUp size={18}/></button>
        <button type="button" disabled={busy||i===photos.length-1} aria-label={`Bajar foto ${i+1} en la lista`} onClick={()=>reorder(i,i+1)}><ArrowDown size={18}/></button>
        <button type="button" disabled={busy} onClick={()=>{replace.current=i;gallery.current?.click();}}>Reemplazar</button>
        <button type="button" disabled={busy} aria-label={`Quitar foto ${i+1}`} onClick={()=>setPhotos(current=>current.filter((_,n)=>n!==i))}><Trash2 size={18}/></button>
      </div></div>
    </li>)}</ul>
    <input ref={gallery} type="file" hidden accept="image/jpeg,image/png,image/webp" onChange={e=>{void upload(e.target.files?.[0]);e.target.value='';}}/>
    <input ref={camera} type="file" hidden accept="image/*" capture="environment" onChange={e=>{void upload(e.target.files?.[0]);e.target.value='';}}/>
    <div className="control-row"><button type="button" className="button outline small" disabled={busy} onClick={()=>{replace.current=null;gallery.current?.click();}}><ImagePlus size={18}/> Agregar desde galería</button><button type="button" className="button outline small" disabled={busy} onClick={()=>{replace.current=null;camera.current?.click();}}><Camera size={18}/> Tomar foto</button></div>
    {error&&<p role="alert">{error}</p>}
    <div className="control-row"><button className="button gold" disabled={busy}>{busy?'Guardando…':'Guardar vehículo'}</button>{vehicle.id&&<button type="button" className="button outline" disabled={busy} onClick={remove}>Eliminar vehículo</button>}</div>
  </form>;
}
