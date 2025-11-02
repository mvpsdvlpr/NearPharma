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

  // Priorizar el campo 'tp' de la API MINSAL
  final tpRaw = (f['tp'] ?? '').toString().trim();
  if (tpRaw == '1') {
    text = 'Turno';
    color = Colors.green.shade600;
  } else if (tpRaw == '3') {
    text = 'Urgencia';
    color = Colors.red.shade600;
  }
  
  // Solo si no hay 'tp', buscar en otros campos (excluyendo horario['turno'] que es la fecha)
  if (text.isEmpty) {
    final candidates = [
      f['pill'], f['atencion'], f['tipo_nombre'], f['tipoNombre'], f['label'], horario['label'],
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
  }

  // Si no se definió color aún, buscar en campos de color
  if (color == Colors.green.shade600 && text.isEmpty) {
    final colorCandidates = [f['pill_color'], f['color'], f['tipo_color'], horario['color'], horario['pill_color']];
    for (final c in colorCandidates) {
      final p = parseColor(c);
      if (p != null) {
        color = p;
        break;
      }
    }
  }

  // Fallback: si aún no hay texto, usar filtro o tipo
  if (text.isEmpty) {
    if (filtroActual == 'turnos' || globalTurno) {
      text = 'Turno';
      color = Colors.green.shade600;
    } else if (filtroActual == 'urgencia') {
      text = 'Urgencia';
      color = Colors.red.shade600;
    } else if (tipoNombre.isNotEmpty) {
      text = tipoNombre;
    }
  }

  return {'text': text, 'color': color};
}
