 
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
  // Convert respuesta map or list to list of {id,label}
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
