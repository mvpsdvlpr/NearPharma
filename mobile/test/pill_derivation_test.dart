import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/pill.dart';

void main() {
  test('derive urgency pill from explicit server fields', () {
    final Map<String, dynamic> f = <String, dynamic>{
      'nm': 'Farmacia U',
      'pill': 'Urgencia 24h',
      'pill_color': '#D32F2F',
    };
    final Map<String, dynamic> horario = <String, dynamic>{};
    final res = derivePillFromResponse(f, horario, false, '', 'urgencia');
    expect(res['text'], 'Urgencia 24h');
    // Color parsing: #D32F2F -> Color(0xFFD32F2F)
    expect(res['color'], equals(const Color(0xFFD32F2F)));
  });

  test('derive urgency fallback when filtroSeleccionado == urgencia', () {
    final Map<String, dynamic> f = <String, dynamic>{'nm': 'Farmacia V'};
    final Map<String, dynamic> horario = <String, dynamic>{};
    final res = derivePillFromResponse(f, horario, false, '', 'urgencia');
    expect(res['text'], 'Urgencia');
    // Default color for urgency should be the red shade we chose
    expect(res['color'], equals(Colors.red.shade600));
  });

  test('derive turno fallback when filtroSeleccionado == turnos', () {
    final Map<String, dynamic> f = <String, dynamic>{'nm': 'Farmacia T'};
    final Map<String, dynamic> horario = <String, dynamic>{};
    final res = derivePillFromResponse(f, horario, true, '', 'turnos');
    expect(res['text'], 'Turno');
    // Turno default is green shade
    expect(res['color'], equals(Colors.green.shade600));
  });

  test('derive pill from tp code: tp==3 -> Urgencia', () {
    final Map<String, dynamic> f = <String, dynamic>{'tp': '3', 'nm': 'Farmacia X'};
    final Map<String, dynamic> horario = <String, dynamic>{};
    final res = derivePillFromResponse(f, horario, false, '', '');
    expect(res['text'], 'Urgencia');
    expect(res['color'], equals(Colors.red.shade600));
  });

  test('derive pill from tp code: tp==1 -> Turno', () {
    final Map<String, dynamic> f = <String, dynamic>{'tp': '1', 'nm': 'Farmacia Y'};
    final Map<String, dynamic> horario = <String, dynamic>{};
    final res = derivePillFromResponse(f, horario, false, '', '');
    expect(res['text'], 'Turno');
    expect(res['color'], equals(Colors.green.shade600));
  });
}
