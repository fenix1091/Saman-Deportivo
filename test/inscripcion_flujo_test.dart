import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/main.dart';
import 'package:saman_deportivo/models/persona.dart';

import 'falsos/auth_repository_falso.dart';
import 'falsos/deporte_repository_falso.dart';
import 'falsos/inscripcion_repository_falso.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<DeporteRepositoryFalso> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final auth = AuthRepositoryFalso.conDatosDePrueba()
      ..agregarCuenta(
        const Estudiante(
          uid: 'est-solvente',
          cedula: 'V-30999888',
          nombre: 'Estudiante Solvente',
          correo: 'solvente@correo.unimet.edu.ve',
          carnet: '20231110002',
          solvente: true,
        ),
        'Solvente123',
      );
    final deportes = DeporteRepositoryFalso.conDatosDePrueba();
    await tester.pumpWidget(SamanDeportivoApp(
      repositorio: auth,
      deportes: deportes,
      inscripciones: InscripcionRepositoryFalso(deportes),
      pasarela: PasarelaFalsa(),
    ));
    await tester.pumpAndSettle();
    return deportes;
  }

  Future<void> entrar(WidgetTester tester, String correo, String clave) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), correo);
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), clave);
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
  }

  testWidgets('un visitante pulsa Inscribirme, inicia sesión, paga con PayPal y ve el comprobante', (tester) async {
    final deportes = await abrir(tester);
    await tester.tap(find.text('Ver deportes sin iniciar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fútbol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inscribirme'));
    await tester.pumpAndSettle();

    // CU-06, A1: la guardia lo manda al login y después vuelve a la inscripción.
    expect(find.text('Inicia sesión'), findsOneWidget);
    await entrar(tester, 'solvente@correo.unimet.edu.ve', 'Solvente123');
    expect(find.text('Requisitos'), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsNothing);

    await tester.tap(find.text('Pagar \$5.00 con PayPal'));
    await tester.pumpAndSettle();
    expect(find.text('PayPal (sandbox)'), findsOneWidget);
    await tester.tap(find.text('Aprobar pago'));
    await tester.pumpAndSettle();

    expect(find.text('¡Inscripción confirmada!'), findsOneWidget);
    expect(find.text('PRUEBA-1'), findsOneWidget);
    expect(deportes.leer('FUT-01')!.cuposOcupados, 21);
  });

  testWidgets('un estudiante no solvente ve el motivo y no puede pagar', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    await entrar(tester, 'estudiante@correo.unimet.edu.ve', 'Estudiante123');
    await tester.tap(find.text('Fútbol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inscribirme'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No apareces como solvente'), findsOneWidget);
    final boton = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text('Pagar \$5.00 con PayPal'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('sin cupos el botón aparece deshabilitado (CU-06, A2)', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Ver deportes sin iniciar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baloncesto'));
    await tester.pumpAndSettle();
    final boton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Sin cupos'));
    expect(boton.onPressed, isNull);
  });
}
