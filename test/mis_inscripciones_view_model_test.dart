import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/viewmodels/mis_inscripciones_view_model.dart';

import 'falsos/deporte_repository_falso.dart';
import 'falsos/inscripcion_repository_falso.dart';

Future<void> esperar() => Future<void>.delayed(Duration.zero);

void main() {
  late DeporteRepositoryFalso deportes;
  late InscripcionRepositoryFalso inscripciones;
  late MisInscripcionesViewModel vm;

  Inscripcion inscripcion(String codigo, EstadoInscripcion estado) => Inscripcion(
        id: Inscripcion.idPara(codigo, 'est-1'),
        estudianteId: 'est-1',
        deporteCodigo: codigo,
        fechaInscripcion: DateTime.now(),
        estado: estado,
      );

  setUp(() {
    deportes = DeporteRepositoryFalso.conDatosDePrueba();
    inscripciones = InscripcionRepositoryFalso(deportes);
    vm = MisInscripcionesViewModel(inscripciones);
  });

  tearDown(() => vm.dispose());

  group('Mis inscripciones (CU-10, CU-11)', () {
    test('separa las vigentes del historial', () async {
      inscripciones
        ..agregar(inscripcion('FUT-01', EstadoInscripcion.confirmada))
        ..agregar(inscripcion('TEN-01', EstadoInscripcion.cancelada))
        ..agregar(Inscripcion(
          id: 'BAS-01_otro',
          estudianteId: 'otro',
          deporteCodigo: 'BAS-01',
          fechaInscripcion: DateTime.now(),
          estado: EstadoInscripcion.confirmada,
        ));
      vm.escucharInscripciones('est-1');
      await esperar();
      expect(vm.cargando, isFalse);
      expect(vm.vigentes.map((i) => i.deporteCodigo), ['FUT-01']);
      expect(vm.historial.map((i) => i.deporteCodigo), ['TEN-01']);
    });

    test('cancelar una inscripción confirmada libera su cupo', () async {
      inscripciones.agregar(inscripcion('FUT-01', EstadoInscripcion.confirmada));
      expect(await vm.cancelarInscripcion('FUT-01_est-1', 'FUT-01'), isTrue);
      expect(inscripciones.guardadas['FUT-01_est-1']!.estado, EstadoInscripcion.cancelada);
      expect(deportes.leer('FUT-01')!.cuposOcupados, 19);
    });

    test('cancelar una reserva pendiente de pago no libera cupo (RN-06)', () async {
      inscripciones.agregar(inscripcion('FUT-01', EstadoInscripcion.pendientePago));
      expect(await vm.cancelarInscripcion('FUT-01_est-1', 'FUT-01'), isTrue);
      expect(deportes.leer('FUT-01')!.cuposOcupados, 20);
    });

    test('no se cancela dos veces ni se libera otro cupo', () async {
      inscripciones.agregar(inscripcion('FUT-01', EstadoInscripcion.confirmada));
      await vm.cancelarInscripcion('FUT-01_est-1', 'FUT-01');
      expect(await vm.cancelarInscripcion('FUT-01_est-1', 'FUT-01'), isFalse);
      expect(vm.error, 'Esta inscripción ya no está vigente.');
      expect(deportes.leer('FUT-01')!.cuposOcupados, 19);
    });
  });

  test('la reseña se guarda una por estudiante y deporte, firmada con su nombre (CU-12)', () async {
    final ok = await vm.publicarResena(
      deporteCodigo: 'FUT-01',
      estudianteId: 'est-1',
      calificacion: 4,
      comentario: 'Buen entrenador',
      autor: 'Estudiante Uno',
    );
    expect(ok, isTrue);
    final resena = inscripciones.resenas['FUT-01_est-1']!;
    expect(resena.calificacion, 4);
    expect(resena.autor, 'Estudiante Uno');
  });
}
