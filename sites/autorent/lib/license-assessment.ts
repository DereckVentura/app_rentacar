export type LicenseReading = {
  nombre?: string;
  vencimiento?: string;
  calidad?: 'oscura' | 'borrosa' | 'fuera_de_marco';
};

export function monthEnd(month: string) {
  if (!/^20\d{2}-(0[1-9]|1[0-2])$/.test(month)) return null;
  const [year, value] = month.split('-').map(Number);
  return new Date(Date.UTC(year, value, 0)).toISOString().slice(0, 10);
}

function normalized(value: string) {
  return value.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^\p{L}\s]/gu, '').trim().split(/\s+/).sort().join(' ');
}

export function assessLicense(read: LicenseReading, holder: string, expiration: string, today: string) {
  const nombre = typeof read?.nombre === 'string' ? read.nombre.trim().slice(0, 180) : '';
  const vencimiento = typeof read?.vencimiento === 'string' && monthEnd(read.vencimiento) ? read.vencimiento : '';
  const nombreCoincide = nombre ? normalized(nombre) === normalized(holder) : null;
  const fechaCoincide = vencimiento ? vencimiento === expiration.slice(0, 7) : null;
  const reason = expiration < today ? 'Licencia vencida'
    : read?.calidad === 'oscura' ? 'Foto muy oscura'
    : read?.calidad === 'borrosa' ? 'Foto borrosa'
    : read?.calidad === 'fuera_de_marco' ? 'Documento fuera de encuadre'
    : nombreCoincide === false ? 'El nombre del titular no coincide con la licencia'
    : fechaCoincide === false ? 'El mes y año de vencimiento no coinciden con la licencia' : null;
  return {nombre, vencimiento, nombreCoincide, fechaCoincide, motivo: reason,
    estado: reason ? 'rechazada' : nombreCoincide && fechaCoincide ? 'lista' : 'revision_manual'};
}
