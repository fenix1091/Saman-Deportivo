import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/validacion_inscripcion.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/pago.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/inscripcion_repository.dart';
import 'package:saman_deportivo/viewmodels/inscripcion_view_model.dart';

import 'falsos/deporte_repository_falso.dart';
import 'falsos/inscripcion_repository_falso.dart';

Future<void> esperar() => Future<void>.delayed(Duration.zero);

const solvente = Estudiante(
  uid: 'est-1',
  cedula: 'V-30111222',
  nombre: 'Estudiante Solvente',
  correo: 'solvente@correo.unimet.edu.ve',
  carnet: '20231110001',
  solvente: true,
);

void main() {
  final ahora = DateTime(2026, 11, 3, 10);
  const futbol = Deporte(codigo: 'FUT-01', nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 20, entrenadorId: 't1');
  const martes = Horario(id: 'h1', dia: DiaSemana.martes, horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha');

  ResultadoValidacion validar({
    Estudiante estudiante = solvente,
    Deporte deporte = futbol,
    List<Horario> horarios = const [martes],
    List<InscripcionConHorarios> otras = const [],
  }) =>
      ValidacionInscripcion.validar(
        estudiante: estudiante,
        deporte: deporte,
        horarios: horarios,
        otras: otras,
        ahora: ahora,
      );

  group('Validación de estado y solvencia (RF-07, RN-01)', () {
    test('un estudiante activo y solvente cumple todos los requisitos', () {
      expect(validar().aprobada, isTrue);
    });

    test('un estudiante no solvente o inactivo no puede inscribirse y sabe por qué', () {
      const noSolvente = Estudiante(uid: 'e', cedula: 'V-1', nombre: 'N', correo: 'n@x.com', carnet: '1');
      final r = validar(estudiante: noSolvente);
      expect(r.aprobada, isFalse);
      expect(r.cumple(Requisito.solvente), isFalse);
      expect(r.motivoDe(Requisito.solvente)!.motivo, contains('Coordinación de Deportes'));

      const inactivo = Estudiante(
        uid: 'e',
        cedula: 'V-1',
        nombre: 'N',
        correo: 'n@x.com',
        carnet: '1',
        solvente: true,
        estado: EstadoEstudiante.inactivo,
      );
      expect(validar(estudiante: inactivo).cumple(Requisito.estudianteActivo), isFalse);
    });

    test('muestra todos los requisitos que fallan a la vez, no solo el primero', () {
      const noSolvente = Estudiante(uid: 'e', cedula: 'V-1', nombre: 'N', correo: 'n@x.com', carnet: '1');
      const lleno = Deporte(codigo: 'FUT-01', nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 25, entrenadorId: 't1');
      final r = validar(estudiante: noSolvente, deporte: lleno);
      expect(r.incumplimientos.map((i) => i.requisito), [Requisito.solvente, Requisito.hayCupo]);
    });
  });

  group('Control de cupos y reglas de inscripción (RF-08)', () {
    test('sin cupos no se puede inscribir (RN-02)', () {
      const lleno = Deporte(codigo: 'FUT-01', nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 25, entrenadorId: 't1');
      expect(validar(deporte: lleno).cumple(Requisito.hayCupo), isFalse);
    });

    test('una disciplina sin entrenador u horarios no recibe inscripciones (RN-07)', () {
      const sinEntrenador = Deporte(codigo: 'FUT-01', nombre: 'Fútbol', cupoMaximo: 25);
      expect(validar(deporte: sinEntrenador).cumple(Requisito.deporteDisponible), isFalse);
      expect(validar(horarios: const []).cumple(Requisito.deporteDisponible), isFalse);
    });

    test('no puede inscribirse dos veces en la misma disciplina (RN-03)', () {
      final confirmada = Inscripcion(
        id: 'FUT-01_est-1',
        estudianteId: 'est-1',
        deporteCodigo: 'FUT-01',
        fechaInscripcion: ahora,
        estado: EstadoInscripcion.confirmada,
      );
      final r = validar(otras: [InscripcionConHorarios(inscripcion: confirmada, nombreDeporte: 'Fútbol', horarios: const [])]);
      expect(r.cumple(Requisito.sinInscripcionPrevia), isFalse);
    });

    test('no puede inscribirse en dos disciplinas cuyos horarios chocan (RN-04)', () {
      InscripcionConHorarios otra(String inicio, String fin, {EstadoInscripcion estado = EstadoInscripcion.confirmada}) =>
          InscripcionConHorarios(
            inscripcion: Inscripcion(
              id: 'TEN-01_est-1',
              estudianteId: 'est-1',
              deporteCodigo: 'TEN-01',
              fechaInscripcion: ahora,
              estado: estado,
            ),
            nombreDeporte: 'Tenis',
            horarios: [Horario(id: 'x', dia: DiaSemana.martes, horaInicio: inicio, horaFin: fin, lugar: 'Otra cancha')],
          );
      final choque = validar(otras: [otra('17:00', '19:00')]);
      expect(choque.cumple(Requisito.sinChoqueDeHorario), isFalse);
      expect(choque.motivoDe(Requisito.sinChoqueDeHorario)!.motivo, 'Choca con Tenis (Martes 17:00 - 19:00).');
      expect(validar(otras: [otra('18:00', '19:00')]).aprobada, isTrue, reason: 'empieza justo al terminar');
      expect(validar(otras: [otra('17:00', '19:00', estado: EstadoInscripcion.cancelada)]).aprobada, isTrue);
    });

    test('una reserva pendiente vence a los 15 minutos (RN-05)', () {
      final reserva =
          Inscripcion(id: 'i', estudianteId: 'e', deporteCodigo: 'FUT-01', fechaInscripcion: DateTime(2026, 11, 3, 10));
      expect(reserva.expiro(DateTime(2026, 11, 3, 10, 14)), isFalse);
      expect(reserva.expiro(DateTime(2026, 11, 3, 10, 15)), isTrue);
      expect(reserva.estaVigente(DateTime(2026, 11, 3, 10, 20)), isFalse);
      expect(Inscripcion.idPara('FUT-01', 'e'), 'FUT-01_e');
    });
  });

  group('Reserva y pago del cupo (RF-09)', () {
    late DeporteRepositoryFalso deportes;
    late InscripcionRepositoryFalso inscripciones;
    late PasarelaFalsa pasarela;

    InscripcionViewModel crear({Estudiante estudiante = solvente, String codigo = 'FUT-01'}) => InscripcionViewModel(
          deportes: deportes,
          inscripciones: inscripciones,
          pasarela: pasarela,
          estudiante: estudiante,
          codigo: codigo,
        );

    setUp(() {
      deportes = DeporteRepositoryFalso.conDatosDePrueba();
      inscripciones = InscripcionRepositoryFalso(deportes);
      pasarela = PasarelaFalsa();
    });

    test('paga con PayPal, confirma la inscripción, ocupa el cupo y guarda la trazabilidad', () async {
      final vm = crear();
      await esperar();
      expect(vm.puedePagar, isTrue);
      expect(await vm.inscribirYPagar(), isTrue);
      await esperar();
      expect(vm.confirmada, isTrue);
      expect(deportes.leer('FUT-01')!.cuposOcupados, 21);
      final pago = inscripciones.pagos.single;
      expect(pago.estado, EstadoPago.completado);
      expect(pago.monto, 5);
      expect(pago.referenciaExterna, 'PRUEBA-1');
      expect(inscripciones.guardadas['FUT-01_est-1']!.pagoId, pago.id);
      expect(vm.pago!.referenciaExterna, 'PRUEBA-1');
    });

    test('un estudiante no solvente no llega a reservar ni a pagar', () async {
      const noSolvente = Estudiante(uid: 'e', cedula: 'V-1', nombre: 'N', correo: 'n@x.com', carnet: '1');
      final vm = crear(estudiante: noSolvente);
      await esperar();
      expect(vm.puedePagar, isFalse);
      expect(await vm.inscribirYPagar(), isFalse);
      expect(inscripciones.guardadas, isEmpty);
      expect(pasarela.cobros, 0);
    });

    test('si cancela el pago la reserva queda pendiente y puede reintentar (CU-07, A4)', () async {
      final vm = crear();
      await esperar();
      pasarela.error = ErrorInscripcion.pagoCancelado;
      expect(await vm.inscribirYPagar(), isFalse);
      await esperar();
      expect(vm.error, ErrorInscripcion.pagoCancelado.mensaje);
      expect(vm.reservaPendiente, isNotNull);
      expect(deportes.leer('FUT-01')!.cuposOcupados, 20, reason: 'la reserva no ocupa cupo (RN-06)');

      pasarela.error = null;
      expect(await vm.inscribirYPagar(), isTrue);
      expect(deportes.leer('FUT-01')!.cuposOcupados, 21);
    });

    test('si el último cupo se ocupa mientras paga, se rechaza y se reembolsa (CU-07, A5)', () async {
      deportes.cambiarCupos('TEN-01', 7);
      final vm = crear(codigo: 'TEN-01');
      await esperar();
      expect(vm.puedePagar, isTrue);
      // Otro estudiante paga primero y se lleva el último cupo.
      final reserva = await inscripciones.reservar(solvente, deportes.leer('TEN-01')!);
      deportes.cambiarCupos('TEN-01', 8);
      await expectLater(
        inscripciones.confirmarPago(reserva, monto: 0, referencia: 'GRATUITA'),
        throwsA(isA<InscripcionException>().having((e) => e.error, 'error', ErrorInscripcion.cupoAgotado)),
      );
      expect(inscripciones.guardadas[reserva.id]!.estado, EstadoInscripcion.rechazada);
      expect(inscripciones.pagos.single.estado, EstadoPago.reembolsado);
      expect(deportes.leer('TEN-01')!.cuposOcupados, 8, reason: 'nunca supera el cupo máximo (RNF-05)');
    });

    test('una disciplina gratuita se confirma sin pasar por PayPal', () async {
      final vm = crear(codigo: 'TEN-01');
      await esperar();
      expect(vm.monto, 0);
      expect(await vm.inscribirYPagar(), isTrue);
      expect(pasarela.cobros, 0);
      expect(inscripciones.pagos.single.referenciaExterna, 'GRATUITA');
    });
  });
}
