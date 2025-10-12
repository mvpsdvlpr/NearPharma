import 'package:flutter_test/flutter_test.dart';

String stripHtml(String? s) {
  if (s == null) return '';
  String withBreaks = s.replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n');
  String without = withBreaks.replaceAll(RegExp(r'<[^>]*>'), '');
  without = without.replaceAll(RegExp(r'[ \t]+'), ' ');
  without = without.replaceAll(RegExp(r'\n{2,}'), '\n');
  final lines = without.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  return lines.join('\n');
}

List<Map<String, String>> parseFechas(dynamic resp) {
  if (resp == null) return [];
  if (resp is List) {
    return resp.map((e) {
      if (e is Map && e.containsKey('id') && e.containsKey('label')) {
        return {'id': e['id'].toString(), 'label': e['label'].toString()};
      }
      return {'id': e.toString(), 'label': e.toString()};
    }).toList();
  }
  if (resp is Map) {
    final entries = resp.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => {'id': e.key.toString(), 'label': e.value.toString()}).toList();
  }
  return [];
}

void main() {
  group('Helpers', () {
    test('stripHtml removes tags and converts <br> to newline', () {
      final html = 'Lunes - Sábado: 09:00 a 21:00 hrs.<br>Domingo: Cerrado<br>';
      final result = stripHtml(html);
      expect(result.contains('<'), false);
      expect(result.contains('Domingo'), true);
      expect(result.split('\n').length, greaterThanOrEqualTo(2));
    });

    test('parseFechas converts map to sorted list of id/label', () {
      final input = {
        '2025-10-11': 'Sábado 11 de Octubre',
        '2025-10-12': 'Domingo 12 de Octubre',
        '2025-10-13': 'Lunes 13 de Octubre'
      };
      final out = parseFechas(input);
      expect(out.length, 3);
      expect(out[0]['id'], '2025-10-11');
      expect(out[0]['label'], 'Sábado 11 de Octubre');
    });
  });
}
