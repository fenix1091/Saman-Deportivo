import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/main.dart';
import 'package:saman_deportivo/repositories/auth_repository_local.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> abrirLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      SamanDeportivoApp(repositorio: AuthRepositoryLocal.conDatosDePrueba(latencia: Duration.zero)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
  }

  testWidgets('el administrador entra y llega a su panel', (tester) async {
    await abrirLogin(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'admin@unimet.edu.ve');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Admin1234');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Panel de administración'), findsOneWidget);
  });

  testWidgets('una contraseña incorrecta muestra el error y no entra', (tester) async {
    await abrirLogin(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'admin@unimet.edu.ve');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Incorrecta1');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Correo o contraseña inválidos.'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsOneWidget);
  });
}
