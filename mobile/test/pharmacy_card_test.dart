import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mobile/widgets/pharmacy_card.dart';

void main() {
  testWidgets('PharmacyCard renders name, address and pill', (WidgetTester tester) async {
    final sample = {
      'nm': 'farmacia ejemplo',
      'dr': 'calle falsa 123',
      'cm': '1',
      'rg': '13',
      'tl': '12345678',
      'tp': '1',
      'img': ''
    };
    final horario = {'semana': 'Lunes a Viernes: 09:00 a 20:00<br>Domingo: Cerrado', 'dia': ''};
  await tester.pumpWidget(MaterialApp(home: Material(child: PharmacyCard(f: sample, horario: horario, comunasMap: {'1': 'ComunaX'}, regionesMap: {'13': 'RegionY'}, titulosTipos: ['Privada','Turno'], iconosTipos: ['privado','turnos'], disableNetworkImages: true))));

    expect(find.text('Farmacia Ejemplo'), findsOneWidget);
    expect(find.textContaining('Calle Falsa'), findsOneWidget);
    expect(find.text('Turno'), findsOneWidget);
  });
}
