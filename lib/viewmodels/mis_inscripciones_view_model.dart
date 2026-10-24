import 'package:flutter/material.dart';
import '../models/inscripcion.dart';
import '../repositories/inscripcion_repository.dart';

class MisInscripcionesViewModel extends ChangeNotifier {
  final InscripcionRepository _repository = InscripcionRepository();

  List<Inscripcion> _inscripciones = [];
  bool _cargando = true;
  String? _error;

  List<Inscripcion> get inscripciones => _inscripciones;
  bool get cargando => _cargando;
  String? get error => _error;

  /// Obtiene solo las inscripciones activas (pendientePago o confirmada)
  List<Inscripcion> get vigentes =>
      _inscripciones.where((i) => i.estaVigente()).toList();

  /// Obtiene el historial (cancelada, rechazada, expirada)
  List<Inscripcion> get historial =>
      _inscripciones.where((i) => !i.estaVigente()).toList();

  /// Escucha en tiempo real las inscripciones del estudiante autenticado
  void escucharInscripciones(String estudianteId) {
    _cargando = true;
    _error = null;
    notifyListeners();

    _repository.obtenerInscripcionesEstudiante(estudianteId).listen(
      (lista) {
        _inscripciones = lista;
        _cargando = false;
        notifyListeners();
      },
      onError: (e) {
        _error = 'Error al cargar las inscripciones: $e';
        _cargando = false;
        notifyListeners();
      },
    );
  }

  /// Cancela la inscripción mediante la transacción de Firestore
  Future<bool> cancelarInscripcion(
      String inscripcionId, String deporteCodigo) async {
    try {
      await _repository.cancelarInscripcion(inscripcionId, deporteCodigo);
      return true;
    } catch (e) {
      _error = 'No se pudo cancelar la inscripción: $e';
      notifyListeners();
      return false;
    }
  }
}
