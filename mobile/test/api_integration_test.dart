import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

void main() {
  group('API integration tests (mapa.php)', () {
    setUpAll(() async {
      await dotenv.load();
    });

    String baseUrl() => dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001';

    test('POST func=iconos returns titulos and iconos', () async {
      final resp = await http.post(Uri.parse('${baseUrl()}/mfarmacias/mapa.php'), headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {'func': 'iconos'});
      expect(resp.statusCode, 200);
      final data = json.decode(resp.body);
      expect(data, isA<Map>());
      expect(data.containsKey('titulos') || (data['respuesta'] != null && data['respuesta'].containsKey('titulos')), true);
    });

    test('POST func=fechas returns respuesta map or list', () async {
      final resp = await http.post(Uri.parse('${baseUrl()}/mfarmacias/mapa.php'), headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {'func': 'fechas'});
      expect(resp.statusCode, 200);
      final data = json.decode(resp.body);
      expect(data, isA<Map>());
      expect(data.containsKey('respuesta'), true);
    });

    test('POST func=comunas returns respuesta list', () async {
      final resp = await http.post(Uri.parse('${baseUrl()}/mfarmacias/mapa.php'), headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {'func': 'comunas'});
      expect(resp.statusCode, 200);
      final data = json.decode(resp.body);
      expect(data, isA<Map>());
      expect(data['respuesta'], isA<List>());
    });

    test('POST func=regiones returns respuesta list', () async {
      final resp = await http.post(Uri.parse('${baseUrl()}/mfarmacias/mapa.php'), headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {'func': 'regiones'});
      expect(resp.statusCode, 200);
      final data = json.decode(resp.body);
      expect(data, isA<Map>());
      expect(data['respuesta'], isA<List>());
    });

    test('POST func=region (search) returns locales list when region provided', () async {
      final resp = await http.post(Uri.parse('${baseUrl()}/mfarmacias/mapa.php'), headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {'func': 'region', 'filtro': 'turnos', 'region': '13', 'hora': '12:00:00', 'fecha': '2025-10-11'});
      expect(resp.statusCode, 200);
      final data = json.decode(resp.body);
      expect(data, isA<Map>());
      expect(data['respuesta'] != null && data['respuesta']['locales'] != null, true);
    }, timeout: Timeout(Duration(seconds: 10)));

    test('POST func=local returns local and horario when sending lc-like payload', () async {
      // Use a known im from a previous run if available (fallback: 1673)
      final resp = await http.post(Uri.parse('${baseUrl()}/mfarmacias/mapa.php'), headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {'func': 'local', 'im': '1673'});
      expect(resp.statusCode, 200);
      final data = json.decode(resp.body);
      expect(data, isA<Map>());
      expect(data['respuesta'] != null && (data['respuesta']['local'] != null || data['respuesta']['horario'] != null), true);
    });
  });
}
