import 'conversion.dart';

/// Estados de una inscripción (diagrama de estados del Hito 1).
enum EstadoInscripcion { pendientePago, confirmada, cancelada, rechazada, expirada }

/// Inscripción de un estudiante en un deporte.
///
/// Se guarda en `inscripciones/{codigo}_{uid}`: un solo documento por estudiante y
/// deporte, así no puede tener dos inscripciones vigentes en el mismo (RN-03).
class Inscripcion {
  const Inscripcion({
    required this.id,
    required this.estudianteId,
    required this.deporteCodigo,
    required this.fechaInscripcion,
    this.estado = EstadoInscripcion.pendientePago,
    this.motivo = '',
    this.pagoId = '',
  });

  /// Minutos que tiene el estudiante para pagar antes de que la reserva expire (RN-05).
  static const minutosParaPagar = 15;

  /// Id del documento de la inscripción de un estudiante en un deporte.
  static String idPara(String deporteCodigo, String estudianteId) => '${deporteCodigo}_$estudianteId';

  final String id;
  final String estudianteId;
  final String deporteCodigo;
  final DateTime fechaInscripcion;
  final EstadoInscripcion estado;

  /// Motivo del rechazo o de la cancelación.
  final String motivo;

  /// Id del pago que la confirmó (`pagos/{pagoId}`); vacío mientras no se paga.
  final String pagoId;

  /// Hora en que vence una reserva pendiente de pago (RN-05).
  DateTime get vencePago => fechaInscripcion.add(const Duration(minutes: minutosParaPagar));

  /// Una reserva pendiente cuyo plazo de pago ya pasó (RN-05).
  bool expiro(DateTime ahora) => estado == EstadoInscripcion.pendientePago && !ahora.isBefore(vencePago);

  /// Está vigente si está confirmada, o pendiente de pago y aún dentro del plazo.
  bool estaVigente([DateTime? ahora]) =>
      estado == EstadoInscripcion.confirmada ||
      (estado == EstadoInscripcion.pendientePago && (ahora == null || !expiro(ahora)));

  Map<String, dynamic> aMapa() => {
        'estudianteId': estudianteId,
        'deporteCodigo': deporteCodigo,
        'fechaInscripcion': fechaInscripcion,
        'estado': estado.name,
        'motivo': motivo,
        'pagoId': pagoId,
      };

  factory Inscripcion.desdeMapa(String id, Map<String, dynamic> mapa) => Inscripcion(
        id: id,
        estudianteId: mapa['estudianteId'] as String,
        deporteCodigo: mapa['deporteCodigo'] as String,
        fechaInscripcion: leerFecha(mapa['fechaInscripcion']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        estado: EstadoInscripcion.values.byName(mapa['estado'] as String? ?? 'pendientePago'),
        motivo: mapa['motivo'] as String? ?? '',
        pagoId: mapa['pagoId'] as String? ?? '',
      );
}
