import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Cambiar fecha limpia region y comuna y borra resultados', (WidgetTester tester) async {
    // Pump the app
    await tester.pumpWidget(const MyApp());

    // Find the TipoFarmaciaScreen
    final tipoFinder = find.byType(TipoFarmaciaScreen);
    expect(tipoFinder, findsOneWidget);

    // Access the state
    final state = tester.state<TipoFarmaciaScreenState>(tipoFinder);

    // Seed some values
  await state.buscarFarmaciasPublic(tipoIndex: 0, regionId: '1', comunaId: '10', fechaId: '20250101', skipFetch: true);

    expect(state.regionSeleccionada, '1');
    expect(state.comunaSeleccionada, '10');
    // Simulate user changing fecha only
  await state.buscarFarmaciasPublic(fechaId: '20250102', skipFetch: true);

    // After fecha-only change, region and comuna should be cleared
    expect(state.regionSeleccionada, isNull);
    expect(state.comunaSeleccionada, isNull);
    expect(state.farmacias, isEmpty);
  });
}
