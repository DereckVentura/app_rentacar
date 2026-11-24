'use client';
import { FormEvent, useState } from 'react';

type Row = Record<string, any>;
const labels:Record<string,string> = {
  pendiente:'Pendiente',lista_para_aprobar:'Lista para aprobar',confirmada:'Confirmada',
  en_curso:'En curso',completada:'Alquiler finalizado',denegada:'Denegada',denegada_automatica:'Denegada automáticamente',
  vencida:'Expirada',cancelada:'Cancelada',
};
export const bookingLabel = (value:string) => labels[value] ?? value.replaceAll('_',' ');
export const canReview = (value:string) => ['pendiente','lista_para_aprobar','denegada_automatica'].includes(value);
export const dateLabel = (value:string) => new Intl.DateTimeFormat('es-SV',{dateStyle:'medium',timeZone:'America/El_Salvador'}).format(new Date(value));

export function ReservationDecision({reservation,api,onSaved}: {reservation:Row;api:(p:string,m?:string,b?:Row)=>Promise<Row>;onSaved:()=>Promise<void>}) {
  const [denying,setDenying]=useState(false),[reason,setReason]=useState(''),[working,setWorking]=useState(false),[error,setError]=useState('');
  async function save(deny:boolean,e?:FormEvent<HTMLFormElement>) {
    e?.preventDefault();
    if(deny&&!reason.trim()){setError('Escribe el motivo de la denegación.');return;}
    setWorking(true);setError('');
    try{await api(`/admin/reservations/${reservation.id}/${deny?'deny':'validate'}`,'POST',deny?{motivo:reason.trim()}:{});await onSaved();}
    catch(e){setError((e as Error).message);}finally{setWorking(false);}
  }
  if(!canReview(reservation.estado))return null;
  return <div className="reservation-decision">
    <div className="control-row">
      <button type="button" className="button gold small" disabled={working} onClick={()=>void save(false)}>Completar reserva</button>
      <button type="button" className="button outline danger small" disabled={working} onClick={()=>setDenying(!denying)} aria-expanded={denying}>Denegar reserva</button>
    </div>
    {denying&&<form className="deny-reservation" onSubmit={e=>void save(true,e)}>
      <div className="control-row">{['Documento inválido','Licencia vencida','Foto borrosa'].map(preset=><button type="button" key={preset} className="button outline small" onClick={()=>setReason(preset)}>{preset}</button>)}</div>
      <label>Motivo de denegación<textarea autoFocus rows={3} maxLength={400} value={reason} onChange={e=>setReason(e.target.value)} required/></label>
      <button className="button outline danger small" disabled={working}>Confirmar denegación</button>
    </form>}
    {error&&<p role="alert">{error}</p>}
  </div>;
}
