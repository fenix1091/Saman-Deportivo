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
  }

  final AuthRepository _repositorio;
  late final StreamSubscription<Persona?> _suscripcion;

  Persona? _usuario;
  bool _cargando = false;
  ErrorAuth? _error;

  Persona? get usuario => _usuario;
  bool get haySesion => _usuario != null;
  bool get cargando => _cargando;
  ErrorAuth? get error => _error;

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

  Future<bool> _ejecutar(Future<Object?> Function() accion) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      await accion();
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
    _suscripcion.cancel();
    super.dispose();
  }
}
