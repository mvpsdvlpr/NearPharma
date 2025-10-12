import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client client;

  ApiClient({required this.baseUrl, http.Client? client}) : client = client ?? http.Client();

  Uri _mapUrl() => Uri.parse('$baseUrl/mfarmacias/mapa.php');

  Future<http.Response> postForm(Map<String, String> body) async {
    final url = _mapUrl();
    return client.post(url, headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: body);
  }

  void close() {
    try {
      client.close();
    } catch (_) {}
  }
}
