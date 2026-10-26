import 'dart:async';

import 'package:flutter/material.dart';
import '../models/inscripcion.dart';
import '../models/resena.dart';
import '../repositories/inscripcion_repository.dart';

class MisInscripcionesViewModel extends ChangeNotifier {
  MisInscripcionesViewModel(this._repository);

  final InscripcionRepository _repository;
  StreamSubscription<List<Inscripcion>>? _suscripcion;

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

    _suscripcion?.cancel();
    _suscripcion = _repository.inscripcionesDe(estudianteId).listen(
      (lista) {
        _inscripciones = lista;
        _cargando = false;
        notifyListeners();
      },
      onError: (e) {
        _error = _mensaje(e, 'No se pudieron cargar tus inscripciones.');
        _cargando = false;
        notifyListeners();
      },
    );
  }

  /// Cancela la inscripción mediante la transacción de Firestore
  Future<bool> cancelarInscripcion(
      String inscripcionId, String deporteCodigo) async {
    try {
      await _repository.cancelar(inscripcionId, deporteCodigo);
      return true;
    } catch (e) {
      _error = _mensaje(e, 'No se pudo cancelar la inscripción.');
      notifyListeners();
      return false;
    }
  }

  /// Publica o actualiza una reseña
  Future<bool> publicarResena({
    required String deporteCodigo,
    required String estudianteId,
    required int calificacion,
    required String comentario,
    String autor = '',
  }) async {
    try {
      await _repository.publicarResena(Resena(
        id: '${deporteCodigo}_$estudianteId',
        estudianteId: estudianteId,
        autor: autor,
        deporteCodigo: deporteCodigo,
        calificacion: calificacion,
        comentario: comentario,
        fecha: DateTime.now(),
      ));
      return true;
    } catch (e) {
      _error = _mensaje(e, 'No se pudo publicar la reseña.');
      notifyListeners();
      return false;
    }
  }

  String _mensaje(Object e, String general) => e is InscripcionException ? e.mensaje : general;

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }
}
