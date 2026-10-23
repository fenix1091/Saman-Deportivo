import 'dart:typed_data';

import '../models/persona.dart';

/// Contrato de acceso a la autenticación y a los datos del usuario.
///
/// Los ViewModels solo conocen esta interfaz (patrón Repositorio). Mientras no esté
/// configurado Firebase se usa [AuthRepositoryLocal]; después se agrega una
/// implementación con Firebase Auth, Firestore y Storage sin tocar las vistas.
abstract class AuthRepository {
  /// Usuario con la sesión abierta, o `null`.
  Persona? get usuarioActual;

  /// Emite el usuario cada vez que se abre o se cierra la sesión.
  Stream<Persona?> get cambiosDeSesion;

  /// Crea la cuenta de un estudiante y abre su sesión (CU-01).
  Future<Estudiante> registrarEstudiante({
    required String cedula,
    required String nombre,
    required String correo,
    required String carnet,
    required String clave,
  });

  /// Verifica las credenciales y devuelve el usuario con su rol (CU-02).
  Future<Persona> iniciarSesion(String correo, String clave);

  /// Envía el enlace para restablecer la contraseña (CU-02, A3).
  Future<void> enviarRecuperacionClave(String correo);

  Future<void> cerrarSesion();

  /// Guarda los datos editables del perfil (CU-03).
  Future<Persona> actualizarPerfil(Persona usuario);

  /// Sube la foto de perfil y devuelve su URL (CU-03).
  Future<String> subirFotoPerfil(String uid, Uint8List bytes, String extension);
}

/// Motivos por los que puede fallar una operación de autenticación.
enum ErrorAuth {
  credencialesInvalidas('Correo o contraseña inválidos.'),
  correoYaRegistrado('Ya existe una cuenta con ese correo.'),
  cedulaYaRegistrada('Ya existe una cuenta con esa cédula.'),
  carnetYaRegistrado('Ya existe una cuenta con ese carnet.'),
  demasiadosIntentos('Demasiados intentos fallidos. Espera unos minutos e inténtalo de nuevo.'),
  sinConexion('No hay conexión. Revisa tu internet e inténtalo de nuevo.'),
  desconocido('Ocurrió un error inesperado. Inténtalo de nuevo.');

  const ErrorAuth(this.mensaje);

  final String mensaje;

  /// Los errores de cuenta duplicada ofrecen "Iniciar sesión" o "Recuperar contraseña" (CU-01, A2).
  bool get esCuentaExistente => this == correoYaRegistrado || this == cedulaYaRegistrada || this == carnetYaRegistrado;
}

class AuthException implements Exception {
  const AuthException(this.error);

  final ErrorAuth error;

  String get mensaje => error.mensaje;

  @override
  String toString() => 'AuthException(${error.name})';
}
