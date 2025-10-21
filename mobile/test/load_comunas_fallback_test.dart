import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/api_client.dart';
import 'package:http/http.dart' as http;

class _FakeClient implements http.Client {
  final bool failRegionRequest;
  _FakeClient({this.failRegionRequest = false});

  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final b = body as Map<String, String>;
    final func = b['func'] ?? '';
    if (func == 'comunas' && b.containsKey('region')) {
      if (failRegionRequest) {
        return http.Response('Internal Error', 500);
      }
      final payload = json.encode({'respuesta': [{'id': '10', 'nombre': 'Comuna X', 'region': '7'}, {'id': '11', 'nombre': 'Comuna Y', 'region': '7'}]});
      return http.Response(payload, 200);
    }
    if (func == 'comunas') {
      // global list contains region info
      final payload = json.encode({'respuesta': [
        {'id': '10', 'nombre': 'Comuna X', 'region': '7'},
        {'id': '11', 'nombre': 'Comuna Y', 'region': '7'},
        {'id': '20', 'nombre': 'Comuna Z', 'region': '8'}
      ]});
      return http.Response(payload, 200);
    }
    return http.Response('{}', 200);
  }

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
  testWidgets('load comunas by region (normal)', (WidgetTester tester) async {
    final client = _FakeClient(failRegionRequest: false);
    final api = ApiClient(baseUrl: 'http://example.test', client: client);
    final widget = app.TipoFarmaciaScreen(apiClient: api, autoInit: false);
    await tester.pumpWidget(MaterialApp(home: widget));
    final state = tester.state<app.TipoFarmaciaScreenState>(find.byType(app.TipoFarmaciaScreen));
    await tester.runAsync(() async {
      await state.loadComunasForTest('7');
    });
    await tester.pump();
    expect(state.comunasMap.isNotEmpty, true);
    expect(state.comunasMap['10'], 'Comuna X');
  });

  testWidgets('fallback to global comunas when region request fails', (WidgetTester tester) async {
    final client = _FakeClient(failRegionRequest: true);
    final api = ApiClient(baseUrl: 'http://example.test', client: client);
    final widget = app.TipoFarmaciaScreen(apiClient: api, autoInit: false);
    await tester.pumpWidget(MaterialApp(home: widget));
    final state = tester.state<app.TipoFarmaciaScreenState>(find.byType(app.TipoFarmaciaScreen));
    await tester.runAsync(() async {
      await state.loadComunasForTest('7');
    });
    await tester.pump();
    // fallback should filter to region '7' entries
    expect(state.comunasMap.isNotEmpty, true);
    expect(state.comunasMap.containsKey('20'), false);
    expect(state.comunasMap['10'], 'Comuna X');
  });
}
