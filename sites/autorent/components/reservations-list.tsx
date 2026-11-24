'use client';

import { useEffect, useState } from 'react';
import { CalendarDays, Copy, MapPin } from 'lucide-react';
import { PaymentDetails, ReservationCountdown } from './booking-settings';
import { bookingLabel, canReview, dateLabel, ReservationDecision } from './reservation-review';

type Row = Record<string, any>;
type Api = (path:string,method?:string,body?:Row)=>Promise<Row>;

export function ReservationsList({admin,api,onReview,onNotice,revision}: {admin:boolean;api:Api;onReview:(row:Row)=>void;onNotice:(message:string)=>void;revision:number}) {
  const [rows,setRows]=useState<Row[]>([]),[search,setSearch]=useState(''),[page,setPage]=useState(1),[pages,setPages]=useState(1);
  const [expired,setExpired]=useState(false);
  const [notices,setNotices]=useState<Row[]>([]);
  const [loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(''),[reload,setReload]=useState(0);
  const refresh=()=>setReload(n=>n+1);
  useEffect(()=>{
    if(admin)return;
    let live=true;
    api('/notifications').then(result=>{if(live)setNotices(result.notifications);}).catch(()=>{});
    return()=>{live=false;};
  },[admin,revision,reload]);
  useEffect(()=>{
    let live=true;
    async function fetchRows(){
      try{const result=await api(`/reservations?page=${page}&buscar=${encodeURIComponent(search)}&${expired?'estado=vencida':'vista=sin_vencidas'}`);if(live){setRows(result.reservations);setPages(result.pagination.totalPages);setError('');if(result.pagination.totalPages<page)setPage(result.pagination.totalPages);}}
      catch(e){if(live)setError((e as Error).message);}finally{if(live)setLoading(false);}
    }
    const debounce=setTimeout(fetchRows,search?200:0),timer=setInterval(fetchRows,15000);
    return()=>{live=false;clearTimeout(debounce);clearInterval(timer);};
  },[search,page,revision,reload,expired]);

  function showExpired(value:boolean) {
    if(value===expired)return;
    setExpired(value);setPage(1);setLoading(true);
  }

  async function action(r:Row, operation:'cancel'|'checkout'|'return') {
    let body:Row={};
    if(operation==='cancel') {if(!window.confirm(`¿Cancelar la reserva ${r.codigo}?`))return;}
    else {
      const km=window.prompt(`Kilometraje ${operation==='checkout'?'de salida':'de regreso'}`);
      if(km===null||!km.trim())return;
      body={kilometraje:Number(km),ubicacion_id:operation==='checkout'?r.pickup:r.dropoff,
        licencia_valida:operation==='checkout'&&r.documento?window.confirm('¿Confirmas que la licencia es válida?'):undefined};
    }
    setBusy(true);
    try{await api(`${operation==='cancel'?'':'/admin'}/reservations/${r.id}/${operation}`,'POST',body);refresh();onNotice('Reserva actualizada.');}
    catch(e){onNotice((e as Error).message);refresh();}finally{setBusy(false);}
  }
  return <section className="section interior">
    <h1 className="page-title">{admin?'Reservas y alquileres':'Mis reservas'}</h1>
    <div className="control-row" role="group" aria-label="Vista de reservas">
      <button type="button" className={`button ${expired?'outline':'gold'} small`} aria-pressed={!expired} onClick={()=>showExpired(false)}>Reservas</button>
      <button type="button" className={`button ${expired?'gold':'outline'} small`} aria-pressed={expired} onClick={()=>showExpired(true)}>Vencidas</button>
    </div>
    <label className="reservation-search">Buscar por {admin?'código o nombre del cliente':'código de reserva'}<input type="search" placeholder={admin?'Ej. AR-123 o María':'Ej. AR-123'} value={search} maxLength={120} onChange={e=>{setSearch(e.target.value);setPage(1);setLoading(true);}}/></label>
    {!admin&&notices.length>0&&<details><summary>Avisos de reservas ({notices.length})</summary><ul>{notices.map(notice=><li key={notice.id}><strong>{notice.codigo}</strong> · {notice.mensaje}</li>)}</ul></details>}
    {error&&<p role="alert">{error}</p>}
    {loading?<p role="status">Consultando reservas…</p>:rows.length===0&&!error?<div className="empty">{search?'No se encontraron reservas para esa búsqueda.':'Todavía no hay reservas.'}</div>:<div className="reservation-grid">{rows.map(r=><article className="reservation-card" key={r.id}>
      <div className="row-between"><span className={`status status-${r.estado}`}>{bookingLabel(r.estado)}</span><button type="button" className="text-button" onClick={async()=>{try{await navigator.clipboard.writeText(r.codigo);onNotice('Código copiado.');}catch{onNotice(r.codigo);}}}>{r.codigo}<Copy size={15}/></button></div>
      {admin&&<h2 className="reservation-customer">{r.cliente_nombre||'Cliente'}</h2>}
      <h3>{r.vehiculo_nombre} <small>{r.color}</small></h3>
      <h4 className="booked-days-title">Días reservados</h4>
      <div className="control-row booked-days"><span><CalendarDays size={16}/> {dateLabel(r.inicio_utc)}</span><span>{dateLabel(r.fin_utc)}</span></div>
      <p><MapPin size={16}/>{[r.entrega_nombre,r.devolucion_nombre].filter(Boolean).join(' → ')}</p>
      <div className="row-between"><b className="reservation-total">${r.total}</b><span>{r.unidades_cobradas} {r.unidades_cobradas===1?'día':'días'}</span></div>
      {r.review_note&&<p className="reservation-notice" role="status">{r.review_note}</p>}
      {r.vence_en&&<><ReservationCountdown deadline={r.vence_en} serverNow={r.servidor_utc} onExpire={refresh}/>{!admin&&<PaymentDetails api={api}/>}</>}
      <div className="control-row">
        {r.documento&&<button type="button" className="button outline small" onClick={()=>onReview(r)}>{admin?'Revisar licencia':'Ver mi licencia'}</button>}
        {['pendiente','lista_para_aprobar','confirmada'].includes(r.estado)&&<button type="button" className="button outline small" disabled={busy} onClick={()=>void action(r,'cancel')}>Cancelar reserva</button>}
      </div>
      {admin&&!r.documento&&canReview(r.estado)&&<ReservationDecision reservation={r} api={api} onSaved={async()=>{refresh();onNotice('Reserva actualizada.');}}/>}
      {admin&&['confirmada','en_curso'].includes(r.estado)&&<button type="button" className="button outline small" disabled={busy} onClick={()=>void action(r,r.estado==='confirmada'?'checkout':'return')}>{r.estado==='confirmada'?'Registrar entrega':'Registrar devolución'}</button>}
    </article>)}</div>}
    {pages>1&&<div className="control-row reservation-pages"><button type="button" className="button outline small" disabled={page<=1||loading} onClick={()=>{setLoading(true);setPage(page-1);}}>Anterior</button><span>Página {page} de {pages}</span><button type="button" className="button outline small" disabled={page>=pages||loading} onClick={()=>{setLoading(true);setPage(page+1);}}>Siguiente</button></div>}
  </section>;
}
