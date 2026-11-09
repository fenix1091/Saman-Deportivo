import 'package:flutter/foundation.dart';

import '../repositories/auth_repository.dart';

/// Qué pide el enlace que llegó por correo.
enum ModoAccion { restablecerClave, verificarCorreo, desconocido }

/// Paso en el que está la pantalla del enlace.
enum EstadoAccion { comprobando, pidiendoClave, listo, invalido }

/// Atiende los enlaces de los correos de Firebase dentro de la propia app:
/// crear una contraseña nueva (CU-02, A3) y verificar el correo del registro.
class AccionCorreoViewModel extends ChangeNotifier {
  AccionCorreoViewModel(this._repositorio, {required String? modo, required String? codigo})
      : codigo = codigo ?? '',
        modo = switch (modo) {
          'resetPassword' => ModoAccion.restablecerClave,
          'verifyEmail' => ModoAccion.verificarCorreo,
          _ => ModoAccion.desconocido,
        } {
    _comprobar();
  }

  final AuthRepository _repositorio;
  final String codigo;
  final ModoAccion modo;

  EstadoAccion _estado = EstadoAccion.comprobando;
  String _correo = '';
  bool _guardando = false;
  String? _error;
  bool _desechado = false;

  EstadoAccion get estado => _estado;

  /// Correo de la cuenta a la que pertenece el enlace de contraseña.
  String get correo => _correo;
  bool get guardando => _guardando;
  String? get error => _error;

  Future<void> _comprobar() async {
    if (codigo.isEmpty || modo == ModoAccion.desconocido) {
      _estado = EstadoAccion.invalido;
      _error = ErrorAuth.enlaceInvalido.mensaje;
      return;
    }
    try {
      if (modo == ModoAccion.restablecerClave) {
        _correo = await _repositorio.correoDelEnlace(codigo);
        _estado = EstadoAccion.pidiendoClave;
      } else {
        await _repositorio.verificarCorreo(codigo);
        _estado = EstadoAccion.listo;
      }
    } on AuthException catch (e) {
      _estado = EstadoAccion.invalido;
      _error = e.mensaje;
    } catch (_) {
      _estado = EstadoAccion.invalido;
      _error = ErrorAuth.desconocido.mensaje;
    }
    _notificar();
  }

  /// Guarda la contraseña nueva. Devuelve `true` si quedó cambiada.
  Future<bool> guardarClave(String clave) async {
    if (_guardando || _estado != EstadoAccion.pidiendoClave) return false;
    _guardando = true;
    _error = null;
    _notificar();
    try {
      await _repositorio.cambiarClaveConEnlace(codigo, clave);
      _estado = EstadoAccion.listo;
      return true;
    } on AuthException catch (e) {
      _error = e.mensaje;
      if (e.error == ErrorAuth.enlaceInvalido) _estado = EstadoAccion.invalido;
      return false;
    } catch (_) {
      _error = ErrorAuth.desconocido.mensaje;
      return false;
    } finally {
      _guardando = false;
      _notificar();
    }
  }

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}
