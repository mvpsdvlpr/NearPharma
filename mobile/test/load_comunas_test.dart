import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/api_client.dart';
import 'package:http/http.dart' as http;

class _FakeClient implements http.Client {
  final Map<String, String> responses;
  _FakeClient(this.responses);

  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final b = body as Map<String, String>;
    final func = b['func'] ?? '';
    if (func == 'comunas') {
      final payload = '{"respuesta": [{"id": "1", "nombre": "Comuna A"}, {"id": "2", "nombre": "Comuna B"}]}';
      return http.Response(payload, 200);
    }
    return http.Response('{}', 200);
  }

  // Minimal unused methods implementations
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
  testWidgets('load comunas populates comunasMap', (WidgetTester tester) async {
    final client = _FakeClient({});
    final api = ApiClient(baseUrl: 'http://example.test', client: client);
    final widget = app.TipoFarmaciaScreen(apiClient: api, autoInit: false);
    await tester.pumpWidget(MaterialApp(home: widget));
    // Obtain the mounted state
    final state = tester.state<app.TipoFarmaciaScreenState>(find.byType(app.TipoFarmaciaScreen));
    // Call loadFiltros asynchronously
    await tester.runAsync(() async {
      await state.loadFiltros();
    });
  // Allow async work to complete: pump a few frames instead of pumpAndSettle to avoid timeout
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
    expect(state.comunasMap.isNotEmpty, true);
    expect(state.comunasMap['1'], 'Comuna A');
  });
}
