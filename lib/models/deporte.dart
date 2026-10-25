/// Disciplina deportiva y sus horarios (diagrama de clases del Hito 1).
///
/// Se guarda en `deportes/{codigo}` y sus horarios en la subcolección
/// `deportes/{codigo}/horarios`.
library;

enum DiaSemana {
  lunes('Lunes'),
  martes('Martes'),
  miercoles('Miércoles'),
  jueves('Jueves'),
  viernes('Viernes'),
  sabado('Sábado'),
  domingo('Domingo');

  const DiaSemana(this.etiqueta);

  final String etiqueta;
}

/// Franjas horarias del filtro del catálogo (CU-05), según la hora de inicio.
enum FranjaHoraria {
  manana('Mañana', 0, 12 * 60),
  tarde('Tarde', 12 * 60, 18 * 60),
  noche('Noche', 18 * 60, 24 * 60);

  const FranjaHoraria(this.etiqueta, this.desde, this.hasta);

  final String etiqueta;

  /// Minutos desde la medianoche: [desde] incluido, [hasta] excluido.
  final int desde;
  final int hasta;
}

/// Datos públicos del entrenador asignado.
///
/// La colección `usuarios` no es pública, así que al asignar el entrenador (RF-18)
/// se copian en el deporte el nombre, la especialidad y la experiencia que muestra
/// el catálogo.
class EntrenadorAsignado {
  const EntrenadorAsignado({required this.nombre, this.especialidad = '', this.aniosExperiencia = 0});

  final String nombre;
  final String especialidad;
  final int aniosExperiencia;

  Map<String, dynamic> aMapa() =>
      {'nombre': nombre, 'especialidad': especialidad, 'aniosExperiencia': aniosExperiencia};

  factory EntrenadorAsignado.desdeMapa(Map<String, dynamic> mapa) => EntrenadorAsignado(
        nombre: mapa['nombre'] as String? ?? '',
        especialidad: mapa['especialidad'] as String? ?? '',
        aniosExperiencia: (mapa['aniosExperiencia'] as num?)?.toInt() ?? 0,
      );
}

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
    this.entrenador,
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
  final EntrenadorAsignado? entrenador;
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
        if (entrenador != null) 'entrenador': entrenador!.aMapa(),
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
        entrenador: mapa['entrenador'] is Map
            ? EntrenadorAsignado.desdeMapa(Map<String, dynamic>.from(mapa['entrenador'] as Map))
            : null,
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

  /// Franja a la que pertenece según su hora de inicio.
  FranjaHoraria get franja {
    final inicio = _minutos(horaInicio);
    return FranjaHoraria.values.firstWhere((f) => inicio >= f.desde && inicio < f.hasta);
  }

  /// Por ejemplo: "Martes 16:00 - 18:00".
  String get etiqueta => '${dia.etiqueta} $horaInicio - $horaFin';

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
