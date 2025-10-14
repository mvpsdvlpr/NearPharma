import 'dart:convert';

import 'package:http/http.dart' as http;
import 'src/logger.dart';

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
      AppLogger.i('API Request -> POST ${url.toString()}');
      AppLogger.d('Headers: ${jsonEncode(AppLogger.maskMap(headers))}');
      AppLogger.d('Body: ${jsonEncode(AppLogger.maskMap(body))}');
    } catch (e, st) {
      // If logging fails, don't break execution
      AppLogger.e('API Request -> (failed to print request) $e', e, st);
    }

    try {
      final response = await client.post(url, headers: headers, body: body);

      // Log response
      try {
        final preview = response.body.length > 1000 ? response.body.substring(0, 1000) + '...[truncated]' : response.body;
        AppLogger.i('API Response <- ${response.statusCode} ${url.toString()}');
        AppLogger.d('Response body preview: ${preview}');
      } catch (e, st) {
        AppLogger.e('API Response <- (failed to print response) $e', e, st);
      }

      return response;
    } catch (e, st) {
      // Log error and rethrow so callers still see the exception
      AppLogger.e('API Error !! ${url.toString()} -> $e', e, st);
      rethrow;
    }
  }

  void close() {
    try {
      client.close();
    } catch (_) {}
  }
}
