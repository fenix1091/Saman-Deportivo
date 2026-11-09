import 'conversion.dart';

/// Qué pasó. Define el icono y el color del aviso.
enum TipoNotificacion {
  reservaRecibida('Nueva reserva por revisar'),
  reservaConfirmada('Reserva confirmada'),
  reservaRechazada('Reserva rechazada'),
  inscripcionDirecta('Inscripción realizada'),
  retiro('Retiro de una disciplina'),
  aviso('Aviso');

  const TipoNotificacion(this.titulo);

  final String titulo;
}

/// Aviso dentro de la aplicación. Se guarda en `notificaciones/{id}`.
///
/// Va dirigido a una persona ([paraUid]) o a todo un rol ([paraRol], por ejemplo
/// "administrador" cuando entra una reserva por revisar). Sustituye al correo
/// (RF-22), que el plan gratuito de Firebase no permite enviar.
class Notificacion {
  const Notificacion({
    required this.id,
    this.paraUid = '',
    this.paraRol = '',
    this.deUid = '',
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    this.ruta = '',
    required this.fecha,
    this.leida = false,
  });

  final String id;
  final String paraUid;
  final String paraRol;
  final String deUid;
  final TipoNotificacion tipo;
  final String titulo;
  final String mensaje;

  /// A dónde lleva al tocarla (por ejemplo /mis-inscripciones o /admin/reservas).
  final String ruta;
  final DateTime fecha;
  final bool leida;

  Notificacion copiarCon({bool? leida}) => Notificacion(
        id: id,
        paraUid: paraUid,
        paraRol: paraRol,
        deUid: deUid,
        tipo: tipo,
        titulo: titulo,
        mensaje: mensaje,
        ruta: ruta,
        fecha: fecha,
        leida: leida ?? this.leida,
      );

  Map<String, dynamic> aMapa() => {
        'paraUid': paraUid,
        'paraRol': paraRol,
        'deUid': deUid,
        'tipo': tipo.name,
        'titulo': titulo,
        'mensaje': mensaje,
        'ruta': ruta,
        'fecha': fecha,
        'leida': leida,
      };

  factory Notificacion.desdeMapa(String id, Map<String, dynamic> mapa) => Notificacion(
        id: id,
        paraUid: mapa['paraUid'] as String? ?? '',
        paraRol: mapa['paraRol'] as String? ?? '',
        deUid: mapa['deUid'] as String? ?? '',
        tipo: TipoNotificacion.values.asNameMap()[mapa['tipo']] ?? TipoNotificacion.aviso,
        titulo: mapa['titulo'] as String? ?? '',
        mensaje: mapa['mensaje'] as String? ?? '',
        ruta: mapa['ruta'] as String? ?? '',
        fecha: leerFecha(mapa['fecha']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        leida: mapa['leida'] as bool? ?? false,
      );
}
