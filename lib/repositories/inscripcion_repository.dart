import '../models/deporte.dart';
import '../models/inscripcion.dart';
import '../models/pago.dart';
import '../models/persona.dart';
import '../models/resena.dart';

/// Contrato de acceso a las inscripciones y sus pagos (CU-07, CU-09).
///
/// Los ViewModels solo conocen esta interfaz (patrón Repositorio). La app usa
/// [InscripcionRepositoryFirebase]; las pruebas usan un repositorio falso en memoria.
abstract class InscripcionRepository {
  /// Inscripciones del estudiante, en tiempo real.
  Stream<List<Inscripcion>> inscripcionesDe(String estudianteId);

  /// Crea la reserva en PENDIENTE_PAGO (CU-07, paso 4). No ocupa cupo: el cupo
  /// solo se ocupa al confirmar el pago (RN-06). Si había una reserva vencida o
  /// una inscripción cancelada en el mismo deporte, la reemplaza.
  Future<Inscripcion> reservar(Estudiante estudiante, Deporte deporte);

  /// Registra el pago aprobado y confirma la inscripción en una sola transacción
  /// (CU-07, paso 6): vuelve a leer el cupo, suma uno a `cuposOcupados`, pasa la
  /// inscripción a CONFIRMADA y guarda el [Pago] con su referencia.
  ///
  /// Si el cupo se agotó mientras se pagaba, marca la inscripción como RECHAZADA,
  /// registra el pago como reembolsado y lanza [ErrorInscripcion.cupoAgotado] (A5).
  Future<Pago> confirmarPago(Inscripcion inscripcion, {required double monto, required String referencia});

  /// Marca como EXPIRADA una reserva cuyo plazo de pago pasó (RN-05).
  Future<void> expirar(Inscripcion inscripcion);

  /// Cancela una inscripción vigente (CU-10). Si estaba confirmada libera su cupo
  /// en la misma transacción; una reserva pendiente de pago no ocupaba cupo (RN-06).
  Future<void> cancelar(String inscripcionId, String deporteCodigo);

  /// Publica o actualiza la reseña del estudiante sobre un deporte (CU-12).
  Future<void> publicarResena(Resena resena);
}

/// Motivos por los que puede fallar una inscripción.
enum ErrorInscripcion {
  noCumpleRequisitos('No cumples los requisitos para inscribirte.'),
  cupoAgotado('El último cupo se ocupó mientras pagabas. Tu pago fue reembolsado.'),
  reservaVencida('Tu reserva venció porque pasaron 15 minutos sin pagar. Vuelve a intentarlo.'),
  pagoCancelado('Cancelaste el pago. Tu reserva sigue apartada mientras no venza.'),
  pagoRechazado('PayPal rechazó el pago. Revisa tu método de pago e inténtalo de nuevo.'),
  noVigente('Esta inscripción ya no está vigente.'),
  sinPermiso('No tienes permiso para hacer esto.'),
  sinConexion('No hay conexión. Revisa tu internet e inténtalo de nuevo.'),
  desconocido('Ocurrió un error inesperado. Inténtalo de nuevo.');

  const ErrorInscripcion(this.mensaje);

  final String mensaje;
}

class InscripcionException implements Exception {
  const InscripcionException(this.error);

  final ErrorInscripcion error;

  String get mensaje => error.mensaje;

  @override
  String toString() => 'InscripcionException(${error.name})';
}
