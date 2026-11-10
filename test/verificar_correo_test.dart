import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/main.dart';
import 'package:saman_deportivo/models/persona.dart';

import 'falsos/auth_repository_falso.dart';
import 'falsos/deporte_repository_falso.dart';
import 'falsos/inscripcion_repository_falso.dart';
import 'falsos/notificacion_repository_falso.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const correo = 'estudiante@correo.unimet.edu.ve';

  Future<AuthRepositoryFalso> abrir(WidgetTester tester, {String ruta = '/verificar-correo'}) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = AuthRepositoryFalso.conDatosDePrueba();
    // El falso espera con un temporizador: fuera del reloj simulado de la prueba.
    await tester.runAsync(() => repo.iniciarSesion(correo, 'Estudiante123'));
    final deportes = DeporteRepositoryFalso();
    await tester.pumpWidget(SamanDeportivoApp(
      repositorio: repo,
      deportes: deportes,
      inscripciones: InscripcionRepositoryFalso(deportes),
      notificaciones: NotificacionRepositoryFalso(),
      rutaInicial: ruta,
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('la pantalla avanza sola cuando el estudiante abre el enlace del correo', (tester) async {
    final repo = await abrir(tester);
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.textContaining(correo, findRichText: true), findsWidgets);

    // Todavía no abrió el enlace: la consulta periódica no cambia nada.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Revisa tu correo'), findsOneWidget);

    repo.enlacesAbiertos.add(correo);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Correo verificado'), findsOneWidget);
    expect((repo.usuarioActual! as Estudiante).correoVerificado, isTrue);

    await tester.tap(find.text('Ir a mi panel'));
    await tester.pumpAndSettle();
    expect(find.text('Correo verificado'), findsNothing);
    expect(find.textContaining('Verifica tu correo para poder reservar'), findsNothing);
  });

  testWidgets('"Ya abrí el enlace" avisa si aún no está verificado, y se puede reenviar el correo', (tester) async {
    final repo = await abrir(tester);
    await tester.tap(find.text('Ya abrí el enlace'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Todavía no aparece verificado'), findsOneWidget);

    await tester.tap(find.text('Reenviar correo'));
    await tester.pump();
    expect(repo.reenvios, 1);
    expect(find.textContaining('Te enviamos otro correo'), findsOneWidget);
    // El botón queda en espera para no mandar correos seguidos.
    expect(find.text('Reenviar correo (60 s)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    expect(find.text('Reenviar correo'), findsOneWidget);
  });

  testWidgets('sin verificar, el panel del estudiante lo recuerda y lleva a la verificación', (tester) async {
    await abrir(tester, ruta: '/estudiante');
    expect(find.textContaining('Verifica tu correo para poder reservar'), findsOneWidget);
    await tester.ensureVisible(find.text('Verificar'));
    await tester.tap(find.text('Verificar'));
    await tester.pumpAndSettle();
    expect(find.text('Revisa tu correo'), findsOneWidget);

    await tester.tap(find.text('Verificar después'));
    await tester.pumpAndSettle();
    expect(find.text('Revisa tu correo'), findsNothing);
  });
}
