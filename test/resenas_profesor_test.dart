import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:saman_deportivo/models/resena.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';
import 'package:saman_deportivo/viewmodels/auth_view_model.dart';
import 'package:saman_deportivo/viewmodels/detalle_deporte_view_model.dart';
import 'package:saman_deportivo/viewmodels/mis_inscripciones_view_model.dart';
import 'package:saman_deportivo/views/dialogs/publicar_resena_dialog.dart';

import 'falsos/auth_repository_falso.dart';
import 'falsos/deporte_repository_falso.dart';
import 'falsos/inscripcion_repository_falso.dart';

void main() {
  group('Reseña del profesor en el modelo', () {
    test('sin calificar al profesor no se guardan sus campos', () {
      final r = Resena(id: 'x', estudianteId: 'e', deporteCodigo: 'FUT-01', calificacion: 4, fecha: DateTime(2026));
      expect(r.aMapa().containsKey('entrenadorId'), isFalse);
      expect(r.calificaAlEntrenador, isFalse);
    });

    test('con calificación del profesor se guarda y se lee igual', () {
      final r = Resena(
        id: 'x',
        estudianteId: 'e',
        deporteCodigo: 'FUT-01',
        calificacion: 4,
        fecha: DateTime(2026),
        entrenadorId: 'ent-demo',
        calificacionEntrenador: 3,
        comentarioEntrenador: 'Puntual',
      );
      final leida = Resena.desdeMapa('x', r.aMapa());
      expect(leida.entrenadorId, 'ent-demo');
      expect(leida.calificacionEntrenador, 3);
      expect(leida.comentarioEntrenador, 'Puntual');
      expect(leida.calificaAlEntrenador, isTrue);
    });

    test('una reseña vieja, sin datos del profesor, se sigue leyendo', () {
      final leida = Resena.desdeMapa('x', {'estudianteId': 'e', 'deporteCodigo': 'FUT-01', 'calificacion': 5});
      expect(leida.calificacionEntrenador, isNull);
      expect(leida.calificaAlEntrenador, isFalse);
    });
  });

  test('el detalle muestra el promedio del profesor con las notas de todas sus disciplinas', () async {
    final repo = DeporteRepositoryFalso.conDatosDePrueba();
    repo.resenasGuardadas.addAll([
      Resena(
          id: 'a',
          estudianteId: 'e1',
          deporteCodigo: 'FUT-01',
          calificacion: 5,
          fecha: DateTime(2026, 11, 1),
          entrenadorId: 'ent-demo',
          calificacionEntrenador: 4),
      Resena(
          id: 'b',
          estudianteId: 'e2',
          deporteCodigo: 'BAS-01',
          calificacion: 3,
          fecha: DateTime(2026, 11, 2),
          entrenadorId: 'ent-demo',
          calificacionEntrenador: 2),
      Resena(
          id: 'c',
          estudianteId: 'e3',
          deporteCodigo: 'FUT-01',
          calificacion: 5,
          fecha: DateTime(2026, 11, 3),
          entrenadorId: 'otro',
          calificacionEntrenador: 1),
    ]);
    final vm = DetalleDeporteViewModel(repo, 'FUT-01');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(vm.totalResenasProfesor, 2);
    expect(vm.calificacionProfesor, 3);
    expect(vm.resenasProfesorRecientes.first.id, 'b');
    vm.dispose();
  });

  testWidgets('la ventana de reseña califica también al profesor asignado', (tester) async {
    final deportes = DeporteRepositoryFalso.conDatosDePrueba();
    final inscripciones = InscripcionRepositoryFalso(deportes);
    final authRepo = AuthRepositoryFalso.conDatosDePrueba(latencia: Duration.zero);
    await tester.runAsync(() => authRepo.iniciarSesion('estudiante@correo.unimet.edu.ve', 'Estudiante123'));
    final auth = AuthViewModel(authRepo);
    addTearDown(auth.dispose);

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<DeporteRepository>.value(value: deportes),
        ChangeNotifierProvider<AuthViewModel>.value(value: auth),
        ChangeNotifierProvider(create: (_) => MisInscripcionesViewModel(inscripciones)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const PublicarResenaDialog(deporteCodigo: 'FUT-01', nombreDeporte: 'Fútbol'),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Opinar sobre Fútbol'), findsOneWidget);
    expect(find.text('¿Cómo fue el profesor Entrenador Prueba?'), findsOneWidget);

    await tester.tap(find.byTooltip('3 estrellas para el profesor'));
    await tester.enterText(find.widgetWithText(TextField, 'Comentario sobre el profesor (opcional)'), 'Muy paciente');
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();

    final guardada = inscripciones.resenas['FUT-01_est-demo']!;
    expect(guardada.calificacion, 5);
    expect(guardada.entrenadorId, 'ent-demo');
    expect(guardada.calificacionEntrenador, 3);
    expect(guardada.comentarioEntrenador, 'Muy paciente');
  });
}
