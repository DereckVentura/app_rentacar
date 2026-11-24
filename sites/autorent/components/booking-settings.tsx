'use client';
import { useEffect, useRef, useState, type FormEvent } from 'react';

type Row = Record<string, any>;
type Api = (path:string,method?:string,body?:Row)=>Promise<Row>;

export function ReservationCountdown({deadline,serverNow,onExpire}: {deadline:string;serverNow:string;onExpire:()=>void}) {
  const [remaining,setRemaining]=useState(()=>Math.max(0,Date.parse(deadline)-Date.parse(serverNow)));
  const callback=useRef(onExpire);callback.current=onExpire;
  useEffect(()=>{
    const end=performance.now()+Math.max(0,Date.parse(deadline)-Date.parse(serverNow));
    let sent=false;
    const tick=()=>{const left=Math.max(0,end-performance.now());setRemaining(left);if(!left&&!sent){sent=true;callback.current();}};
    tick();const timer=setInterval(tick,1000);return()=>clearInterval(timer);
  },[deadline,serverNow]);
  const seconds=Math.ceil(remaining/1000);
  const clock=[Math.floor(seconds/3600),Math.floor(seconds/60)%60,seconds%60].map(n=>String(n).padStart(2,'0')).join(':');
  return <div className="booking-countdown" role="timer" aria-label="Tiempo restante para validar la reserva"><span>Pendiente de validación</span><strong>{clock}</strong><small>{seconds?'Tiempo para revisar la solicitud.':'Plazo vencido. Actualizando la reserva.'}</small></div>;
}

const paymentFields = [['banco','Banco',100],['titular','Titular de la cuenta',160],['numero_cuenta','Número de cuenta',80],['tipo_cuenta','Tipo de cuenta',80]] as const;

export function PaymentDetails({api}: {api:Api}) {
  const [payment,setPayment]=useState<Row|null>(null),[error,setError]=useState(''),[loaded,setLoaded]=useState(false);
  useEffect(()=>{let live=true;api('/payment-details').then(d=>{if(live){setPayment(d.payment);setLoaded(true);}}).catch(()=>{if(live)setError('No se pudieron cargar los datos de pago.');});return()=>{live=false;};},[]);
  return <div className="payment-details"><h3>Datos para el pago</h3>{error?<p role="alert">{error}</p>:payment?<><dl>{paymentFields.map(([key,label])=><div key={key}><dt>{label}</dt><dd>{payment[key]}</dd></div>)}</dl>{payment.instrucciones&&<p>{payment.instrucciones}</p>}</>:<p>{loaded?'La empresa todavía no ha agregado su cuenta de pago.':'Consultando datos de pago…'}</p>}</div>;
}

export function AdminSettings({api,onSaved}: {api:Api;onSaved:()=>Promise<void>}) {
  const [locations,setLocations]=useState<Row[]>([]),[payment,setPayment]=useState<Row|null>(null);
  const [minutes,setMinutes]=useState<number|null>(null),[editing,setEditing]=useState<Row|null>(null);
  const [message,setMessage]=useState(''),[busy,setBusy]=useState(false);
  const [expired,setExpired]=useState<Row[]|null>(null);
  async function refresh(){const [l,p,s]=await Promise.all([api('/admin/locations'),api('/payment-details'),api('/reservation-settings')]);setLocations(l.locations);setPayment(p.payment??{});setMinutes(s.minutos);}
  useEffect(()=>{refresh().catch(e=>setMessage(e.message));},[]);
  useEffect(()=>{
    let live=true;
    api('/admin/expired-reservations').then(result=>{if(live)setExpired(result.reservations);}).catch(()=>{});
    return()=>{live=false;};
  },[]);
  async function change(path:string,method:string,fields?:Row){
    setBusy(true);setMessage('');
    try{await api(path,method,fields);await refresh();await onSaved();setMessage('Cambios guardados.');return true;}
    catch(e){setMessage((e as Error).message);return false;}finally{setBusy(false);}
  }
  async function save(e:FormEvent<HTMLFormElement>,section:'location'|'payment'|'settings'){
    e.preventDefault();const fields=Object.fromEntries(new FormData(e.currentTarget));
    if(section==='location'){
      const path=editing?.id?`/admin/locations/${editing.id}`:'/admin/locations';
      if(await change(path,editing?.id?'PUT':'POST',{...fields,activo:fields.activo==='si'}))setEditing(null);
    }else await change(section==='payment'?'/admin/payment-details':'/admin/reservation-settings','PUT',fields);
  }
  return <div className="admin-settings">
    <section><h2>Plazo para validar</h2><p>El plazo nuevo se aplica a las próximas reservas.</p>
      {minutes!==null&&<form key={minutes} onSubmit={e=>void save(e,'settings')}><label>Minutos para validar una reserva<input name="minutos" defaultValue={minutes} type="number" min={1} max={1440} required/></label><button className="button gold small" disabled={busy}>Guardar plazo</button></form>}
    </section>
    {expired&&<section><details><summary>Reservas expiradas ({expired.length})</summary>{expired.map(row=><div className="admin-row" key={row.codigo}><div><h3>{row.codigo} · {row.cliente}</h3><p>{row.vehiculo} · {new Date(row.inicio).toLocaleDateString('es-SV',{timeZone:'America/El_Salvador'})} a {new Date(row.fin).toLocaleDateString('es-SV',{timeZone:'America/El_Salvador'})}</p></div></div>)}</details></section>}
    <section><h2>Datos de pago</h2>
      {payment&&<form key={JSON.stringify(payment)} onSubmit={e=>void save(e,'payment')}><div className="form-grid">{paymentFields.map(([key,label,max])=><label key={key}>{label}<input name={key} defaultValue={payment[key]} maxLength={max} required/></label>)}</div><label>Instrucciones de pago<textarea name="instrucciones" maxLength={1000} rows={3} defaultValue={payment.instrucciones||''}/></label><button className="button gold small" disabled={busy}>Guardar datos de pago</button></form>}
    </section>
    <section><h2>Puntos de entrega</h2>
      {locations.map(l=><div className="admin-row" key={l.id}><div><h3>{l.nombre}</h3><p>{l.direccion} · {l.activo?'Activo':'Inactivo'}</p></div><div className="control-row"><button type="button" className="button outline small" disabled={busy} onClick={()=>setEditing(l)}>Editar</button><button type="button" className="text-button" disabled={busy} onClick={async()=>{if(window.confirm(`¿Eliminar el punto ${l.nombre}?`)&&await change(`/admin/locations/${l.id}`,'DELETE')&&editing?.id===l.id)setEditing(null);}}>Eliminar</button></div></div>)}
      <button type="button" className="button outline small" onClick={()=>setEditing({tipo:'punto_autorizado',activo:true})}>Agregar punto</button>
      {editing&&<form key={editing.id||'new'} onSubmit={e=>void save(e,'location')}><div className="form-grid">
        <label>Nombre<input name="nombre" defaultValue={editing.nombre||''} maxLength={120} required/></label><label>Ciudad<input name="ciudad" defaultValue={editing.ciudad||''} maxLength={120}/></label>
        <label>Tipo<select name="tipo" defaultValue={editing.tipo}><option value="sucursal">Sucursal</option><option value="punto_autorizado">Punto autorizado</option></select></label>
        <label>Estado<select name="activo" defaultValue={editing.activo?'si':'no'}><option value="si">Activo</option><option value="no">Inactivo</option></select></label>
        <label>Latitud<input name="latitud" type="number" step="any" min="-90" max="90" defaultValue={editing.latitud??''} required/></label><label>Longitud<input name="longitud" type="number" step="any" min="-180" max="180" defaultValue={editing.longitud??''} required/></label>
      </div><label>Dirección<input name="direccion" defaultValue={editing.direccion||''} maxLength={300} required/></label><label>Indicaciones<textarea name="indicaciones" defaultValue={editing.indicaciones||''} maxLength={600}/></label><button className="button gold small" disabled={busy}>Guardar ubicación</button> <button type="button" className="text-button" disabled={busy} onClick={()=>setEditing(null)}>Cerrar edición</button></form>}
    </section>{message&&<p role="status">{message}</p>}
  </div>;
}
