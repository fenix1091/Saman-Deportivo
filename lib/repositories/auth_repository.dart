import 'dart:typed_data';

import '../models/persona.dart';

/// Contrato de acceso a la autenticación y a los datos del usuario.
///
/// Los ViewModels solo conocen esta interfaz (patrón Repositorio). La app usa
/// [AuthRepositoryFirebase]; las pruebas usan un repositorio falso en memoria.
abstract class AuthRepository {
  /// Usuario con la sesión abierta, o `null`.
  Persona? get usuarioActual;

  /// Espera a que Firebase recupere la sesión guardada en el dispositivo
  /// (por ejemplo, al recargar la PWA) y devuelve el usuario, o `null`.
  Future<Persona?> restaurarSesion();

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

  /// Guarda el teléfono y la foto del perfil (CU-03).
  Future<Persona> actualizarPerfil(Persona usuario);

  /// Prepara la foto de perfil para guardarla y devuelve la dirección con la que se muestra (CU-03).
  Future<String> subirFotoPerfil(String uid, Uint8List bytes, String extension);
}

/// Motivos por los que puede fallar una operación de autenticación.
enum ErrorAuth {
  credencialesInvalidas('Correo o contraseña inválidos.'),
  correoYaRegistrado('Ya existe una cuenta con ese correo.'),
  cedulaYaRegistrada('Ya existe una cuenta con esa cédula.'),
  carnetYaRegistrado('Ya existe una cuenta con ese carnet.'),
  claveDebil('La contraseña es muy débil. Usa al menos 8 caracteres, con letras y números.'),
  demasiadosIntentos('Demasiados intentos fallidos. Espera unos minutos e inténtalo de nuevo.'),
  perfilNoEncontrado('No encontramos los datos de tu cuenta. Escribe a la Coordinación de Deportes.'),
  sinPermiso('No tienes permiso para hacer esto.'),
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
