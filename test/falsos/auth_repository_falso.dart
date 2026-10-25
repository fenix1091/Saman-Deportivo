import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/auth_repository.dart';

/// [AuthRepository] en memoria para las pruebas, sin conexión a Firebase.
///
/// Imita las reglas de Firebase Auth y de firestore.rules que usa la app: correo,
/// cédula y carnet únicos, y bloqueo tras 5 intentos fallidos.
class AuthRepositoryFalso implements AuthRepository {
  AuthRepositoryFalso({this.latencia = Duration.zero});

  /// Repositorio con una cuenta de prueba por rol (ver el README).
  factory AuthRepositoryFalso.conDatosDePrueba({Duration latencia = Duration.zero}) {
    final repo = AuthRepositoryFalso(latencia: latencia);
    repo._agregar(
      const Estudiante(
        uid: 'est-demo',
        cedula: 'V-30111222',
        nombre: 'Estudiante Prueba',
        correo: 'estudiante@correo.unimet.edu.ve',
        carnet: '20231110001',
        carrera: 'Ingeniería de Sistemas',
      ),
      'Estudiante123',
    );
    repo._agregar(
      const Entrenador(
        uid: 'ent-demo',
        cedula: 'V-20333444',
        nombre: 'Entrenador Prueba',
        correo: 'entrenador@unimet.edu.ve',
        especialidad: 'Fútbol',
        aniosExperiencia: 8,
      ),
      'Entrenador123',
    );
    repo._agregar(
      const Administrador(
        uid: 'adm-demo',
        cedula: 'V-15555666',
        nombre: 'Administrador Prueba',
        correo: 'admin@unimet.edu.ve',
        cargo: 'Coordinación de Deportes',
      ),
      'Admin1234',
    );
    return repo;
  }

  static const maxIntentos = 5;

  final Duration latencia;
  final _usuarios = <String, Persona>{};
  final _claves = <String, String>{};
  final _intentosFallidos = <String, int>{};
  final _sesion = StreamController<Persona?>.broadcast();
  Persona? _actual;
  int _siguienteId = 1;

  /// Agrega otra cuenta, por ejemplo un estudiante solvente.
  void agregarCuenta(Persona usuario, String clave) => _agregar(usuario, clave);

  void _agregar(Persona usuario, String clave) {
    _usuarios[usuario.uid] = usuario;
    _claves[usuario.uid] = clave;
  }

  Persona? _buscarPorCorreo(String correo) {
    final c = correo.trim().toLowerCase();
    for (final u in _usuarios.values) {
      if (u.correo.toLowerCase() == c) return u;
    }
    return null;
  }

  void _abrirSesion(Persona? usuario) {
    _actual = usuario;
    _sesion.add(usuario);
  }

  @override
  Persona? get usuarioActual => _actual;

  @override
  Future<Persona?> restaurarSesion() async => _actual;

  @override
  Stream<Persona?> get cambiosDeSesion => _sesion.stream;

  @override
  Future<Estudiante> registrarEstudiante({
    required String cedula,
    required String nombre,
    required String correo,
    required String carnet,
    required String clave,
  }) async {
    await Future<void>.delayed(latencia);
    if (_buscarPorCorreo(correo) != null) throw const AuthException(ErrorAuth.correoYaRegistrado);
    if (_usuarios.values.any((u) => u.cedula == cedula)) {
      throw const AuthException(ErrorAuth.cedulaYaRegistrada);
    }
    if (_usuarios.values.any((u) => u is Estudiante && u.carnet == carnet)) {
      throw const AuthException(ErrorAuth.carnetYaRegistrado);
    }
    final estudiante = Estudiante(
      uid: 'local-${_siguienteId++}',
      cedula: cedula,
      nombre: nombre.trim(),
      correo: correo.trim().toLowerCase(),
      carnet: carnet,
    );
    _agregar(estudiante, clave);
    _abrirSesion(estudiante);
    return estudiante;
  }

  @override
  Future<Persona> iniciarSesion(String correo, String clave) async {
    await Future<void>.delayed(latencia);
    final c = correo.trim().toLowerCase();
    if ((_intentosFallidos[c] ?? 0) >= maxIntentos) {
      throw const AuthException(ErrorAuth.demasiadosIntentos);
    }
    final usuario = _buscarPorCorreo(c);
    if (usuario == null || _claves[usuario.uid] != clave) {
      _intentosFallidos[c] = (_intentosFallidos[c] ?? 0) + 1;
      throw const AuthException(ErrorAuth.credencialesInvalidas);
    }
    _intentosFallidos.remove(c);
    _abrirSesion(usuario);
    return usuario;
  }

  @override
  Future<void> enviarRecuperacionClave(String correo) async {
    // Igual que Firebase: no revela si el correo existe.
    await Future<void>.delayed(latencia);
  }

  @override
  Future<void> cerrarSesion() async {
    _abrirSesion(null);
  }

  @override
  Future<Persona> actualizarPerfil(Persona usuario) async {
    await Future<void>.delayed(latencia);
    _usuarios[usuario.uid] = usuario;
    if (_actual?.uid == usuario.uid) _abrirSesion(usuario);
    return usuario;
  }

  @override
  Future<String> subirFotoPerfil(String uid, Uint8List bytes, String extension) async {
    await Future<void>.delayed(latencia);
    final tipo = extension == 'png' ? 'png' : (extension == 'webp' ? 'webp' : 'jpeg');
    return 'data:image/$tipo;base64,${base64Encode(bytes)}';
  }
}
