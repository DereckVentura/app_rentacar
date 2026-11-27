import { ApiError } from '../utils/api-error.js';

export function parseMileage(value: unknown): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0 || value > 999999) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'Ingresa un kilometraje entero de 0 a 999.999 km.');
  }
  return value;
}
