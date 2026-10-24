import 'package:flutter/material.dart';
import '../models/deporte.dart';
import '../repositories/deporte_repository.dart';

class DeporteViewModel extends ChangeNotifier {
  final DeporteRepository _repository = DeporteRepository();

  // Variables para RF-05
  String textoBusqueda = '';
  String categoriaFiltro = 'Todas';
  String diaFiltro = 'Todos';
  String horarioFiltro = 'Todos';
  bool soloConCupo = false;

  // Opciones predefinidas para los selectores
  final List<String> categorias = [
    'Todas',
    'Cancha',
    'Gimnasio',
    'Campo',
    'Acuático',
    'Combate'
  ];

  final List<String> diasSemana = [
    'Todos',
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado'
  ];

  final List<String> horarios = [
    'Todos',
    'Mañana (07:00 - 12:00)',
    'Tarde (12:00 - 17:00)',
    'Noche (17:00 - 21:00)'
  ];

  void actualizarBusqueda(String valor) {
    textoBusqueda = valor.toLowerCase();
    notifyListeners();
  }

  void actualizarCategoria(String? categoria) {
    if (categoria != null) {
      categoriaFiltro = categoria;
      notifyListeners();
    }
  }

  void actualizarDia(String? dia) {
    if (dia != null) {
      diaFiltro = dia;
      notifyListeners();
    }
  }

  void actualizarHorario(String? horario) {
    if (horario != null) {
      horarioFiltro = horario;
      notifyListeners();
    }
  }

  void actualizarSoloConCupo(bool valor) {
    soloConCupo = valor;
    notifyListeners();
  }

  void limpiarFiltros() {
    textoBusqueda = '';
    categoriaFiltro = 'Todas';
    diaFiltro = 'Todos';
    horarioFiltro = 'Todos';
    soloConCupo = false;
    notifyListeners();
  }

  /// Búsqueda y Filtros Avanzados (RF-05)
  List<Deporte> filtrarDeportes(List<Deporte> listaOriginal) {
    return listaOriginal.where((dep) {
      // 1. Búsqueda por Texto (Nombre / Categoría / Descripción)
      final coincideTexto = textoBusqueda.isEmpty ||
          dep.nombre.toLowerCase().contains(textoBusqueda) ||
          dep.categoria.toLowerCase().contains(textoBusqueda) ||
          dep.descripcion.toLowerCase().contains(textoBusqueda);

      // 2. Filtro por Especialidad / Categoría
      final coincideCategoria = categoriaFiltro == 'Todas' ||
          dep.categoria.toLowerCase() == categoriaFiltro.toLowerCase();

      // 3. Filtro por Día (se consulta en los días configurados o la descripción)
      final coincideDia = diaFiltro == 'Todos' || _evaluarDia(dep, diaFiltro);

      // 4. Filtro por Horario / Turno
      final coincideHorario =
          horarioFiltro == 'Todos' || _evaluarHorario(dep, horarioFiltro);

      // 5. Filtro por Disponibilidad de Cupos
      final coincideCupos = !soloConCupo || dep.hayCupo();

      return coincideTexto &&
          coincideCategoria &&
          coincideDia &&
          coincideHorario &&
          coincideCupos;
    }).toList();
  }

  bool _evaluarDia(Deporte dep, String dia) {
    try {
      final dynamic d = (dep as dynamic).dias;
      if (d is List) {
        return d.any((element) =>
            element.toString().toLowerCase().contains(dia.toLowerCase()));
      }
    } catch (_) {}
    return dep.descripcion.toLowerCase().contains(dia.toLowerCase());
  }

  bool _evaluarHorario(Deporte dep, String horarioSeleccionado) {
    String clave = '';
    if (horarioSeleccionado.contains('Mañana')) clave = 'mañana';
    if (horarioSeleccionado.contains('Tarde')) clave = 'tarde';
    if (horarioSeleccionado.contains('Noche')) clave = 'noche';

    try {
      final dynamic h = (dep as dynamic).horario;
      if (h != null && h.toString().toLowerCase().contains(clave)) {
        return true;
      }
    } catch (_) {}
    return dep.descripcion.toLowerCase().contains(clave);
  }

  Stream<List<Deporte>> get deportesStream => _repository.getDeportesStream();
}
