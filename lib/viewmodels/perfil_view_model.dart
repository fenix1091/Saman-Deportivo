import 'package:flutter/foundation.dart';

import '../models/persona.dart';
import '../repositories/auth_repository.dart';

/// Edición del perfil del usuario con la sesión abierta (CU-03, RF-03).
///
/// Solo el teléfono y la foto son editables; cédula, correo y los datos del rol
/// los muestra la vista en modo lectura.
class PerfilViewModel extends ChangeNotifier {
  PerfilViewModel(this._repositorio);

  /// La foto se guarda dentro del documento del usuario, que en Firestore no puede pasar de 1 MB.
  static const tamanoMaximoFoto = 700 * 1024;
  static const formatosFoto = {'jpg', 'jpeg', 'png', 'webp'};

  final AuthRepository _repositorio;

  Uint8List? _fotoNueva;
  String _extensionFoto = '';
  bool _guardando = false;
  String? _error;

  Persona? get usuario => _repositorio.usuarioActual;
  Uint8List? get fotoNueva => _fotoNueva;
  bool get guardando => _guardando;
  String? get error => _error;

  /// Elige la foto que se subirá al guardar. Si no cumple el tamaño o el formato,
  /// se conserva la anterior y se informa el motivo (CU-03, A1).
  bool elegirFoto(Uint8List bytes, String nombreArchivo) {
    final extension = nombreArchivo.contains('.') ? nombreArchivo.split('.').last.toLowerCase() : '';
    if (!formatosFoto.contains(extension)) {
      _error = 'La foto debe ser JPG, PNG o WEBP.';
    } else if (bytes.length > tamanoMaximoFoto) {
      _error = 'La foto es demasiado pesada. Elige otra o recórtala.';
    } else {
      _fotoNueva = bytes;
      _extensionFoto = extension;
      _error = null;
    }
    notifyListeners();
    return _error == null;
  }

  /// Sube la foto si hay una nueva y guarda el teléfono. Devuelve `true` si se guardó.
  Future<bool> guardar({required String telefono}) async {
    final actual = usuario;
    if (actual == null) return false;
    _guardando = true;
    _error = null;
    notifyListeners();
    try {
      var fotoUrl = actual.fotoUrl;
      if (_fotoNueva != null) {
        fotoUrl = await _repositorio.subirFotoPerfil(actual.uid, _fotoNueva!, _extensionFoto);
      }
      await _repositorio.actualizarPerfil(
        actual.copiarPerfil(telefono: telefono.replaceAll(RegExp(r'[\s-]'), ''), fotoUrl: fotoUrl),
      );
      _fotoNueva = null;
      return true;
    } on AuthException catch (e) {
      _error = e.mensaje;
      return false;
    } catch (_) {
      _error = ErrorAuth.desconocido.mensaje;
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }
}
