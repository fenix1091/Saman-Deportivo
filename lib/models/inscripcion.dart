import 'conversion.dart';

/// Estados de una inscripción (diagrama de estados del Hito 1).
enum EstadoInscripcion { pendientePago, confirmada, cancelada, rechazada, expirada }

/// Inscripción de un estudiante en un deporte. Se guarda en `inscripciones/{id}`.
class Inscripcion {
  const Inscripcion({
    required this.id,
    required this.estudianteId,
    required this.deporteCodigo,
    required this.fechaInscripcion,
    this.estado = EstadoInscripcion.pendientePago,
    this.motivo = '',
  });

  final String id;
  final String estudianteId;
  final String deporteCodigo;
  final DateTime fechaInscripcion;
  final EstadoInscripcion estado;

  /// Motivo del rechazo o de la cancelación.
  final String motivo;

  /// Una inscripción ocupa cupo mientras está pendiente de pago o confirmada.
  bool estaVigente() => estado == EstadoInscripcion.pendientePago || estado == EstadoInscripcion.confirmada;

  Map<String, dynamic> aMapa() => {
        'estudianteId': estudianteId,
        'deporteCodigo': deporteCodigo,
        'fechaInscripcion': fechaInscripcion,
        'estado': estado.name,
        'motivo': motivo,
      };

  factory Inscripcion.desdeMapa(String id, Map<String, dynamic> mapa) => Inscripcion(
        id: id,
        estudianteId: mapa['estudianteId'] as String,
        deporteCodigo: mapa['deporteCodigo'] as String,
        fechaInscripcion: leerFecha(mapa['fechaInscripcion']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        estado: EstadoInscripcion.values.byName(mapa['estado'] as String? ?? 'pendientePago'),
        motivo: mapa['motivo'] as String? ?? '',
      );
}
