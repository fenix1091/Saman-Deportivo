import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/deporte.dart';
import '../models/resena.dart';
import '../repositories/deporte_repository.dart';

/// Detalle de un deporte: entrenador, horarios, cupos en tiempo real, costo y
/// reseñas (CU-06, RF-06).
class DetalleDeporteViewModel extends ChangeNotifier {
  DetalleDeporteViewModel(this._repositorio, this.codigo) {
    _subDeporte = _repositorio.deporte(codigo).listen((deporte) {
      _deporte = deporte;
      _seguirProfesor(deporte?.entrenadorId ?? '');
      _cargando = false;
      _error = null;
      _notificar();
    }, onError: _alFallar);
    _subResenas = _repositorio.resenas(codigo).listen((resenas) {
      _resenas = resenas;
      _notificar();
    }, onError: (_) {});
    _cargarHorarios();
    _repositorio.registrarConsulta(codigo);
  }

  /// Reseñas que se muestran en el detalle (las más recientes).
  static const maxResenas = 5;

  final DeporteRepository _repositorio;
  final String codigo;
  late final StreamSubscription<Deporte?> _subDeporte;
  late final StreamSubscription<List<Resena>> _subResenas;
  StreamSubscription<List<Resena>>? _subProfesor;
  String _profesorSeguido = '';
  List<Resena> _resenasProfesor = const [];
  bool _desechado = false;

  Deporte? _deporte;
  List<Horario> _horarios = const [];
  List<Resena> _resenas = const [];
  bool _cargando = true;
  String? _error;

  bool get cargando => _cargando;
  String? get error => _error;
  Deporte? get deporte => _deporte;

  /// Un deporte que no existe o que el administrador dio de baja no se muestra.
  bool get noDisponible => !_cargando && _error == null && (_deporte == null || !_deporte!.activo);
  List<Horario> get horarios => _horarios;

  /// Si ya se leyeron los horarios (sin conexión pueden no estar disponibles).
  bool get horariosCargados => _horariosCargados;
  bool _horariosCargados = false;
  List<Resena> get resenasRecientes => _resenas.take(maxResenas).toList();
  int get totalResenas => _resenas.length;

  /// Promedio de 1 a 5 estrellas, o `null` si aún no hay reseñas.
  double? get calificacionPromedio {
    if (_resenas.isEmpty) return null;
    final suma = _resenas.fold<int>(0, (total, r) => total + r.calificacion);
    return suma / _resenas.length;
  }

  /// Reseñas del profesor asignado, de todas sus disciplinas (las más recientes).
  List<Resena> get resenasProfesorRecientes => _resenasProfesor.take(maxResenas).toList();
  int get totalResenasProfesor => _resenasProfesor.length;

  /// Promedio de 1 a 5 estrellas del profesor, o `null` si nadie lo ha calificado.
  double? get calificacionProfesor => promedioProfesor(_resenasProfesor);

  static double? promedioProfesor(List<Resena> resenas) {
    final notas = [for (final r in resenas) if (r.calificacionEntrenador != null) r.calificacionEntrenador!];
    if (notas.isEmpty) return null;
    return notas.reduce((a, b) => a + b) / notas.length;
  }

  void _seguirProfesor(String uid) {
    if (uid == _profesorSeguido) return;
    _profesorSeguido = uid;
    _subProfesor?.cancel();
    _subProfesor = null;
    _resenasProfesor = const [];
    if (uid.isEmpty) return;
    _subProfesor = _repositorio.resenasDeEntrenador(uid).listen((resenas) {
      _resenasProfesor = resenas;
      _notificar();
    }, onError: (_) {});
  }

  Future<void> _cargarHorarios() async {
    try {
      _horarios = await _repositorio.horarios(codigo);
      _horariosCargados = true;
      _notificar();
    } catch (_) {
      // El resto del detalle se muestra igual; la sección de horarios queda vacía.
    }
  }

  void _alFallar(Object e) {
    _cargando = false;
    _error = e is CatalogoException ? e.mensaje : 'No pudimos cargar el deporte. Inténtalo de nuevo.';
    _notificar();
  }

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    _subDeporte.cancel();
    _subResenas.cancel();
    _subProfesor?.cancel();
    super.dispose();
  }
}
