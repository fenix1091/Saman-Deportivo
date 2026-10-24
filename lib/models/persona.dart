/// Modelo de usuarios del sistema (ver el diagrama de clases del Hito 1).
///
/// Persona es la clase base; Estudiante, Entrenador y Administrador heredan de ella.
/// Cada usuario se guarda como un documento de la colección `usuarios` de Firestore,
/// cuyo id es el uid de Firebase Auth y cuyo campo `rol` indica la subclase.
library;

/// Rol del usuario dentro de Samán Deportivo.
enum Rol { estudiante, entrenador, administrador }

/// Estado académico del estudiante en la UNIMET.
enum EstadoEstudiante { activo, inactivo }

/// Clase base con los datos comunes a todos los usuarios.
abstract class Persona {
  const Persona({
    required this.uid,
    required this.cedula,
    required this.nombre,
    required this.correo,
    this.telefono = '',
    this.fotoUrl = '',
  });

  final String uid;
  final String cedula;
  final String nombre;
  final String correo;
  final String telefono;
  final String fotoUrl;

  Rol get rol;

  /// Devuelve una copia con los datos editables del perfil cambiados.
  Persona copiarPerfil({String? telefono, String? fotoUrl});

  /// Convierte el usuario al documento que se guarda en Firestore.
  Map<String, dynamic> aMapa() => {
        'rol': rol.name,
        'cedula': cedula,
        'nombre': nombre,
        'correo': correo,
        'telefono': telefono,
        'fotoUrl': fotoUrl,
      };

  /// Crea la subclase que corresponde al campo `rol` del documento.
  factory Persona.desdeMapa(String uid, Map<String, dynamic> mapa) {
    final rol = Rol.values.byName(mapa['rol'] as String);
    return switch (rol) {
      Rol.estudiante => Estudiante.desdeMapa(uid, mapa),
      Rol.entrenador => Entrenador.desdeMapa(uid, mapa),
      Rol.administrador => Administrador.desdeMapa(uid, mapa),
    };
  }
}

/// Estudiante de la UNIMET que se inscribe en las disciplinas.
class Estudiante extends Persona {
  const Estudiante({
    required super.uid,
    required super.cedula,
    required super.nombre,
    required super.correo,
    super.telefono,
    super.fotoUrl,
    required this.carnet,
    this.estado = EstadoEstudiante.activo,
    this.solvente = false,
    this.carrera = '',
  });

  final String carnet;
  final EstadoEstudiante estado;

  /// Lo marca la Coordinación de Deportes; el estudiante empieza como no solvente
  /// y no puede cambiarlo (lo impiden las reglas de Firestore).
  final bool solvente;
  final String carrera;

  @override
  Rol get rol => Rol.estudiante;

  bool estaActivo() => estado == EstadoEstudiante.activo;

  @override
  Estudiante copiarPerfil({String? telefono, String? fotoUrl}) => Estudiante(
        uid: uid,
        cedula: cedula,
        nombre: nombre,
        correo: correo,
        telefono: telefono ?? this.telefono,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        carnet: carnet,
        estado: estado,
        solvente: solvente,
        carrera: carrera,
      );

  @override
  Map<String, dynamic> aMapa() => {
        ...super.aMapa(),
        'carnet': carnet,
        'estado': estado.name,
        'solvente': solvente,
        'carrera': carrera,
      };

  factory Estudiante.desdeMapa(String uid, Map<String, dynamic> mapa) => Estudiante(
        uid: uid,
        cedula: mapa['cedula'] as String,
        nombre: mapa['nombre'] as String,
        correo: mapa['correo'] as String,
        telefono: mapa['telefono'] as String? ?? '',
        fotoUrl: mapa['fotoUrl'] as String? ?? '',
        carnet: mapa['carnet'] as String,
        estado: EstadoEstudiante.values.byName(mapa['estado'] as String? ?? 'activo'),
        solvente: mapa['solvente'] as bool? ?? false,
        carrera: mapa['carrera'] as String? ?? '',
      );
}

/// Entrenador a cargo de una o más disciplinas.
class Entrenador extends Persona {
  const Entrenador({
    required super.uid,
    required super.cedula,
    required super.nombre,
    required super.correo,
    super.telefono,
    super.fotoUrl,
    required this.especialidad,
    this.aniosExperiencia = 0,
  });

  final String especialidad;
  final int aniosExperiencia;

  @override
  Rol get rol => Rol.entrenador;

  @override
  Entrenador copiarPerfil({String? telefono, String? fotoUrl}) => Entrenador(
        uid: uid,
        cedula: cedula,
        nombre: nombre,
        correo: correo,
        telefono: telefono ?? this.telefono,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        especialidad: especialidad,
        aniosExperiencia: aniosExperiencia,
      );

  @override
  Map<String, dynamic> aMapa() => {
        ...super.aMapa(),
        'especialidad': especialidad,
        'aniosExperiencia': aniosExperiencia,
      };

  factory Entrenador.desdeMapa(String uid, Map<String, dynamic> mapa) => Entrenador(
        uid: uid,
        cedula: mapa['cedula'] as String,
        nombre: mapa['nombre'] as String,
        correo: mapa['correo'] as String,
        telefono: mapa['telefono'] as String? ?? '',
        fotoUrl: mapa['fotoUrl'] as String? ?? '',
        especialidad: mapa['especialidad'] as String? ?? '',
        aniosExperiencia: (mapa['aniosExperiencia'] as num?)?.toInt() ?? 0,
      );
}

/// Personal de la Coordinación de Deportes que administra el sistema.
class Administrador extends Persona {
  const Administrador({
    required super.uid,
    required super.cedula,
    required super.nombre,
    required super.correo,
    super.telefono,
    super.fotoUrl,
    this.cargo = '',
  });

  final String cargo;

  @override
  Rol get rol => Rol.administrador;

  @override
  Administrador copiarPerfil({String? telefono, String? fotoUrl}) => Administrador(
        uid: uid,
        cedula: cedula,
        nombre: nombre,
        correo: correo,
        telefono: telefono ?? this.telefono,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        cargo: cargo,
      );

  @override
  Map<String, dynamic> aMapa() => {...super.aMapa(), 'cargo': cargo};

  factory Administrador.desdeMapa(String uid, Map<String, dynamic> mapa) => Administrador(
        uid: uid,
        cedula: mapa['cedula'] as String,
        nombre: mapa['nombre'] as String,
        correo: mapa['correo'] as String,
        telefono: mapa['telefono'] as String? ?? '',
        fotoUrl: mapa['fotoUrl'] as String? ?? '',
        cargo: mapa['cargo'] as String? ?? '',
      );
}
