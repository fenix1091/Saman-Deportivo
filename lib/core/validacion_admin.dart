import '../models/deporte.dart';
import '../models/inscripcion.dart';
import '../models/persona.dart';

/// Reglas de negocio del panel de administración (Hito 3, puntos 6 a 8):
/// cuándo se puede eliminar una disciplina o un usuario y cuándo el
/// administrador puede inscribir a un estudiante directamente.
///
/// Cada función devuelve `null` si la operación procede, o el motivo (en el
/// lenguaje del usuario) por el que no se puede hacer. Son funciones puras para
/// poder probarlas sin Firebase; el repositorio las aplica dentro de la transacción.
class ValidacionAdmin {
  ValidacionAdmin._();

  /// Una disciplina solo se elimina si nadie tiene una inscripción vigente en ella
  /// (pendiente de pago, en revisión o confirmada). Si la tiene, lo correcto es
  /// darla de baja (dejarla inactiva) para conservar el historial.
  static String? eliminarDeporte(Deporte deporte, Iterable<Inscripcion> inscripciones) {
    final vigentes = inscripciones.where((i) => i.deporteCodigo == deporte.codigo && i.estaVigente()).length;
    if (vigentes > 0) {
      return '${deporte.nombre} tiene $vigentes ${vigentes == 1 ? 'inscripción vigente' : 'inscripciones vigentes'}. '
          'Retira o cancela esas inscripciones, o da de baja la disciplina en vez de eliminarla.';
    }
    return null;
  }

  /// Un estudiante se elimina si no tiene inscripciones vigentes; un entrenador,
  /// si no tiene disciplinas asignadas; el administrador no puede eliminarse a sí mismo.
  static String? eliminarUsuario(
    Persona usuario, {
    required String adminUid,
    Iterable<Inscripcion> inscripciones = const [],
    Iterable<Deporte> deportes = const [],
  }) {
    if (usuario.uid == adminUid) return 'No puedes eliminar tu propia cuenta de administrador.';
    if (usuario is Estudiante) {
      final vigentes = inscripciones.where((i) => i.estudianteId == usuario.uid && i.estaVigente()).toList();
      if (vigentes.isNotEmpty) {
        final nombres = vigentes.map((i) => i.nombreDeporte.isEmpty ? i.deporteCodigo : i.nombreDeporte).join(', ');
        return '${usuario.nombreCompleto} tiene ${vigentes.length} ${vigentes.length == 1 ? 'inscripción vigente' : 'inscripciones vigentes'} '
            '($nombres). Retíralo de esas disciplinas antes de eliminarlo, o márcalo como inactivo.';
      }
    }
    if (usuario is Entrenador) {
      final asignadas = deportes.where((d) => d.entrenadorId == usuario.uid).map((d) => d.nombre).toList();
      if (asignadas.isNotEmpty) {
        return '${usuario.nombreCompleto} es el entrenador de ${asignadas.join(', ')}. '
            'Asigna otro entrenador a ${asignadas.length == 1 ? 'esa disciplina' : 'esas disciplinas'} antes de eliminarlo.';
      }
    }
    if (usuario is Administrador) return 'Las cuentas de administrador no se eliminan desde el panel.';
    return null;
  }

  /// El administrador inscribe directamente a un estudiante (sin pago): debe estar
  /// activo y solvente, la disciplina debe tener cupo y entrenador, y el estudiante
  /// no puede tener ya una inscripción vigente en ella.
  static String? inscribirDirecto(Estudiante estudiante, Deporte deporte, Iterable<Inscripcion> inscripciones) {
    if (!estudiante.estaActivo()) return '${estudiante.nombreCompleto} está inactivo.';
    if (!estudiante.solvente) return '${estudiante.nombreCompleto} no está solvente; márcalo solvente primero.';
    if (!deporte.activo) return '${deporte.nombre} está dada de baja.';
    if (deporte.entrenadorId.isEmpty) return '${deporte.nombre} no tiene entrenador asignado.';
    if (deporte.cuposDisponibles() == 0) return '${deporte.nombre} no tiene cupos disponibles.';
    final repetida = inscripciones.any(
      (i) => i.estudianteId == estudiante.uid && i.deporteCodigo == deporte.codigo && i.estaVigente(),
    );
    if (repetida) return '${estudiante.nombreCompleto} ya tiene una inscripción vigente en ${deporte.nombre}.';
    return null;
  }
}
