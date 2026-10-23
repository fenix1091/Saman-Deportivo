import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../models/persona.dart';
import 'auth_repository.dart';

/// Implementación en memoria de [AuthRepository] para desarrollar y probar sin Firebase.
///
/// Imita las reglas de Firebase Auth que usa la app: correo único, bloqueo tras
/// 5 intentos fallidos y una pequeña espera en cada operación. Los datos se pierden
/// al recargar la página.
class AuthRepositoryLocal implements AuthRepository {
  AuthRepositoryLocal({this.latencia = const Duration(milliseconds: 400)});

  /// Repositorio con una cuenta de prueba por rol (ver el README).
  factory AuthRepositoryLocal.conDatosDePrueba({Duration latencia = const Duration(milliseconds: 400)}) {
    final repo = AuthRepositoryLocal(latencia: latencia);
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
    // Sin Storage, la foto se guarda como data URL dentro del propio perfil.
    final tipo = extension == 'png' ? 'png' : (extension == 'webp' ? 'webp' : 'jpeg');
    return 'data:image/$tipo;base64,${base64Encode(bytes)}';
  }
}
