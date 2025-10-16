import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/filter_utils.dart';

void main() {
  test('resetFiltersForFechaChange clears region, comuna and results', () {
    final current = {
      'regionSeleccionada': '5',
      'comunaSeleccionada': '51',
      'comunas': [{'id': '51'}],
      'farmacias': [{'id': '100'}],
      'error': 'some error'
    };

    final res = resetFiltersForFechaChange(current);
    expect(res['regionSeleccionada'], isNull);
    expect(res['comunaSeleccionada'], isNull);
    expect(res['comunas'], isEmpty);
    expect(res['farmacias'], isEmpty);
    expect(res['error'], isNull);
  });
}
