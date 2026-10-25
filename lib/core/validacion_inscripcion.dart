/// Validación de una inscripción antes de reservar el cupo (CU-07 pasos 1 a 3 y CU-08).
///
/// Es lógica pura, sin Firebase, para poder probarla sola. Las mismas condiciones
/// de estado, solvencia y cupo las vuelve a comprobar firestore.rules en el
/// servidor, así que saltarse la app no sirve para inscribirse.
library;

import '../models/deporte.dart';
import '../models/inscripcion.dart';
import '../models/persona.dart';

/// Cada requisito que se revisa, con el texto que ve el estudiante.
enum Requisito {
  estudianteActivo('Estudiante activo'),
  solvente('Solvente con la universidad'),
  deporteDisponible('Disciplina abierta a inscripciones'),
  hayCupo('Cupos disponibles'),
  sinInscripcionPrevia('Sin otra inscripción en esta disciplina'),
  sinChoqueDeHorario('Sin choque con tus otros horarios');

  const Requisito(this.etiqueta);

  final String etiqueta;
}

/// Un requisito que no se cumple y cómo resolverlo (CU-07, A1 a A3).
class Incumplimiento {
  const Incumplimiento(this.requisito, this.motivo);

  final Requisito requisito;
  final String motivo;
}

/// Otra inscripción vigente del estudiante, con los horarios de su deporte.
class InscripcionConHorarios {
  const InscripcionConHorarios({required this.inscripcion, required this.nombreDeporte, required this.horarios});

  final Inscripcion inscripcion;
  final String nombreDeporte;
  final List<Horario> horarios;
}

class ResultadoValidacion {
  const ResultadoValidacion(this.incumplimientos);

  final List<Incumplimiento> incumplimientos;

  bool get aprobada => incumplimientos.isEmpty;

  bool cumple(Requisito requisito) => incumplimientos.every((i) => i.requisito != requisito);

  Incumplimiento? motivoDe(Requisito requisito) {
    for (final i in incumplimientos) {
      if (i.requisito == requisito) return i;
    }
    return null;
  }
}

class ValidacionInscripcion {
  const ValidacionInscripcion._();

  /// Dos horarios chocan si son el mismo día y sus horas se cruzan, sin importar
  /// el lugar (a diferencia de [Horario.seSolapaCon], que es para el administrador).
  static bool chocan(Horario a, Horario b) {
    int minutos(String hora) {
      final partes = hora.split(':');
      return int.parse(partes[0]) * 60 + int.parse(partes[1]);
    }

    return a.dia == b.dia &&
        minutos(a.horaInicio) < minutos(b.horaFin) &&
        minutos(b.horaInicio) < minutos(a.horaFin);
  }

  /// Revisa todas las reglas y devuelve todas las que fallan, no solo la primera,
  /// para que el estudiante sepa todo lo que debe resolver.
  ///
  /// [otras] son las inscripciones vigentes del estudiante (RN-03, RN-04).
  static ResultadoValidacion validar({
    required Estudiante estudiante,
    required Deporte deporte,
    required List<Horario> horarios,
    required List<InscripcionConHorarios> otras,
    required DateTime ahora,
  }) {
    final fallas = <Incumplimiento>[];

    // RN-01 (CU-08): estado y solvencia, tal como los registra la Coordinación de Deportes.
    if (!estudiante.estaActivo()) {
      fallas.add(const Incumplimiento(
        Requisito.estudianteActivo,
        'Tu estado académico es inactivo. Regulariza tu inscripción en la universidad.',
      ));
    }
    if (!estudiante.solvente) {
      fallas.add(const Incumplimiento(
        Requisito.solvente,
        'No apareces como solvente. Ponte al día en Caja y pide a la Coordinación de Deportes que lo actualice.',
      ));
    }

    // RN-07: solo se aceptan inscripciones con entrenador y horarios.
    if (!deporte.activo || deporte.entrenadorId.isEmpty || horarios.isEmpty) {
      fallas.add(const Incumplimiento(
        Requisito.deporteDisponible,
        'Esta disciplina aún no tiene entrenador u horarios, así que no recibe inscripciones.',
      ));
    }

    // RN-02 / RF-08: el cupo se vuelve a revisar en la transacción del pago.
    if (deporte.cuposDisponibles() <= 0) {
      fallas.add(const Incumplimiento(Requisito.hayCupo, 'No hay cupos disponibles en esta disciplina.'));
    }

    // RN-03: una sola inscripción vigente por deporte.
    final enEste = otras.where((o) => o.inscripcion.deporteCodigo == deporte.codigo);
    if (enEste.any((o) => o.inscripcion.estado == EstadoInscripcion.confirmada)) {
      fallas.add(const Incumplimiento(Requisito.sinInscripcionPrevia, 'Ya estás inscrito en esta disciplina.'));
    }

    // RN-04: sin choques con los horarios de las otras disciplinas vigentes.
    for (final otra in otras) {
      if (otra.inscripcion.deporteCodigo == deporte.codigo || !otra.inscripcion.estaVigente(ahora)) continue;
      for (final h in horarios) {
        final choque = otra.horarios.where((o) => chocan(h, o)).firstOrNull;
        if (choque != null) {
          fallas.add(Incumplimiento(
            Requisito.sinChoqueDeHorario,
            'Choca con ${otra.nombreDeporte} (${choque.etiqueta}).',
          ));
          break;
        }
      }
    }

    return ResultadoValidacion(fallas);
  }
}
