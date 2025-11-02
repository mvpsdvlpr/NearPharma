import 'dart:convert';

import 'package:http/http.dart' as http;
import 'src/logger.dart';

class ApiClient {
  final String baseUrl;
  final http.Client client;

  ApiClient({required this.baseUrl, http.Client? client}) : client = client ?? http.Client();

  /// Maps func parameters to V2 REST API endpoints
  Uri _getEndpointUrl(String func, Map<String, String> body) {
    switch (func) {
      case 'iconos':
        // POST /api/v2/pharmacy-types - Get pharmacy types
        return Uri.parse('$baseUrl/api/v2/pharmacy-types');
      case 'fechas':
        // POST /api/v2/turn-dates - Get available turn dates
        return Uri.parse('$baseUrl/api/v2/turn-dates');
      case 'regiones':
        // POST /api/v2/regions - Get all regions
        return Uri.parse('$baseUrl/api/v2/regions');
      case 'comunas':
        // POST /api/v2/regions/{regionId}/communes - Get communes by region
        final regionId = body['region'] ?? '';
        if (regionId.isEmpty) {
          throw Exception('region parameter required for comunas endpoint');
        }
        return Uri.parse('$baseUrl/api/v2/regions/$regionId/communes');
      case 'region':
      case 'local':
        // POST /api/v2/pharmacies/search - Search pharmacies
        return Uri.parse('$baseUrl/api/v2/pharmacies/search');
      default:
        // Fallback to search endpoint
        return Uri.parse('$baseUrl/api/v2/pharmacies/search');
    }
  }

  /// All V2 endpoints use JSON
  bool _shouldUseJson(String func, Map<String, String> body) {
    // V2 API always uses JSON
    return true;
  }

  /// Converts func-based parameters to V2 REST API format
  Map<String, dynamic> _convertToApiFormat(Map<String, String> body) {
    final func = body['func'] ?? '';
    final result = <String, dynamic>{};
    
    switch (func) {
      case 'iconos':
        // POST /api/v2/pharmacy-types - No parameters required
        // Returns: [{"id": "1", "name": "Turno", "icon": "turnos"}, ...]
        break;
        
      case 'fechas':
        // POST /api/v2/turn-dates - No parameters required
        // Returns: {"2025-11-01": "Sábado 01 de Noviembre", ...}
        break;
        
      case 'regiones':
        // POST /api/v2/regions - No parameters required
        // Returns: [{"id": "1", "nombre": "Tarapacá", ...}, ...]
        break;
        
      case 'comunas':
        // POST /api/v2/regions/{regionId}/communes
        // Region ID is in the URL path, no body parameters needed
        // The regionId is extracted in _getEndpointUrl
        break;
        
      case 'region':
      case 'local':
        // POST /api/v2/pharmacies/search
        // Body: { filter, date?, regionId?, communeId? }
        
        // Map 'filtro' to 'filter' (V2 uses 'filter')
        if (body.containsKey('filtro')) {
          result['filter'] = body['filtro'];
        }
        
        // Map 'region' to 'regionId' (as string)
        if (body.containsKey('region')) {
          result['regionId'] = body['region']!.toString();
        }
        
        // Map 'comuna' to 'communeId' (as string)
        if (body.containsKey('comuna')) {
          result['communeId'] = body['comuna']!.toString();
        }
        
        // Map 'fecha' to 'date'
        if (body.containsKey('fecha')) {
          result['date'] = body['fecha'];
        }
        
        // Pass through pharmacy ID for specific pharmacy requests
        if (body.containsKey('im')) {
          result['pharmacyId'] = body['im'];
        }
        
        break;
        
      default:
        // Unknown func - return empty body
        break;
    }
    
    return result;
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

    // Log request
    try {
      AppLogger.i('API Request -> POST ${url.toString()}');
      AppLogger.d('Headers: ${jsonEncode(AppLogger.maskMap(headers))}');
      AppLogger.d('Body: ${useJson ? requestBody : jsonEncode(AppLogger.maskMap(body))}');
    } catch (e, st) {
      // If logging fails, don't break execution
      AppLogger.e('API Request -> (failed to print request) $e', e, st);
    }

    try {
      final response = await client.post(url, headers: headers, body: requestBody);

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
    } catch (e, st) {
      AppLogger.d('ApiClient.close failed', e, st);
    }
  }
}
