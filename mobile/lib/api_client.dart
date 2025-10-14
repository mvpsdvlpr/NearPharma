import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client client;

  ApiClient({required this.baseUrl, http.Client? client}) : client = client ?? http.Client();

  Uri _mapUrl() => Uri.parse('$baseUrl/mfarmacias/mapa.php');

  /// Sends a form-encoded POST to the mapa endpoint and logs request/response details
  Future<http.Response> postForm(Map<String, String> body) async {
    final url = _mapUrl();
    final headers = {'Content-Type': 'application/x-www-form-urlencoded'};

    // Log request
    try {
      print('API Request -> POST ${url.toString()}');
      print('Headers: ${jsonEncode(headers)}');
      print('Body: ${jsonEncode(body)}');
    } catch (e) {
      // If logging fails, don't break execution
      print('API Request -> (failed to print request) $e');
    }

    try {
      final response = await client.post(url, headers: headers, body: body);

      // Log response
      try {
        final preview = response.body.length > 1000 ? response.body.substring(0, 1000) + '...[truncated]' : response.body;
        print('API Response <- ${response.statusCode} ${url.toString()}');
        print('Response body preview: ${preview}');
      } catch (e) {
        print('API Response <- (failed to print response) $e');
      }

      return response;
    } catch (e, st) {
      // Log error and rethrow so callers still see the exception
      print('API Error !! ${url.toString()} -> $e');
      print(st.toString());
      rethrow;
    }
  }

  void close() {
    try {
      client.close();
    } catch (_) {}
  }
}
