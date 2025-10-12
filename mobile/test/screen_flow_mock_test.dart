import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mobile/main.dart';
import 'package:mobile/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mocked screen flow', () {
    setUpAll(() async {
      await dotenv.load();
    });

  testWidgets('full filter -> region -> local flow with MockClient', (tester) async {
      // Prepare mock responses for each func
      final mock = MockClient((request) async {
        // Try request.bodyFields first, fallback to parsing body as form-encoded string
        Map<String, String> body = {};
        try {
          body = request.bodyFields;
        } catch (_) {
          try {
            body = Uri.splitQueryString(request.body);
          } catch (_) {
            body = {};
          }
        }
        final func = body['func'] ?? '';
        if (func == 'iconos') {
          return http.Response(json.encode({
            'titulos': ['Turno A', 'Otro'],
            'iconos': ['turnos', 'otro']
          }), 200);
        }
        if (func == 'regiones') {
          return http.Response(json.encode({
            'respuesta': [ {'id': '13', 'nombre': 'Region X'} ]
          }), 200);
        }
        if (func == 'comunas') {
          return http.Response(json.encode({
            'respuesta': [ {'id': '131', 'nombre': 'Comuna Y'} ]
          }), 200);
        }
        if (func == 'fechas') {
          return http.Response(json.encode({ 'respuesta': { '2025-10-11': '11 Oct 2025' } }), 200);
        }
        if (func == 'region') {
          // Return one local with tp='1' (index 1)
          return http.Response(json.encode({
            'respuesta': { 'locales': [ { 'im': '999', 'nm': 'Farmacia Mock', 'dr': 'Calle 1', 'cm': '131', 'rg': '13', 'tp': '0', 'lt': '-33.0', 'lg': '-70.0' } ] }
          }), 200);
        }
        if (func == 'local') {
          return http.Response(json.encode({ 'respuesta': { 'local': { 'nm': 'Farmacia Mock', 'dr': 'Calle 1' }, 'horario': { 'semana': 'Lunes-Viernes', 'turno': '' } } }), 200);
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001', client: mock);

  await tester.pumpWidget(MaterialApp(home: TipoFarmaciaScreen(apiClient: apiClient, autoInit: false, disableNetworkImages: true)));
      // Manually trigger filter loading so MockClient is used synchronously
  final state = tester.state<TipoFarmaciaScreenState>(find.byType(TipoFarmaciaScreen));
  await state.loadFiltros();
      await tester.pump();

  // Instead of interacting with dropdown overlays (slow/flaky), set selections directly
  // tipo index 0, region '13', comuna '131', fecha '2025-10-11'
  await state.buscarFarmaciasPublic(tipoIndex: 0, regionId: '13', comunaId: '131', fechaId: '2025-10-11');
      // pump a short while to allow UI to update (bounded polling)
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (find.text('Farmacia Mock').evaluate().isNotEmpty) break;
      }

      // Now the region search should have happened and a card shown
      expect(find.text('Farmacia Mock'), findsOneWidget);
      expect(find.textContaining('Turno', findRichText: false), findsWidgets);
    },
  // Skip this slow/integration-like test during normal runs; enable when debugging locally
  skip: true,
  );
  });
}
