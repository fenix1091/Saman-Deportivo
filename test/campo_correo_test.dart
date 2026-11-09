import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/core/theme.dart';
import 'package:saman_deportivo/core/validadores.dart';
import 'package:saman_deportivo/widgets/campo_correo.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<TextEditingController> abrir(WidgetTester tester, {VoidCallback? alEnviar}) async {
    final correo = TextEditingController();
    addTearDown(correo.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CampoCorreo(controller: correo, validator: Validadores.correo, alEnviar: alEnviar),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: 'Contraseña')),
            ],
          ),
        ),
      ),
    ));
    return correo;
  }

  testWidgets('al escribir el usuario propone los correos de la UNIMET y un clic lo completa', (tester) async {
    final correo = await abrir(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'vgallo');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('vgallo@correo.unimet.edu.ve'), findsOneWidget);
    expect(find.bySemanticsLabel('vgallo@unimet.edu.ve'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('vgallo@unimet.edu.ve'));
    await tester.pumpAndSettle();
    expect(correo.text, 'vgallo@unimet.edu.ve');
    expect(find.bySemanticsLabel('vgallo@correo.unimet.edu.ve'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter elige la primera propuesta; con el correo completo, envía el formulario', (tester) async {
    var enviado = 0;
    final correo = await abrir(tester, alEnviar: () => enviado++);
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'vgallo@c');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('vgallo@unimet.edu.ve'), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(correo.text, 'vgallo@correo.unimet.edu.ve');
    expect(enviado, 0);

    await tester.showKeyboard(find.widgetWithText(TextFormField, 'Correo'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(enviado, 1);
  });
}
