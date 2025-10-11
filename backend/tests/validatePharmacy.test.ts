import { isValidPharmacy } from '../src/utils/validatePharmacy';

describe('isValidPharmacy', () => {
  it('should return true for valid pharmacy object', () => {
    const obj = {
      local_id: '1',
      local_nombre: 'Farmacia X',
      comuna_nombre: 'Curicó',
      local_direccion: 'Calle 123',
      local_telefono: '123456',
      local_lat: '-34.98',
      local_lng: '-71.24',
      local_tipo: 'Farmacia',
      funcionamiento_hora_apertura: '09:00',
      funcionamiento_hora_cierre: '21:00',
      fecha: '2025-10-08',
    };
    expect(isValidPharmacy(obj)).toBe(true);
  });

  it('should return false for missing fields', () => {
    const obj = { local_id: '1' };
    expect(isValidPharmacy(obj)).toBe(false);
  });

  it('should return false for wrong types', () => {
    const obj = {
      local_id: 1,
      local_nombre: 2,
      comuna_nombre: 3,
      local_direccion: 4,
      local_telefono: 5,
      local_lat: 6,
      local_lng: 7,
      local_tipo: 8,
      funcionamiento_hora_apertura: 9,
      funcionamiento_hora_cierre: 10,
      fecha: 11,
    };
    expect(isValidPharmacy(obj)).toBe(false);
  });
});
