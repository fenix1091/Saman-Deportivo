import 'conversion.dart';

enum EstadoAsistencia { presente, ausente }

/// Asistencia de un estudiante a un entrenamiento. Se guarda en `asistencias/{id}`.
class Asistencia {
  const Asistencia({
    required this.id,
    required this.inscripcionId,
    required this.estudianteId,
    required this.deporteCodigo,
    required this.fecha,
    required this.estado,
    this.observacion = '',
  });

  final String id;
  final String inscripcionId;
  final String estudianteId;
  final String deporteCodigo;

  /// Fecha del entrenamiento.
  final DateTime fecha;
  final EstadoAsistencia estado;
  final String observacion;

  Map<String, dynamic> aMapa() => {
        'inscripcionId': inscripcionId,
        'estudianteId': estudianteId,
        'deporteCodigo': deporteCodigo,
        'fecha': fecha,
        'estado': estado.name,
        'observacion': observacion,
      };

  factory Asistencia.desdeMapa(String id, Map<String, dynamic> mapa) => Asistencia(
        id: id,
        inscripcionId: mapa['inscripcionId'] as String,
        estudianteId: mapa['estudianteId'] as String,
        deporteCodigo: mapa['deporteCodigo'] as String,
        fecha: leerFecha(mapa['fecha']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        estado: EstadoAsistencia.values.byName(mapa['estado'] as String),
        observacion: mapa['observacion'] as String? ?? '',
      );
}
