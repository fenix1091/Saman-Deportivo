import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/validadores.dart';
import '../models/persona.dart';
import '../repositories/auth_repository.dart';

/// Estado de la sesión y acciones de autenticación.
///
/// Las vistas de registro e inicio de sesión lo usan, y el enrutador lo escucha
/// para proteger las rutas según el rol.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repositorio) : _usuario = _repositorio.usuarioActual {
    _suscripcion = _repositorio.cambiosDeSesion.listen((usuario) {
      _usuario = usuario;
      notifyListeners();
    });
    _restaurarSesion();
  }

  final AuthRepository _repositorio;
  late final StreamSubscription<Persona?> _suscripcion;

  Persona? _usuario;
  bool _listo = false;
  bool _desechado = false;
  bool _cargando = false;
  ErrorAuth? _error;

  Persona? get usuario => _usuario;
  bool get haySesion => _usuario != null;

  /// `false` mientras se recupera la sesión guardada; el enrutador espera a que termine.
  bool get listo => _listo;
  bool get cargando => _cargando;
  ErrorAuth? get error => _error;

  Future<void> _restaurarSesion() async {
    final usuario = await _repositorio.restaurarSesion();
    if (_desechado) return;
    _usuario = _repositorio.usuarioActual ?? usuario;
    _listo = true;
    notifyListeners();
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Registra un estudiante (CU-01). Devuelve `true` si la cuenta se creó.
  Future<bool> registrar({
    required String cedula,
    required String nombre,
    required String correo,
    required String carnet,
    required String clave,
  }) {
    return _ejecutar(() => _repositorio.registrarEstudiante(
          cedula: Validadores.normalizarCedula(cedula),
          nombre: nombre,
          correo: correo,
          carnet: carnet.trim(),
          clave: clave,
        ));
  }

  /// Inicia sesión con correo y contraseña (CU-02). Devuelve `true` si las credenciales son válidas.
  Future<bool> iniciarSesion(String correo, String clave) {
    return _ejecutar(() => _repositorio.iniciarSesion(correo.trim(), clave));
  }

  /// Envía el enlace para restablecer la contraseña (CU-02, A3).
  Future<bool> recuperarClave(String correo) {
    return _ejecutar(() => _repositorio.enviarRecuperacionClave(correo.trim()));
  }

  Future<void> cerrarSesion() => _repositorio.cerrarSesion();

  /// Pantalla inicial de cada rol después de iniciar sesión.
  static String rutaInicio(Rol rol) => switch (rol) {
        Rol.estudiante => '/catalogo',
        Rol.entrenador => '/entrenador/mis-deportes',
        Rol.administrador => '/admin/dashboard',
      };

  Future<bool> _ejecutar(Future<Object?> Function() accion) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      await accion();
      // El stream avisa en la siguiente vuelta del bucle de eventos; se lee ya para
      // que la vista pueda navegar según el rol apenas termina la acción.
      _usuario = _repositorio.usuarioActual;
      return true;
    } on AuthException catch (e) {
      _error = e.error;
      return false;
    } catch (_) {
      _error = ErrorAuth.desconocido;
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _desechado = true;
    _suscripcion.cancel();
    super.dispose();
  }
}
