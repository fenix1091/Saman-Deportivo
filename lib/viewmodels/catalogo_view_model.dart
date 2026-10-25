import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/deporte.dart';
import '../repositories/deporte_repository.dart';

/// Catálogo público de deportes con búsqueda y filtros (CU-04, CU-05; RF-04, RF-05).
///
/// Escucha los deportes activos en tiempo real, carga los horarios de cada uno una
/// sola vez y aplica los filtros en el teléfono, así la lista cambia al instante.
class CatalogoViewModel extends ChangeNotifier {
  CatalogoViewModel(this._repositorio) {
    _suscripcion = _repositorio.deportesActivos().listen(_alRecibirDeportes, onError: _alFallar);
  }

  final DeporteRepository _repositorio;
  late final StreamSubscription<List<Deporte>> _suscripcion;
  final _horarios = <String, List<Horario>>{};
  bool _desechado = false;

  List<Deporte> _deportes = const [];
  bool _cargando = true;
  String? _error;

  String _texto = '';
  String? _deporte;
  String? _categoria;
  DiaSemana? _dia;
  FranjaHoraria? _franja;
  bool _soloConCupos = false;

  bool get cargando => _cargando;
  String? get error => _error;
  List<Deporte> get deportes => _deportes;

  String get texto => _texto;
  String? get deporte => _deporte;
  String? get categoria => _categoria;
  DiaSemana? get dia => _dia;
  FranjaHoraria? get franja => _franja;
  bool get soloConCupos => _soloConCupos;

  List<Horario> horariosDe(String codigo) => _horarios[codigo] ?? const [];

  /// Nombres de deporte distintos, para el filtro "Deporte".
  List<String> get nombresDeporte => _distintos(_deportes.map((d) => d.nombre));

  /// Categorías o especialidades distintas, para el filtro "Categoría".
  List<String> get categorias => _distintos(_deportes.map((d) => d.categoria));

  bool get hayFiltros =>
      _texto.trim().isNotEmpty ||
      _deporte != null ||
      _categoria != null ||
      _dia != null ||
      _franja != null ||
      _soloConCupos;

  /// Deportes que cumplen la búsqueda y todos los filtros activos.
  List<Deporte> get resultados => _deportes.where(_cumpleFiltros).toList();

  void buscar(String texto) => _cambiar(() => _texto = texto);
  void filtrarDeporte(String? nombre) => _cambiar(() => _deporte = nombre);
  void filtrarCategoria(String? categoria) => _cambiar(() => _categoria = categoria);
  void filtrarDia(DiaSemana? dia) => _cambiar(() => _dia = dia);
  void filtrarFranja(FranjaHoraria? franja) => _cambiar(() => _franja = franja);
  void filtrarSoloConCupos(bool valor) => _cambiar(() => _soloConCupos = valor);

  void limpiarFiltros() => _cambiar(() {
        _texto = '';
        _deporte = null;
        _categoria = null;
        _dia = null;
        _franja = null;
        _soloConCupos = false;
      });

  /// Quita mayúsculas y acentos para que "futbol" encuentre "Fútbol" (CU-05).
  static String normalizar(String texto) {
    const conAcento = 'áéíóúüàèìòùñ';
    const sinAcento = 'aeiouuaeioun';
    final buffer = StringBuffer();
    for (final letra in texto.toLowerCase().trim().split('')) {
      final i = conAcento.indexOf(letra);
      buffer.write(i >= 0 ? sinAcento[i] : letra);
    }
    return buffer.toString();
  }

  bool _cumpleFiltros(Deporte d) {
    if (_soloConCupos && !d.hayCupo()) return false;
    if (_deporte != null && d.nombre != _deporte) return false;
    if (_categoria != null && d.categoria != _categoria) return false;
    if (_dia != null || _franja != null) {
      final coincide = horariosDe(d.codigo)
          .any((h) => (_dia == null || h.dia == _dia) && (_franja == null || h.franja == _franja));
      if (!coincide) return false;
    }
    final busqueda = normalizar(_texto);
    if (busqueda.isEmpty) return true;
    final campos = [d.nombre, d.codigo, d.categoria, d.descripcion, d.entrenador?.nombre ?? ''];
    return campos.any((campo) => normalizar(campo).contains(busqueda));
  }

  Future<void> _alRecibirDeportes(List<Deporte> deportes) async {
    _deportes = deportes;
    _cargando = false;
    _error = null;
    _notificar();
    final faltan = deportes.where((d) => !_horarios.containsKey(d.codigo)).toList();
    if (faltan.isEmpty) return;
    await Future.wait(faltan.map((d) async {
      try {
        _horarios[d.codigo] = await _repositorio.horarios(d.codigo);
      } catch (_) {
        // Sin horarios el deporte se sigue mostrando; solo no aparece al filtrar por día.
      }
    }));
    _notificar();
  }

  void _alFallar(Object e) {
    _cargando = false;
    _error = e is CatalogoException ? e.mensaje : 'No pudimos cargar el catálogo. Inténtalo de nuevo.';
    _notificar();
  }

  void _cambiar(void Function() cambio) {
    cambio();
    notifyListeners();
  }

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  static List<String> _distintos(Iterable<String> valores) {
    final lista = valores.where((v) => v.trim().isNotEmpty).toSet().toList();
    lista.sort((a, b) => normalizar(a).compareTo(normalizar(b)));
    return lista;
  }

  @override
  void dispose() {
    _desechado = true;
    _suscripcion.cancel();
    super.dispose();
  }
}
