import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/main.dart';
import 'falsos/auth_repository_falso.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> abrirLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      SamanDeportivoApp(repositorio: AuthRepositoryFalso.conDatosDePrueba(latencia: Duration.zero)),
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

  testWidgets('el entrenador ve sus datos en el perfil y cambia su teléfono', (tester) async {
    await abrirLogin(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'entrenador@unimet.edu.ve');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Entrenador123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mi perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Fútbol'), findsOneWidget);
    expect(find.text('V-20333444'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Teléfono'), '0412-555');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('celular válido'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Teléfono'), '0412-5550000');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil actualizado'), findsOneWidget);
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
