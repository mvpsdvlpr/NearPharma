import 'package:flutter/material.dart';

/// Derive pill text and color from server response maps. Public utility used
/// by UI and tests.
Map<String, dynamic> derivePillFromResponse(Map<String, dynamic> f, Map<String, dynamic> horario, bool globalTurno, String tipoNombre, String filtroActual) {
  String text = '';
  Color color = Colors.green.shade600;

  Color? parseColor(dynamic v) {
    if (v == null) {
      return null;
    }
    final s = v.toString().trim();
    if (s.startsWith('#')) {
      try {
        final hex = s.substring(1);
        final intVal = int.parse(hex, radix: 16);
        if (hex.length == 6) {
          return Color(0xFF000000 | intVal);
        }
        if (hex.length == 8) {
          return Color(intVal);
        }
      } catch (_) {}
    }
    final lower = s.toLowerCase();
    if (lower.contains('urg')) return Colors.red.shade600;
    if (lower.contains('turn')) return Colors.green.shade600;
    if (lower.contains('amar') || lower.contains('yell')) return Colors.amber.shade700;
    return null;
  }

  final candidates = [
    f['pill'], f['atencion'], f['tipo_nombre'], f['tipoNombre'], f['label'], horario['label'], horario['turno'],
    f['urgencia'], f['urgencia_label'], f['urgencia_text'], f['pill_urgencia'], horario['urgencia']
  ];

  for (final c in candidates) {
    try {
      if (c != null) {
        final s = c.toString().trim();
        if (s.isNotEmpty) {
          text = s;
          break;
        }
      }
    } catch (_) {}
  }

  final colorCandidates = [f['pill_color'], f['color'], f['tipo_color'], horario['color'], horario['pill_color']];
  for (final c in colorCandidates) {
    final p = parseColor(c);
    if (p != null) {
      color = p;
      break;
    }
  }

  // If explicit text/color were not provided, prefer the `tp` code when present
  final tpRaw = (f['tp'] ?? '').toString().trim();
  if ((text.isEmpty || text == '') ) {
    if (tpRaw == '1') {
      text = 'Turno';
    } else if (tpRaw == '3') {
      text = 'Urgencia';
    }
  }

  if ((color == Colors.green.shade600)) {
    if (tpRaw == '1') {
      color = Colors.green.shade600;
    } else if (tpRaw == '3') {
      color = Colors.red.shade600;
    }
  }

  if (text.isEmpty) {
    if (filtroActual == 'turnos' || globalTurno) {
      text = 'Turno';
    } else if (filtroActual == 'urgencia') {
      text = 'Urgencia';
    } else if (tipoNombre.isNotEmpty) {
      text = tipoNombre;
    } else {
      final tpRaw = f['tp']?.toString() ?? '';
      if (tpRaw.toLowerCase().contains('urg')) {
        text = 'Urgencia';
      }
    }
  }

  if (color == Colors.green.shade600) {
    final lower = text.toLowerCase();
    if (lower.contains('urg')) {
      color = Colors.red.shade600;
    } else if (lower.contains('turn')) {
      color = Colors.green.shade600;
    }
  }

  return {'text': text, 'color': color};
}
