import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart' as app;

void main() {
  test('comma decimal and string coordinates parse and sort', () {
    final helper = app.TipoFarmaciaScreenState();
    final items = [
      {'id': 'a', 'lt': '-33,0', 'lg': '-70,0'},
      {'id': 'b', 'lt': '-33,5', 'lg': '-70,5'},
      {'id': 'c', 'lt': '-34,0', 'lg': '-71,0'},
    ];
    final sorted = helper.sortByProximity(items, -33.25, -70.25);
    final ids = sorted.map((e) => e['id']).toList();
    // b (~35 km) is closest, then a, then c
    expect(ids, ['b', 'a', 'c']);
  });

  test('missing or non-numeric coordinates go to the end', () {
    final helper = app.TipoFarmaciaScreenState();
    final items = [
      {'id': 'a', 'lat': 1.0, 'lng': 1.0},
      {'id': 'b', 'lat': null, 'lng': null},
      {'id': 'c', 'lat': 'foo', 'lng': 'bar'},
    ];
    final sorted = helper.sortByProximity(items, 0.0, 0.0);
    final ids = sorted.map((e) => e['id']).toList();
    expect(ids.first, 'a');
    expect(ids.contains('b'), true);
    expect(ids.contains('c'), true);
    // Ensure that valid item is first
    expect(ids.indexOf('a') < ids.indexOf('b'), true);
    expect(ids.indexOf('a') < ids.indexOf('c'), true);
  });

  test('strings with extra characters parse correctly', () {
    final helper = app.TipoFarmaciaScreenState();
    final items = [
      {'id': 'a', 'lt': ' -33.123° ', 'lg': ' -70.456° '},
      {'id': 'b', 'lt': '-33.5', 'lg': '-70.5'},
    ];
    final sorted = helper.sortByProximity(items, -33.2, -70.3);
    final ids = sorted.map((e) => e['id']).toList();
    expect(ids.first, 'a');
  });
}
