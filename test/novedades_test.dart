import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/core/novedades.dart';
import 'package:saman_deportivo/main.dart';

import 'falsos/auth_repository_falso.dart';
import 'falsos/deporte_repository_falso.dart';
import 'falsos/notificacion_repository_falso.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('el registro va de la versión más reciente a la más antigua y ninguna entrada está vacía', () {
    expect(novedades, isNotEmpty);
    for (var i = 1; i < novedades.length; i++) {
      expect(novedades[i - 1].fecha.isBefore(novedades[i].fecha), isFalse,
          reason: 'la versión ${novedades[i - 1].version} va antes que la ${novedades[i].version}');
    }
    expect(novedades.map((n) => n.version).toSet().length, novedades.length);
    for (final n in novedades) {
      expect(n.titulo, isNotEmpty);
      expect(n.cambios, isNotEmpty);
    }
  });

  Future<void> abrirPerfil(WidgetTester tester, String correo, String clave) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = AuthRepositoryFalso.conDatosDePrueba();
    // El falso espera con un temporizador: fuera del reloj simulado de la prueba.
    await tester.runAsync(() => repo.iniciarSesion(correo, clave));
    await tester.pumpWidget(SamanDeportivoApp(
      repositorio: repo,
      deportes: DeporteRepositoryFalso(),
      notificaciones: NotificacionRepositoryFalso(),
      rutaInicial: '/perfil',
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('el administrador abre el registro de actualizaciones desde su perfil', (tester) async {
    await abrirPerfil(tester, 'admin@unimet.edu.ve', 'Admin1234');
    expect(find.byTooltip('Registro de actualizaciones'), findsOneWidget);

    await tester.tap(find.byTooltip('Registro de actualizaciones'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Registro de actualizaciones'), findsOneWidget);
    expect(find.text('Versión actual: ${novedades.first.version}'), findsOneWidget);
    expect(find.text('Versión ${novedades.first.version}'), findsOneWidget);
    expect(find.text(novedades.first.titulo), findsOneWidget);

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Versión actual: ${novedades.first.version}'), findsNothing);
  });

  testWidgets('el estudiante y el entrenador no ven el registro de actualizaciones', (tester) async {
    await abrirPerfil(tester, 'estudiante@correo.unimet.edu.ve', 'Estudiante123');
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.byTooltip('Registro de actualizaciones'), findsNothing);
  });
}
