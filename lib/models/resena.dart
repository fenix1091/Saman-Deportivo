import 'conversion.dart';

/// Reseña de un estudiante sobre un deporte. Se guarda en `resenas/{id}`.
class Resena {
  const Resena({
    required this.id,
    required this.estudianteId,
    required this.deporteCodigo,
    required this.calificacion,
    this.comentario = '',
    required this.fecha,
  }) : assert(calificacion >= 1 && calificacion <= 5);

  final String id;
  final String estudianteId;
  final String deporteCodigo;

  /// De 1 a 5 estrellas.
  final int calificacion;
  final String comentario;
  final DateTime fecha;

  Map<String, dynamic> aMapa() => {
        'estudianteId': estudianteId,
        'deporteCodigo': deporteCodigo,
        'calificacion': calificacion,
        'comentario': comentario,
        'fecha': fecha,
      };

  factory Resena.desdeMapa(String id, Map<String, dynamic> mapa) => Resena(
        id: id,
        estudianteId: mapa['estudianteId'] as String,
        deporteCodigo: mapa['deporteCodigo'] as String,
        calificacion: (mapa['calificacion'] as num).toInt(),
        comentario: mapa['comentario'] as String? ?? '',
        fecha: leerFecha(mapa['fecha']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
