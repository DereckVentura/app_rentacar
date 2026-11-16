import { ApiError } from '../utils/api-error.js';
export function parsePayment(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new ApiError(400, 'VALIDATION_ERROR', 'Revisa los datos de pago.');
  const body = value as Record<string, unknown>;
  const limits = { banco: 100, titular: 160, numero_cuenta: 80, tipo_cuenta: 80, instrucciones: 1000 };
  if (Object.keys(body).some(k => !(k in limits))) throw new ApiError(400, 'VALIDATION_ERROR', 'Revisa los campos de pago.');
  return Object.fromEntries(Object.entries(limits).map(([key, max]) => {
    const text = body[key] ?? (key === 'instrucciones' ? '' : null);
    if (typeof text !== 'string' || text.trim().length > max || (key !== 'instrucciones' && !text.trim()) || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(text)) throw new ApiError(400, 'VALIDATION_ERROR', `Revisa ${key}.`);
    return [key, text.trim()];
  }));
}
