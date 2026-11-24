type Row = Record<string, any>;
export class FleetError extends Error {
  constructor(public status: number, message: string, public code = 'FLEET_ERROR') { super(message); }
}

const cleaned = (value: unknown, max: number) => typeof value === 'string' ? value.trim().slice(0, max) : '';
const number = (value: unknown, min: number, max: number) => {
  const parsed = value === '' || value == null ? NaN : Number(value);
  return Number.isFinite(parsed) && parsed >= min && parsed <= max ? parsed : null;
};
const labelId = (label: string) => {
  let id = 0;
  for (const char of label.trim().toLowerCase()) id = (Math.imul(31, id) + char.charCodeAt(0)) >>> 0;
  return id + 100;
};
function named(value: unknown, previous: Row | undefined, label: string) {
  if (value === undefined || typeof value === 'object') return previous;
  const nombre = cleaned(value, 80);
  if (!nombre) throw new FleetError(400, `Indica ${label}.`);
  return {id: previous?.nombre === nombre ? previous.id : labelId(nombre), nombre};
}

export function editVehicle(body: Row, previous: Row, locations: Row[], categories: Row[]) {
  const details = body.ficha && typeof body.ficha === 'object' ? body.ficha : {};
  const marca = named(body.marca, previous.marca, 'la marca');
  const modelo = named(body.modelo, previous.modelo, 'el modelo');
  const storedCategory = body.categoria_id ? categories.find(c=>c.id===Number(body.categoria_id)) : previous.categoria;
  const categoria = named(body.categoria, storedCategory, 'el tipo de vehículo');
  const anio = number(body.anio ?? previous.anio, 1900, new Date().getFullYear() + 2);
  if (!marca || !modelo || !categoria || !anio || !Number.isInteger(anio)) throw new FleetError(400, 'Completa la marca, modelo, tipo y año.');
  const rawPrice = body.precio_dia === undefined ? previous.precio_dia : body.precio_dia;
  const price = number(rawPrice, 0.01, 99999);
  if (rawPrice != null && rawPrice !== '' && price === null) throw new FleetError(400, 'Ingresa una tarifa diaria válida.');
  const locationId = number(body.ubicacion_actual_id === undefined ? previous.ubicacion_actual_id : body.ubicacion_actual_id, 1, Number.MAX_SAFE_INTEGER);
  const ubicacion = locations.find(location => location.id === locationId && location.activo);
  const operationalStatus = body.estado_operativo ?? previous.estado_operativo ?? 'disponible';
  const estado = operationalStatus==='operativo'?'disponible':operationalStatus;
  if (!['disponible', 'mantenimiento', 'inactivo'].includes(estado)) throw new FleetError(400, 'Selecciona un estado válido.');
  const posted = typeof body.publicado === 'boolean' ? body.publicado : previous.publicado !== false;
  const placa = cleaned(body.placa === undefined ? previous.placa : body.placa, 30);
  const ficha = {...(previous.ficha ?? {}), referencias: previous.ficha?.referencias ?? []};
  for (const key of ['color', 'traccion', 'version', 'transmision', 'combustible', 'observaciones']) {
    const value=body[key]===undefined?details[key]:body[key];
    if (value !== undefined) ficha[key] = cleaned(value, key === 'observaciones' ? 500 : 80);
  }
  for (const [key, max] of [['plazas', 100], ['motor_litros', 50], ['potencia_hp', 3000]] as const) {
    const value=body[key]===undefined?details[key]:body[key];
    if (value !== undefined) ficha[key] = number(value, 0, max);
  }
  const verified=body.anio_verificado ?? details.anio_verificado;
  if (typeof verified === 'boolean') ficha.anio_verificado = verified;
  if (Array.isArray(details.referencias)) ficha.referencias = details.referencias.slice(0,5).map((ref:Row)=>({titulo:cleaned(ref?.titulo,150),url:cleaned(ref?.url,700),mercado:cleaned(ref?.mercado,150),resumen:cleaned(ref?.resumen,700)})).filter((ref:Row)=>/^https:\/\//.test(ref.url));
  const photos=body.fotos ?? details.fotos ?? ficha.fotos ?? [];
  if (!Array.isArray(photos) || photos.length > 12) throw new FleetError(400, 'Adjunta hasta 12 fotos por vehículo.');
  ficha.fotos = photos.map((photo: Row) => {
    const url = cleaned(photo?.url, 700);
    if (!/^\/vehicles\/[\w.-]+$|^\/api\/v1\/fleet-(?:photos|images)\/[0-9a-f-]{36}$|^https:\/\//.test(url)) throw new FleetError(400, 'La foto debe tener un enlace HTTPS o cargarse desde la galería.');
    return {url, alt: cleaned(photo.alt, 150) || `${marca.nombre} ${modelo.nombre}`};
  });
  return {...previous, marca, modelo, categoria, categoria_id:categoria.id, anio, placa, ficha,
    kilometraje: number(body.kilometraje === undefined ? previous.kilometraje : body.kilometraje, 0, 9999999),
    descripcion: cleaned(body.descripcion === undefined ? previous.descripcion : body.descripcion, 1200),
    precio_dia: price?.toFixed(2) ?? null, publicado: posted, estado_operativo: estado,
    disponible: estado === 'disponible', activo: estado !== 'inactivo',
    ubicacion_actual_id: locationId, imagen_url: ficha.fotos[0]?.url ?? null,
    reservable: !!(price && posted && estado === 'disponible' && placa && ubicacion),
  };
}

export async function saveCatalogRow(db: D1Database, table: 'vehicles' | 'locations', id: number | null, data: Row) {
  if (id !== null) {
    const result = await db.prepare(`UPDATE ${table} SET data=json_set(?, '$.id', id) WHERE id=? AND json_extract(data,'$.eliminado') IS NOT 1 RETURNING data`).bind(JSON.stringify(data), id).first<{data:string}>();
    if (!result) throw new FleetError(404, 'El registro ya no está disponible.');
    return JSON.parse(result.data);
  }
  const result = await db.prepare(`INSERT INTO ${table}(id,data) SELECT next_id,json_set(?, '$.id', next_id) FROM (SELECT COALESCE(MAX(id),0)+1 AS next_id FROM ${table}) RETURNING data`).bind(JSON.stringify(data)).first<{data:string}>();
  return JSON.parse(result!.data);
}
