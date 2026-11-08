import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/asistencia.dart';
import '../repositories/asistencia_repository.dart';

/// Resumen de una sesión de entrenamiento ya registrada (RF-16).
class SesionRegistrada {
  const SesionRegistrada({required this.fecha, required this.presentes, required this.total});

  final DateTime fecha;
  final int presentes;
  final int total;
}

/// Toma de asistencia e historial de una disciplina (CU-14, CU-15; RF-14 a RF-16).
///
/// Escucha la nómina y las asistencias en tiempo real; al cambiar la fecha carga
/// lo ya registrado ese día para que el entrenador lo corrija en vez de duplicarlo.
class AsistenciaViewModel extends ChangeNotifier {
  AsistenciaViewModel(this._repositorio, this.codigo, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now {
    _fecha = _soloDia(_reloj());
    _subNomina = _repositorio.nomina(codigo).listen((lista) {
      _nomina = lista;
      _cargandoNomina = false;
      _rellenarMarcas();
      _notificar();
    }, onError: _fallar);
    _subAsistencias = _repositorio.asistenciasDe(codigo).listen((lista) {
      _asistencias = lista;
      _cargandoAsistencias = false;
      _rellenarMarcas();
      _notificar();
    }, onError: _fallar);
  }

  final AsistenciaRepository _repositorio;
  final String codigo;
  final DateTime Function() _reloj;

  late final StreamSubscription<List<EstudianteInscrito>> _subNomina;
  late final StreamSubscription<List<Asistencia>> _subAsistencias;
  bool _desechado = false;

  List<EstudianteInscrito> _nomina = const [];
  List<Asistencia> _asistencias = const [];
  late DateTime _fecha;
  final _marcas = <String, bool>{};
  bool _editado = false;
  bool _cargandoNomina = true;
  bool _cargandoAsistencias = true;
  bool _guardando = false;
  String? _error;
  String? _aviso;

  List<EstudianteInscrito> get nomina => _nomina;
  DateTime get fecha => _fecha;
  bool get cargando => _cargandoNomina || _cargandoAsistencias;
  bool get guardando => _guardando;
  String? get error => _error;

  /// Mensaje de éxito de la última operación; se limpia al leerlo.
  String? tomarAviso() {
    final a = _aviso;
    _aviso = null;
    return a;
  }

  /// Si el estudiante está marcado presente en la fecha elegida.
  bool presente(String uid) => _marcas[uid] ?? false;

  /// La fecha elegida ya tiene asistencia registrada.
  bool get fechaRegistrada => _asistencias.any((a) => _soloDia(a.fecha) == _fecha);

  int get totalPresentes => _marcas.values.where((p) => p).length;

  bool get puedeGuardar => !_guardando && _nomina.isNotEmpty && !cargando;

  void marcar(String uid, bool presente) {
    _marcas[uid] = presente;
    _editado = true;
    _notificar();
  }

  void marcarTodos(bool presente) {
    for (final e in _nomina) {
      _marcas[e.uid] = presente;
    }
    _editado = true;
    _notificar();
  }

  void cambiarFecha(DateTime nueva) {
    _fecha = _soloDia(nueva);
    _editado = false;
    _marcas.clear();
    _rellenarMarcas();
    _notificar();
  }

  /// Guarda la asistencia de la fecha elegida para toda la nómina (RF-15).
  Future<bool> guardar() async {
    if (!puedeGuardar) return false;
    _guardando = true;
    _error = null;
    _notificar();
    try {
      await _repositorio.registrarAsistencia(
        codigo: codigo,
        fecha: _fecha,
        presentes: {for (final e in _nomina) e.uid: _marcas[e.uid] ?? false},
      );
      _editado = false;
      _aviso = 'Asistencia del ${_formato(_fecha)} guardada: $totalPresentes de ${_nomina.length} presentes.';
      return true;
    } on AsistenciaException catch (e) {
      _error = e.mensaje;
      return false;
    } catch (_) {
      _error = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
      return false;
    } finally {
      _guardando = false;
      _notificar();
    }
  }

  /// Porcentaje de asistencia de un estudiante sobre las sesiones registradas (RF-16).
  double porcentaje(String uid) {
    final suyas = _asistencias.where((a) => a.estudianteId == uid).toList();
    if (suyas.isEmpty) return 0;
    final presentes = suyas.where((a) => a.estado == EstadoAsistencia.presente).length;
    return presentes * 100 / suyas.length;
  }

  int sesionesDe(String uid) => _asistencias.where((a) => a.estudianteId == uid).length;

  int asistidasDe(String uid) =>
      _asistencias.where((a) => a.estudianteId == uid && a.estado == EstadoAsistencia.presente).length;

  /// Sesiones registradas, de la más reciente a la más antigua.
  List<SesionRegistrada> get sesiones {
    final porDia = <DateTime, List<Asistencia>>{};
    for (final a in _asistencias) {
      porDia.putIfAbsent(_soloDia(a.fecha), () => []).add(a);
    }
    final lista = [
      for (final e in porDia.entries)
        SesionRegistrada(
          fecha: e.key,
          presentes: e.value.where((a) => a.estado == EstadoAsistencia.presente).length,
          total: e.value.length,
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  /// Promedio de asistencia de la disciplina (0 a 100).
  double get promedio {
    if (_asistencias.isEmpty) return 0;
    final presentes = _asistencias.where((a) => a.estado == EstadoAsistencia.presente).length;
    return presentes * 100 / _asistencias.length;
  }

  /// Si el entrenador aún no tocó nada, precarga lo registrado en la fecha elegida.
  void _rellenarMarcas() {
    if (_editado) return;
    for (final e in _nomina) {
      final registrada = _asistencias.where((a) => a.estudianteId == e.uid && _soloDia(a.fecha) == _fecha);
      _marcas[e.uid] = registrada.isNotEmpty && registrada.first.estado == EstadoAsistencia.presente;
    }
  }

  void _fallar(Object e) {
    _cargandoNomina = false;
    _cargandoAsistencias = false;
    _error = e is AsistenciaException ? e.mensaje : 'No se pudo cargar la disciplina.';
    _notificar();
  }

  static DateTime _soloDia(DateTime f) => DateTime(f.year, f.month, f.day);

  static String _formato(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    _subNomina.cancel();
    _subAsistencias.cancel();
    super.dispose();
  }
}
