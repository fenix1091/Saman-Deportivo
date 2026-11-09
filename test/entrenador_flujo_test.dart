import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/main.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/repositories/asistencia_repository.dart';

import 'falsos/asistencia_repository_falso.dart';
import 'falsos/auth_repository_falso.dart';
import 'falsos/deporte_repository_falso.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<AsistenciaRepositoryFalso> entrarComoEntrenador(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final deportes = DeporteRepositoryFalso.conDatosDePrueba();
    final asistencia = AsistenciaRepositoryFalso(deportes)
      ..inscribir(
          'FUT-01',
          const EstudianteInscrito(
              uid: 'a', inscripcionId: 'FUT-01_a', nombreCompleto: 'Ana Pérez', cedulaTexto: 'V-28555123'))
      ..inscribir(
          'FUT-01', const EstudianteInscrito(uid: 'b', inscripcionId: 'FUT-01_b', nombreCompleto: 'Luis Rojas'));
    await tester.pumpWidget(SamanDeportivoApp(
      repositorio: AuthRepositoryFalso.conDatosDePrueba(),
      deportes: deportes,
      asistenciaRepository: asistencia,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'entrenador@unimet.edu.ve');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Entrenador123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    return asistencia;
  }

  testWidgets('el entrenador entra y ve solo sus disciplinas, con los inscritos de cada una', (tester) async {
    await entrarComoEntrenador(tester);
    expect(find.text('Mis disciplinas'), findsOneWidget);
    expect(find.text('Entrenador Prueba'), findsAtLeastNWidgets(1));
    expect(find.text('Fútbol'), findsOneWidget);
    expect(find.text('Tenis'), findsOneWidget);
    expect(find.text('Baloncesto'), findsNothing, reason: 'no está asignado a ese deporte');
    expect(find.text('20 inscritos'), findsOneWidget);
  });

  testWidgets('toma la asistencia de la nómina real y la guarda', (tester) async {
    final repo = await entrarComoEntrenador(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Tomar asistencia').first);
    await tester.pumpAndSettle();
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Luis Rojas'), findsOneWidget);
    expect(find.text('0 de 2 marcados presentes'), findsOneWidget);

    await tester.tap(find.text('Ana Pérez'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 2 marcados presentes'), findsOneWidget);
    await tester.tap(find.text('Guardar asistencia'));
    await tester.pumpAndSettle();

    expect(find.textContaining('guardada: 1 de 2 presentes'), findsOneWidget);
    expect(repo.asistencias.length, 2);
    expect(repo.asistencias.values.where((a) => a.estado == EstadoAsistencia.presente).single.estudianteId, 'a');
    expect(find.text('Actualizar asistencia'), findsOneWidget);

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 2 presentes'), findsOneWidget);
    expect(find.text('1 de 1 · 100 %'), findsOneWidget);
    expect(find.text('0 de 1 · 0 %'), findsOneWidget);
  });
}
