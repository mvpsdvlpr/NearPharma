import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/api_client.dart';
import 'package:http/http.dart' as http;

class _FakeClientScenario implements http.Client {
  final int scenario;
  _FakeClientScenario(this.scenario);

  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final b = body as Map<String, String>;
    final func = b['func'] ?? '';
    // scenario 1: region-specific returns valid list
    if (scenario == 1) {
      if (func == 'comunas' && b['region'] != null) {
        final payload = json.encode({'respuesta': [{'id': '10', 'nombre': 'Comuna X', 'region': b['region']}]});
        return http.Response(payload, 200);
      }
      return http.Response('{}', 200);
    }
    // scenario 2: region-specific fails, global returns list
    if (scenario == 2) {
      if (func == 'comunas' && b['region'] != null) {
        return http.Response('Server error', 500);
      }
      if (func == 'comunas') {
        final payload = json.encode({'respuesta': [{'id': '20', 'nombre': 'Comuna Y', 'region': '5'}, {'id': '21', 'nombre': 'Comuna Z', 'region': '6'}]});
        return http.Response(payload, 200);
      }
    }
    return http.Response('{}', 200);
  }

  // unused methods
  @override
  void close() {}
  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) => Future.value(http.Response('', 200));
  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) => Future.value(http.Response('{}', 200));
  @override
  Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => Future.value(http.Response('{}', 200));
  @override
  Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => Future.value(http.Response('{}', 200));
  @override
  Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => Future.value(http.Response('{}', 200));
  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) => Future.value('{}');
  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) => Future.value(Uint8List(0));
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => Future.error(UnimplementedError());
}

void main() {
  testWidgets('load comunas by region succeeds (no fallback)', (WidgetTester tester) async {
    final client = _FakeClientScenario(1);
    final api = ApiClient(baseUrl: 'http://example.test', client: client);
    final widget = app.TipoFarmaciaScreen(apiClient: api, autoInit: false);
    await tester.pumpWidget(MaterialApp(home: widget));
    final state = tester.state<app.TipoFarmaciaScreenState>(find.byType(app.TipoFarmaciaScreen));
  await tester.runAsync(() async { await state.loadComunas('10'); });
    await tester.pump();
    expect(state.comunas.isNotEmpty, true);
    expect(state.comunasMap['10'] ?? state.comunasMap['10'.toString()], 'Comuna X');
  });

  testWidgets('load comunas fallback to global when region fails', (WidgetTester tester) async {
    final client = _FakeClientScenario(2);
    final api = ApiClient(baseUrl: 'http://example.test', client: client);
    final widget = app.TipoFarmaciaScreen(apiClient: api, autoInit: false);
    await tester.pumpWidget(MaterialApp(home: widget));
    final state = tester.state<app.TipoFarmaciaScreenState>(find.byType(app.TipoFarmaciaScreen));
  await tester.runAsync(() async { await state.loadComunas('5'); });
    await tester.pump();
    expect(state.comunas.isNotEmpty, true);
    // The global response contains an item with region '5' (id 20)
    expect(state.comunasMap['20'], 'Comuna Y');
  });
}
