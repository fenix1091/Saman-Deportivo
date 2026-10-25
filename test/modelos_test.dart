import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/pago.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/models/resena.dart';

/// Imita el Timestamp de Firestore, que los modelos reconocen por toDate().
class _TimestampFalso {
  _TimestampFalso(this._fecha);
  final DateTime _fecha;
  DateTime toDate() => _fecha;
}

void main() {
  final fecha = DateTime(2026, 11, 3, 16, 30);

  group('Estructura base: cada modelo se guarda y se lee igual desde Firestore', () {
    test('Persona y sus roles', () {
      final usuarios = <Persona>[
        const Estudiante(uid: 'a', cedula: 'V-1', nombre: 'A B', correo: 'a@correo.unimet.edu.ve', carnet: '1'),
        const Entrenador(uid: 'b', cedula: 'V-2', nombre: 'C D', correo: 'b@unimet.edu.ve', especialidad: 'Tenis'),
        const Administrador(uid: 'c', cedula: 'V-3', nombre: 'E F', correo: 'c@unimet.edu.ve', cargo: 'Coordinador'),
      ];
      for (final u in usuarios) {
        final copia = Persona.desdeMapa(u.uid, u.aMapa());
        expect(copia.runtimeType, u.runtimeType);
        expect(copia.aMapa(), u.aMapa());
      }
    });

    test('un estudiante nuevo empieza activo y no solvente', () {
      const e = Estudiante(uid: 'a', cedula: 'V-1', nombre: 'A B', correo: 'a@correo.unimet.edu.ve', carnet: '1');
      expect(e.estaActivo(), isTrue);
      expect(e.solvente, isFalse);
    });

    test('Deporte, Horario, Inscripción, Pago, Asistencia y Reseña', () {
      const deporte = Deporte(codigo: 'FUT-01', nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 3, costoReserva: 5);
      expect(Deporte.desdeMapa('FUT-01', deporte.aMapa()).aMapa(), deporte.aMapa());

      const horario =
          Horario(id: 'h1', dia: DiaSemana.martes, horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha 1');
      expect(Horario.desdeMapa('h1', horario.aMapa()).aMapa(), horario.aMapa());

      final inscripcion = Inscripcion(id: 'i1', estudianteId: 'a', deporteCodigo: 'FUT-01', fechaInscripcion: fecha);
      expect(Inscripcion.desdeMapa('i1', inscripcion.aMapa()).aMapa(), inscripcion.aMapa());

      final pago = Pago(id: 'p1', inscripcionId: 'i1', monto: 5, referenciaExterna: 'PAYID-1', fecha: fecha);
      expect(Pago.desdeMapa('p1', pago.aMapa()).aMapa(), pago.aMapa());

      final asistencia = Asistencia(
        id: 'as1',
        inscripcionId: 'i1',
        estudianteId: 'a',
        deporteCodigo: 'FUT-01',
        fecha: fecha,
        estado: EstadoAsistencia.presente,
      );
      expect(Asistencia.desdeMapa('as1', asistencia.aMapa()).aMapa(), asistencia.aMapa());

      final resena = Resena(id: 'r1', estudianteId: 'a', deporteCodigo: 'FUT-01', calificacion: 5, fecha: fecha);
      expect(Resena.desdeMapa('r1', resena.aMapa()).aMapa(), resena.aMapa());
    });

    test('las fechas se leen también desde un Timestamp de Firestore', () {
      final mapa = {'estudianteId': 'a', 'deporteCodigo': 'FUT-01', 'fechaInscripcion': _TimestampFalso(fecha)};
      expect(Inscripcion.desdeMapa('i1', mapa).fechaInscripcion, fecha);
    });
  });

  group('Reglas de los modelos', () {
    test('los cupos disponibles nunca son negativos y un deporte inactivo no tiene cupo', () {
      expect(const Deporte(codigo: 'X', nombre: 'X', cupoMaximo: 10, cuposOcupados: 4).cuposDisponibles(), 6);
      expect(const Deporte(codigo: 'X', nombre: 'X', cupoMaximo: 10, cuposOcupados: 12).cuposDisponibles(), 0);
      expect(const Deporte(codigo: 'X', nombre: 'X', cupoMaximo: 10, cuposOcupados: 10).hayCupo(), isFalse);
      expect(const Deporte(codigo: 'X', nombre: 'X', cupoMaximo: 10, activo: false).hayCupo(), isFalse);
    });

    test('dos horarios se solapan solo el mismo día, en el mismo lugar y con horas cruzadas', () {
      const base = Horario(id: '1', dia: DiaSemana.lunes, horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha 1');
      const cruzado = Horario(id: '2', dia: DiaSemana.lunes, horaInicio: '17:00', horaFin: '19:00', lugar: 'cancha 1');
      const seguido = Horario(id: '3', dia: DiaSemana.lunes, horaInicio: '18:00', horaFin: '20:00', lugar: 'Cancha 1');
      const otroLugar =
          Horario(id: '4', dia: DiaSemana.lunes, horaInicio: '16:00', horaFin: '18:00', lugar: 'Gimnasio');
      const otroDia = Horario(id: '5', dia: DiaSemana.martes, horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha 1');
      expect(base.seSolapaCon(cruzado), isTrue);
      expect(base.seSolapaCon(seguido), isFalse);
      expect(base.seSolapaCon(otroLugar), isFalse);
      expect(base.seSolapaCon(otroDia), isFalse);
    });

    test('solo las inscripciones pendientes de pago o confirmadas ocupan cupo', () {
      Inscripcion con(EstadoInscripcion e) =>
          Inscripcion(id: 'i', estudianteId: 'a', deporteCodigo: 'X', fechaInscripcion: fecha, estado: e);
      expect(con(EstadoInscripcion.pendientePago).estaVigente(), isTrue);
      expect(con(EstadoInscripcion.confirmada).estaVigente(), isTrue);
      expect(con(EstadoInscripcion.cancelada).estaVigente(), isFalse);
      expect(con(EstadoInscripcion.expirada).estaVigente(), isFalse);
    });
  });
}
