export class BookingError extends Error {
 constructor(public status:number,message:string,public code='VALIDATION_ERROR'){super(message);}
}
export const DAY=86400000,DEPOSIT_WINDOW=3*3600000;
export const iso=(time:number)=>new Date(time).toISOString();
export const svDay=(time=Date.now())=>new Date(time-6*3600000).toISOString().slice(0,10);
export function validDay(value:unknown):value is string {
 return typeof value==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(value)&&Number.isFinite(Date.parse(value))&&new Date(value+'T00:00:00Z').toISOString().slice(0,10)===value;
}
export const dayStart=(day:string)=>Date.parse(day+'T06:00:00.000Z');
export function selectedDates(value:unknown,now=Date.now()):string[]{
 if(!Array.isArray(value)||!value.length||value.length>90||!value.every(validDay))throw new BookingError(400,'Selecciona entre 1 y 90 días válidos en el calendario.','DATES_REQUIRED');
 const days=[...new Set(value as string[])].sort();
 if(days.length!==value.length)throw new BookingError(400,'No repitas fechas.');
 if(days[0]<=svDay(now)||days.at(-1)!>svDay(now+365*DAY))throw new BookingError(400,'Selecciona días desde mañana y dentro de los próximos 12 meses.');
 return days;
}
export function cents(value:unknown):number {
 if(typeof value!=='string'&&typeof value!=='number')throw new BookingError(400,'Introduce un importe válido.');
 const text=String(value);if(!/^\d{1,8}(\.\d{1,2})?$/.test(text))throw new BookingError(400,'Introduce un importe con un máximo de dos decimales.');
 const [whole,decimal='']=text.split('.');return Number(whole)*100+Number(decimal.padEnd(2,'0'));
}
export const amount=(n:number)=>(n/100).toFixed(2);
export const deposit=(total:number)=>Math.ceil(total/2);
export function activeSql(alias='r'){
 return `(${alias}.estado IN ('confirmada','en_curso') OR (${alias}.estado='pendiente_deposito' AND ${alias}.deposit_due_at>?) OR (${alias}.estado='en_revision' AND ${alias}.receipt_submitted_at IS NOT NULL AND ${alias}.receipt_submitted_at<=${alias}.deposit_due_at))`;
}
// One conditional insert makes availability and reservation creation indivisible in D1.
export function conflictSql(alias='r'){
 return `(EXISTS(SELECT 1 FROM json_each(?) requested JOIN json_each(COALESCE(${alias}.selected_dates,'[]')) booked ON requested.value=booked.value) OR (json_array_length(COALESCE(${alias}.selected_dates,'[]'))=0 AND EXISTS(SELECT 1 FROM json_each(?) requested WHERE julianday(${alias}.inicio)<julianday(requested.value,'+1 day','+6 hours') AND julianday(${alias}.fin)>julianday(requested.value,'+6 hours'))))`;
}
export function occupiedOn(r:Record<string,any>,day:string):boolean{
 const dates=JSON.parse(r.selected_dates||'[]') as string[];
 return dates.length?dates.includes(day):Date.parse(r.inicio)<dayStart(day)+DAY&&Date.parse(r.fin)>dayStart(day);
}
