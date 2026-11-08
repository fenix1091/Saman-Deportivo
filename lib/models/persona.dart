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
    this.nacionalidad = 'V',
    required this.cedula,
    required this.nombre,
    required this.correo,
    this.telefono = '',
    this.fotoUrl = '',
  });

  final String uid;

  /// Letra de la cédula: `V` (venezolano) o `E` (extranjero).
  final String nacionalidad;

  /// Número de cédula. Se guarda como número para que el administrador pueda
  /// ordenar y filtrar por rangos (por ejemplo, `cedula >= 30000000`).
  final int cedula;
  final String nombre;
  final String correo;
  final String telefono;
  final String fotoUrl;

  Rol get rol;

  /// Cédula con su letra, como se muestra y como se usa en el índice `cedulas/{V-31985476}`.
  String get cedulaTexto => '$nacionalidad-$cedula';

  /// Devuelve una copia con los datos editables del perfil cambiados.
  Persona copiarPerfil({String? nombre, String? telefono, String? fotoUrl});

  /// Convierte el usuario al documento que se guarda en Firestore.
  Map<String, dynamic> aMapa() => {
        'rol': rol.name,
        'nacionalidad': nacionalidad,
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

/// Lee la cédula de un documento. Acepta el formato actual (número) y el de las
/// cuentas creadas antes del cambio, que la guardaban como texto ("V-31985476").
int leerCedula(Object? valor) => switch (valor) {
      num n => n.toInt(),
      String s => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 0,
      _ => 0,
    };

/// Lee la letra de la cédula: del campo `nacionalidad` o, en documentos viejos, del texto de la cédula.
String leerNacionalidad(Map<String, dynamic> mapa) {
  final letra = mapa['nacionalidad'];
  if (letra is String && letra.isNotEmpty) return letra;
  final cedula = mapa['cedula'];
  return cedula is String && cedula.toUpperCase().startsWith('E') ? 'E' : 'V';
}

/// Estudiante de la UNIMET que se inscribe en las disciplinas.
class Estudiante extends Persona {
  const Estudiante({
    required super.uid,
    super.nacionalidad,
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
  Estudiante copiarPerfil({String? nombre, String? telefono, String? fotoUrl}) => Estudiante(
        uid: uid,
        nacionalidad: nacionalidad,
        cedula: cedula,
        nombre: nombre ?? this.nombre,
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
        nacionalidad: leerNacionalidad(mapa),
        cedula: leerCedula(mapa['cedula']),
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
    super.nacionalidad,
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
  Entrenador copiarPerfil({String? nombre, String? telefono, String? fotoUrl}) => Entrenador(
        uid: uid,
        nacionalidad: nacionalidad,
        cedula: cedula,
        nombre: nombre ?? this.nombre,
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
        nacionalidad: leerNacionalidad(mapa),
        cedula: leerCedula(mapa['cedula']),
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
    super.nacionalidad,
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
  Administrador copiarPerfil({String? nombre, String? telefono, String? fotoUrl}) => Administrador(
        uid: uid,
        nacionalidad: nacionalidad,
        cedula: cedula,
        nombre: nombre ?? this.nombre,
        correo: correo,
        telefono: telefono ?? this.telefono,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        cargo: cargo,
      );

  @override
  Map<String, dynamic> aMapa() => {...super.aMapa(), 'cargo': cargo};

  factory Administrador.desdeMapa(String uid, Map<String, dynamic> mapa) => Administrador(
        uid: uid,
        nacionalidad: leerNacionalidad(mapa),
        cedula: leerCedula(mapa['cedula']),
        nombre: mapa['nombre'] as String,
        correo: mapa['correo'] as String,
        telefono: mapa['telefono'] as String? ?? '',
        fotoUrl: mapa['fotoUrl'] as String? ?? '',
        cargo: mapa['cargo'] as String? ?? '',
      );
}
