import { Pharmacy } from '../types/pharmacy';

export function isValidPharmacy(obj: any): obj is Pharmacy {
  return (
    typeof obj.local_id === 'string' &&
    typeof obj.local_nombre === 'string' &&
    typeof obj.comuna_nombre === 'string' &&
    typeof obj.local_direccion === 'string' &&
    typeof obj.local_telefono === 'string' &&
    typeof obj.local_lat === 'string' &&
    typeof obj.local_lng === 'string' &&
    typeof obj.local_tipo === 'string' &&
    typeof obj.funcionamiento_hora_apertura === 'string' &&
    typeof obj.funcionamiento_hora_cierre === 'string' &&
    typeof obj.fecha === 'string'
  );
}
