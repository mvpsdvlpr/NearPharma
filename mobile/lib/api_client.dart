import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client client;

  ApiClient({required this.baseUrl, http.Client? client}) : client = client ?? http.Client();

  /// Conexión directa a mapa.php - Todas las funciones van al mismo endpoint
  Uri _getEndpointUrl(String func, Map<String, String> body) {
    // Todas las peticiones van a mapa.php con el parámetro func
    return Uri.parse('$baseUrl/mapa.php');
  }

  /// La API de MINSAL usa form-urlencoded, no JSON
  bool _shouldUseJson(String func, Map<String, String> body) {
    // La API original usa application/x-www-form-urlencoded
    return false;
  }

  /// Conexión directa - No se necesita conversión, enviamos los parámetros tal cual
  Map<String, dynamic> _convertToApiFormat(Map<String, String> body) {
    // La API de MINSAL espera los mismos parámetros que enviamos
    // func=fechas, func=iconos, func=regiones, func=comunas&region=X, etc.
    return body;
  }

  /// Sends requests to correct API endpoints with proper formatting
  Future<http.Response> postForm(Map<String, String> body) async {
    final func = body['func'] ?? '';
    final url = _getEndpointUrl(func, body);
    final useJson = _shouldUseJson(func, body);
    
    Map<String, String> headers;
    dynamic requestBody;
    
    if (useJson) {
      headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final apiData = _convertToApiFormat(body);
      requestBody = jsonEncode(apiData);
    } else {
      headers = {'Content-Type': 'application/x-www-form-urlencoded'};
      requestBody = body;
    }

    return await client.post(url, headers: headers, body: requestBody);
  }

  void close() {
    client.close();
  }
}
