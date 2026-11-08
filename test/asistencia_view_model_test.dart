import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/repositories/asistencia_repository.dart';
import 'package:saman_deportivo/viewmodels/asistencia_view_model.dart';

import 'falsos/asistencia_repository_falso.dart';
import 'falsos/deporte_repository_falso.dart';

Future<void> esperar() => Future<void>.delayed(Duration.zero);

void main() {
  late AsistenciaRepositoryFalso repo;
  final hoy = DateTime(2026, 11, 8, 15, 30);

  const ana =
      EstudianteInscrito(uid: 'a', inscripcionId: 'FUT-01_a', nombreCompleto: 'Ana Pérez', cedulaTexto: 'V-28555123');
  const luis =
      EstudianteInscrito(uid: 'b', inscripcionId: 'FUT-01_b', nombreCompleto: 'Luis Rojas', carnet: '20231110045');

  setUp(() {
    repo = AsistenciaRepositoryFalso(DeporteRepositoryFalso.conDatosDePrueba())
      ..inscribir('FUT-01', ana)
      ..inscribir('FUT-01', luis);
  });

  AsistenciaViewModel crear() => AsistenciaViewModel(repo, 'FUT-01', reloj: () => hoy);

  group('Nómina y toma de asistencia (CU-13, CU-14)', () {
    test('la nómina trae solo a los inscritos de la disciplina, todos ausentes al empezar', () async {
      final vm = crear();
      await esperar();
      expect(vm.cargando, isFalse);
      expect(vm.nomina.map((e) => e.nombreCompleto), ['Ana Pérez', 'Luis Rojas']);
      expect(vm.presente('a'), isFalse);
      expect(vm.fecha, DateTime(2026, 11, 8));
      expect(vm.fechaRegistrada, isFalse);
      vm.dispose();
    });

    test('guarda un documento por estudiante y fecha con su estado, y suma la sesión a la inscripción', () async {
      final vm = crear();
      await esperar();
      vm.marcar('a', true);
      expect(vm.totalPresentes, 1);
      expect(await vm.guardar(), isTrue);
      expect(vm.tomarAviso(), 'Asistencia del 08/11/2026 guardada: 1 de 2 presentes.');
      expect(repo.asistencias.keys, containsAll(['FUT-01_a_2026-11-08', 'FUT-01_b_2026-11-08']));
      expect(repo.asistencias['FUT-01_a_2026-11-08']!.estado, EstadoAsistencia.presente);
      expect(repo.asistencias['FUT-01_b_2026-11-08']!.estado, EstadoAsistencia.ausente);
      await esperar();
      final anaGuardada = repo.inscritos['FUT-01']!.firstWhere((e) => e.uid == 'a');
      expect(anaGuardada.sesiones, 1);
      expect(anaGuardada.sesionesAsistidas, 1);
      expect(vm.fechaRegistrada, isTrue);
      vm.dispose();
    });

    test('volver a guardar la misma fecha corrige en vez de duplicar', () async {
      final vm = crear();
      await esperar();
      vm.marcar('a', true);
      await vm.guardar();
      await esperar();
      vm.marcar('a', false);
      vm.marcar('b', true);
      await vm.guardar();
      await esperar();
      expect(repo.asistencias.length, 2, reason: 'una por estudiante en esa fecha');
      final ana = repo.inscritos['FUT-01']!.firstWhere((e) => e.uid == 'a');
      final luis = repo.inscritos['FUT-01']!.firstWhere((e) => e.uid == 'b');
      expect([ana.sesiones, ana.sesionesAsistidas], [1, 0]);
      expect([luis.sesiones, luis.sesionesAsistidas], [1, 1]);
      vm.dispose();
    });

    test('al cambiar de fecha carga lo registrado ese día; marcar todos y desmarcar todos', () async {
      final vm = crear();
      await esperar();
      vm.marcarTodos(true);
      await vm.guardar();
      vm.cambiarFecha(DateTime(2026, 11, 6));
      expect(vm.presente('a'), isFalse);
      expect(vm.fechaRegistrada, isFalse);
      vm.cambiarFecha(DateTime(2026, 11, 8, 23));
      expect(vm.presente('a'), isTrue);
      expect(vm.presente('b'), isTrue);
      vm.marcarTodos(false);
      expect(vm.totalPresentes, 0);
      vm.dispose();
    });

    test('si Firestore rechaza la escritura muestra el motivo', () async {
      final vm = crear();
      await esperar();
      repo.fallo = const AsistenciaException('Solo el entrenador asignado puede registrar la asistencia.');
      expect(await vm.guardar(), isFalse);
      expect(vm.error, 'Solo el entrenador asignado puede registrar la asistencia.');
      vm.dispose();
    });
  });

  group('Historial y porcentaje (CU-15)', () {
    test('calcula sesiones, porcentaje por estudiante y promedio de la disciplina', () async {
      final vm = crear();
      await esperar();
      vm.marcarTodos(true);
      await vm.guardar();
      vm.cambiarFecha(DateTime(2026, 11, 6));
      vm.marcar('a', true);
      await vm.guardar();
      vm.cambiarFecha(DateTime(2026, 11, 4));
      vm.marcar('a', true);
      vm.marcar('b', false);
      await vm.guardar();
      await esperar();
      expect(vm.sesiones.map((s) => s.fecha.day), [8, 6, 4], reason: 'de la más reciente a la más antigua');
      expect(vm.sesiones.first.presentes, 2);
      expect(vm.porcentaje('a'), 100);
      expect(vm.porcentaje('b'), closeTo(33.3, 0.1));
      expect(vm.asistidasDe('b'), 1);
      expect(vm.sesionesDe('b'), 3);
      expect(vm.promedio, closeTo(66.7, 0.1));
      vm.dispose();
    });

    test('el entrenador solo ve sus disciplinas', () async {
      final lista = await repo.deportesDe('ent-demo').first;
      expect(lista.map((d) => d.codigo), ['FUT-01', 'TEN-01']);
      expect(await repo.deportesDe('nadie').first, isEmpty);
    });
  });
}
