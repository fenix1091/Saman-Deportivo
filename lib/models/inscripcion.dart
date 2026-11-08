import 'conversion.dart';

/// Estados de una inscripción (diagrama de estados del Hito 1, ampliado en el Hito 3
/// con la revisión del pago).
///
/// pendientePago → enRevision → confirmada | rechazada; desde cualquier estado vigente
/// el estudiante puede pasar a cancelada, y una reserva sin pagar vence a expirada.
enum EstadoInscripcion {
  pendientePago('Pendiente de pago'),
  enRevision('En revisión'),
  confirmada('Confirmada'),
  cancelada('Cancelada'),
  rechazada('Rechazada'),
  expirada('Expirada');

  const EstadoInscripcion(this.etiqueta);

  /// Nombre que ve el usuario.
  final String etiqueta;
}

/// Inscripción (reserva) de un estudiante en un deporte.
///
/// Se guarda en `inscripciones/{codigo}_{uid}`: un solo documento por estudiante y
/// deporte, así no puede tener dos inscripciones vigentes en el mismo (RN-03).
///
/// Además de los vínculos guarda una copia de los datos de la reserva (nombre del
/// deporte, horarios, monto, descripción y duración) para que el comprobante y el
/// historial no cambien aunque el administrador edite después la disciplina.
class Inscripcion {
  const Inscripcion({
    required this.id,
    required this.estudianteId,
    required this.deporteCodigo,
    required this.fechaInscripcion,
    this.estado = EstadoInscripcion.pendientePago,
    this.motivo = '',
    this.pagoId = '',
    this.nombreDeporte = '',
    this.horarios = '',
    this.monto = 0,
    this.descripcion = '',
    this.duracion = '',
    this.cupoMaximo = 0,
    this.sesiones = 0,
    this.sesionesAsistidas = 0,
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

  /// Datos de la reserva copiados del deporte al reservar.
  final String nombreDeporte;

  /// Días y horas de entrenamiento, por ejemplo "Martes 16:00 - 18:00 · Cancha 1".
  final String horarios;
  final double monto;
  final String descripcion;
  final String duracion;

  /// Cantidad de personas que admite la disciplina.
  final int cupoMaximo;

  /// Sesiones de entrenamiento registradas por el entrenador y a cuántas asistió.
  final int sesiones;
  final int sesionesAsistidas;

  /// Hora en que vence una reserva pendiente de pago (RN-05).
  DateTime get vencePago => fechaInscripcion.add(const Duration(minutes: minutosParaPagar));

  /// Una reserva pendiente cuyo plazo de pago ya pasó (RN-05).
  bool expiro(DateTime ahora) => estado == EstadoInscripcion.pendientePago && !ahora.isBefore(vencePago);

  /// Está vigente si está confirmada o en revisión, o pendiente de pago y aún dentro del plazo.
  bool estaVigente([DateTime? ahora]) =>
      estado == EstadoInscripcion.confirmada ||
      estado == EstadoInscripcion.enRevision ||
      (estado == EstadoInscripcion.pendientePago && (ahora == null || !expiro(ahora)));

  /// Ocupa un cupo desde que el pago se recibe (en revisión) hasta que se cancela o rechaza (RN-06).
  bool get ocupaCupo => estado == EstadoInscripcion.enRevision || estado == EstadoInscripcion.confirmada;

  /// Porcentaje de asistencia (0 a 100); 0 si aún no hay sesiones.
  double get porcentajeAsistencia => sesiones == 0 ? 0 : sesionesAsistidas * 100 / sesiones;

  Inscripcion copiarCon({EstadoInscripcion? estado, String? motivo, String? pagoId}) => Inscripcion(
        id: id,
        estudianteId: estudianteId,
        deporteCodigo: deporteCodigo,
        fechaInscripcion: fechaInscripcion,
        estado: estado ?? this.estado,
        motivo: motivo ?? this.motivo,
        pagoId: pagoId ?? this.pagoId,
        nombreDeporte: nombreDeporte,
        horarios: horarios,
        monto: monto,
        descripcion: descripcion,
        duracion: duracion,
        cupoMaximo: cupoMaximo,
        sesiones: sesiones,
        sesionesAsistidas: sesionesAsistidas,
      );

  Map<String, dynamic> aMapa() => {
        'estudianteId': estudianteId,
        'deporteCodigo': deporteCodigo,
        'fechaInscripcion': fechaInscripcion,
        'estado': estado.name,
        'motivo': motivo,
        'pagoId': pagoId,
        'nombreDeporte': nombreDeporte,
        'horarios': horarios,
        'monto': monto,
        'descripcion': descripcion,
        'duracion': duracion,
        'cupoMaximo': cupoMaximo,
        'sesiones': sesiones,
        'sesionesAsistidas': sesionesAsistidas,
      };

  factory Inscripcion.desdeMapa(String id, Map<String, dynamic> mapa) => Inscripcion(
        id: id,
        estudianteId: mapa['estudianteId'] as String,
        deporteCodigo: mapa['deporteCodigo'] as String,
        fechaInscripcion: leerFecha(mapa['fechaInscripcion']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        estado: EstadoInscripcion.values.byName(mapa['estado'] as String? ?? 'pendientePago'),
        motivo: mapa['motivo'] as String? ?? '',
        pagoId: mapa['pagoId'] as String? ?? '',
        nombreDeporte: mapa['nombreDeporte'] as String? ?? '',
        horarios: mapa['horarios'] as String? ?? '',
        monto: (mapa['monto'] as num?)?.toDouble() ?? 0,
        descripcion: mapa['descripcion'] as String? ?? '',
        duracion: mapa['duracion'] as String? ?? '',
        cupoMaximo: (mapa['cupoMaximo'] as num?)?.toInt() ?? 0,
        sesiones: (mapa['sesiones'] as num?)?.toInt() ?? 0,
        sesionesAsistidas: (mapa['sesionesAsistidas'] as num?)?.toInt() ?? 0,
      );
}
