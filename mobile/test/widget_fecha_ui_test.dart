import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mobile/main.dart';

// This widget test pumps the real widget and simulates a user changing the
// Fecha dropdown using pumpWidget. We avoid network by calling buscarFarmaciasPublic
// with skipFetch=true where needed.

void main() {
  testWidgets('UI: al seleccionar fecha por dropdown se resetean filtros', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Access the state and inject example fechas so the Fecha dropdown is built.
    final tipoFinder = find.byType(TipoFarmaciaScreen);
    final state = tester.state<TipoFarmaciaScreenState>(tipoFinder);

    // Inject fechas so the dropdown is present in the widget tree.
    state.setState(() {
      state.fechas = [
        {'id': '20250101', 'label': '2025-01-01'},
        {'id': '20250102', 'label': '2025-01-02'},
      ];
    });
    await tester.pumpAndSettle();

  // Set an initial selection programmatically (skip network)
  await state.buscarFarmaciasPublic(tipoIndex: 0, regionId: '2', comunaId: '20', fechaId: '20250101', skipFetch: true);
    expect(state.regionSeleccionada, '2');
    expect(state.comunaSeleccionada, '20');

  // Now simulate user selecting a new fecha via the UI by calling the
  // extracted handler directly (avoids overlay interaction in tests)
  state.onFechaSelected('20250102');
  await tester.pump();

    expect(state.fechaSeleccionada, '20250102');
    expect(state.regionSeleccionada, isNull);
    expect(state.comunaSeleccionada, isNull);
    expect(state.farmacias, isEmpty);
  });
}
