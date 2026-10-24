/// Disciplina deportiva y sus horarios (diagrama de clases del Hito 1).
///
/// Se guarda en `deportes/{codigo}` y sus horarios en la subcolección
/// `deportes/{codigo}/horarios`.
library;

enum DiaSemana { lunes, martes, miercoles, jueves, viernes, sabado, domingo }

class Deporte {
  const Deporte({
    required this.codigo,
    required this.nombre,
    this.descripcion = '',
    this.categoria = '',
    required this.cupoMaximo,
    this.cuposOcupados = 0,
    this.costoReserva = 0,
    this.imagenUrl = '',
    this.entrenadorId = '',
    this.activo = true,
    this.vecesBuscado = 0,
  });

  /// Código único; es el id del documento.
  final String codigo;
  final String nombre;
  final String descripcion;
  final String categoria;
  final int cupoMaximo;
  final int cuposOcupados;
  final double costoReserva;
  final String imagenUrl;

  /// uid del entrenador asignado; vacío si aún no tiene.
  final String entrenadorId;
  final bool activo;
  final int vecesBuscado;

  int cuposDisponibles() => (cupoMaximo - cuposOcupados).clamp(0, cupoMaximo);

  bool hayCupo() => activo && cuposDisponibles() > 0;

  Map<String, dynamic> aMapa() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'categoria': categoria,
        'cupoMaximo': cupoMaximo,
        'cuposOcupados': cuposOcupados,
        'costoReserva': costoReserva,
        'imagenUrl': imagenUrl,
        'entrenadorId': entrenadorId,
        'activo': activo,
        'vecesBuscado': vecesBuscado,
      };

  factory Deporte.desdeMapa(String codigo, Map<String, dynamic> mapa) => Deporte(
        codigo: codigo,
        nombre: mapa['nombre'] as String,
        descripcion: mapa['descripcion'] as String? ?? '',
        categoria: mapa['categoria'] as String? ?? '',
        cupoMaximo: (mapa['cupoMaximo'] as num).toInt(),
        cuposOcupados: (mapa['cuposOcupados'] as num?)?.toInt() ?? 0,
        costoReserva: (mapa['costoReserva'] as num?)?.toDouble() ?? 0,
        imagenUrl: mapa['imagenUrl'] as String? ?? '',
        entrenadorId: mapa['entrenadorId'] as String? ?? '',
        activo: mapa['activo'] as bool? ?? true,
        vecesBuscado: (mapa['vecesBuscado'] as num?)?.toInt() ?? 0,
      );
}

/// Bloque semanal de entrenamiento. Las horas se guardan como "HH:mm".
class Horario {
  const Horario({
    required this.id,
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
    required this.lugar,
  });

  final String id;
  final DiaSemana dia;
  final String horaInicio;
  final String horaFin;
  final String lugar;

  static int _minutos(String hora) {
    final partes = hora.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  /// Dos horarios se solapan si son el mismo día, en el mismo lugar y sus horas se cruzan.
  bool seSolapaCon(Horario otro) =>
      dia == otro.dia &&
      lugar.trim().toLowerCase() == otro.lugar.trim().toLowerCase() &&
      _minutos(horaInicio) < _minutos(otro.horaFin) &&
      _minutos(otro.horaInicio) < _minutos(horaFin);

  Map<String, dynamic> aMapa() => {'dia': dia.name, 'horaInicio': horaInicio, 'horaFin': horaFin, 'lugar': lugar};

  factory Horario.desdeMapa(String id, Map<String, dynamic> mapa) => Horario(
        id: id,
        dia: DiaSemana.values.byName(mapa['dia'] as String),
        horaInicio: mapa['horaInicio'] as String,
        horaFin: mapa['horaFin'] as String,
        lugar: mapa['lugar'] as String? ?? '',
      );
}
