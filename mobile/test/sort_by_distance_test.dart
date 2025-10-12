import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart' as app;

void main() {
  test('sort by proximity orders nearest first', () {
    final helper = app.TipoFarmaciaScreenState();
    // Device at lat 0, lng 0
    final items = [
      {'id': 'a', 'lat': 1.0, 'lng': 1.0}, // ~157 km
      {'id': 'b', 'lat': 0.1, 'lng': 0.1}, // ~15.7 km
      {'id': 'c', 'lat': -0.5, 'lng': -0.5}, // ~78 km
    ];
  final sorted = helper.sortByProximity(items, 0.0, 0.0);
    final ids = sorted.map((e) => e['id']).toList();
    expect(ids, ['b', 'c', 'a']);
  });
}
