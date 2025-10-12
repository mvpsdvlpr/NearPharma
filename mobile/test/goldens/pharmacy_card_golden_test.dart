import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mobile/widgets/pharmacy_card.dart';

void main() {
  testWidgets('PharmacyCard golden', (WidgetTester tester) async {
    final sample = {
      'nm': 'Farmacia El Progreso con un nombre muy largo para probar el truncado',
      'dr': 'Av. Principal 1234, Sector de pruebas con dirección extensa',
      'cm': '1',
      'rg': '13',
      'tl': '+56 9 1234 5678',
      'tp': '0',
    };
    final horario = {'dia': 'Lunes a Viernes: 09:00 - 21:00<br>Sabado: 10:00 - 14:00'};

    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: Center(
          child: SizedBox(width: 360, child: PharmacyCard(
            f: sample,
            horario: horario,
            comunasMap: {'1': 'ComunaX'},
            regionesMap: {'13': 'RegionY'},
            titulosTipos: ['Privada', 'Turno'],
            iconosTipos: ['privado', 'turnos'],
            disableNetworkImages: true,
          )),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    await expectLater(find.byType(PharmacyCard), matchesGoldenFile('goldens/pharmacy_card.png'));
  });
}
