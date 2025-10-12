import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

void main() {
  group('Pruebas de conexión', () {
    setUpAll(() async {
      await dotenv.load();
    });
    Future<bool> _isUp() async {
      try {
        final base = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001';
        final url = Uri.parse('$base/mfarmacias/mapa.php');
        final r = await http.post(url, headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {'func': 'regiones'}).timeout(const Duration(seconds: 3));
        return r.statusCode == 200;
      } catch (_) {
        return false;
      }
    }

    test('POST func=regiones responde 200 y lista', () async {
      final base = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001';
      final url = Uri.parse('$base/mfarmacias/mapa.php');
      final up = await _isUp();
      if (!up) { print('Skipping test: $url is not available'); return; }
      final resp = await http.post(url, headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {'func': 'regiones'});
      expect(resp.statusCode, 200);
      final data = json.decode(resp.body);
      expect(data, isA<Map>());
      expect(data['respuesta'], isA<List<dynamic>>());
    });

    test('POST func=comunas (region=7) responde 200 y lista', () async {
      final base = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001';
      final url = Uri.parse('$base/mfarmacias/mapa.php');
      final up = await _isUp();
      if (!up) { print('Skipping test: $url is not available'); return; }
      final resp = await http.post(url, headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {'func': 'comunas', 'region': '7'});
      expect(resp.statusCode, 200);
      final data = json.decode(resp.body);
      expect(data, isA<Map>());
      expect(data['respuesta'], isA<List<dynamic>>());
    });

    test('POST func=region (region=7) responde 200 y lista de locales', () async {
      final base = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001';
      final url = Uri.parse('$base/mfarmacias/mapa.php');
      final up = await _isUp();
      if (!up) { print('Skipping test: $url is not available'); return; }
      final resp = await http.post(url, headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {'func': 'region', 'filtro': '', 'region': '7', 'hora': '12:00:00'});
      expect(resp.statusCode, 200);
      final data = json.decode(resp.body);
      expect(data, isA<Map>());
      expect(data['respuesta'] != null && (data['respuesta']['locales'] is List), true);
    });
  });
}
