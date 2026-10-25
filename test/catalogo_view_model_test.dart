import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';
import 'package:saman_deportivo/viewmodels/catalogo_view_model.dart';
import 'package:saman_deportivo/viewmodels/detalle_deporte_view_model.dart';

import 'falsos/deporte_repository_falso.dart';

/// Deja correr los streams y las cargas de horarios del repositorio falso.
Future<void> esperar() => Future<void>.delayed(Duration.zero);

List<String> codigos(CatalogoViewModel vm) => [for (final d in vm.resultados) d.codigo];

void main() {
  group('Catálogo público (RF-04)', () {
    test('muestra solo los deportes activos, ordenados por nombre', () async {
      final vm = CatalogoViewModel(DeporteRepositoryFalso.conDatosDePrueba());
      expect(vm.cargando, isTrue);
      await esperar();
      expect(vm.cargando, isFalse);
      expect(codigos(vm), ['BAS-01', 'FUT-01', 'TEN-01']);
      expect(vm.horariosDe('FUT-01'), hasLength(2));
    });

    test('los cupos se actualizan en tiempo real', () async {
      final repo = DeporteRepositoryFalso.conDatosDePrueba();
      final vm = CatalogoViewModel(repo);
      await esperar();
      expect(vm.deportes.firstWhere((d) => d.codigo == 'FUT-01').cuposDisponibles(), 5);
      repo.cambiarCupos('FUT-01', 24);
      await esperar();
      expect(vm.deportes.firstWhere((d) => d.codigo == 'FUT-01').cuposDisponibles(), 1);
    });

    test('sin conexión muestra el motivo en vez de la lista', () async {
      final repo = DeporteRepositoryFalso.conDatosDePrueba()..fallo = const CatalogoException('Sin conexión.');
      final vm = CatalogoViewModel(repo);
      await esperar();
      expect(vm.error, 'Sin conexión.');
      expect(vm.resultados, isEmpty);
    });
  });

  group('Búsqueda y filtros avanzados (RF-05)', () {
    late CatalogoViewModel vm;

    setUp(() async {
      vm = CatalogoViewModel(DeporteRepositoryFalso.conDatosDePrueba());
      await esperar();
    });

    test('la búsqueda no distingue mayúsculas ni acentos', () {
      vm.buscar('FUTBOL');
      expect(codigos(vm), ['FUT-01']);
      vm.buscar('ten');
      expect(codigos(vm), ['TEN-01']);
      vm.buscar('entrenador prueba');
      expect(codigos(vm), ['FUT-01', 'TEN-01']);
      expect(CatalogoViewModel.normalizar(' Natación Ñandú '), 'natacion nandu');
    });

    test('filtra por deporte y por categoría', () {
      expect(vm.nombresDeporte, ['Baloncesto', 'Fútbol', 'Tenis']);
      expect(vm.categorias, ['Colectivo', 'Raqueta']);
      vm.filtrarDeporte('Tenis');
      expect(codigos(vm), ['TEN-01']);
      vm.filtrarDeporte(null);
      vm.filtrarCategoria('Colectivo');
      expect(codigos(vm), ['BAS-01', 'FUT-01']);
    });

    test('filtra por día y por franja horaria', () {
      vm.filtrarDia(DiaSemana.martes);
      expect(codigos(vm), ['FUT-01']);
      vm.filtrarDia(null);
      vm.filtrarFranja(FranjaHoraria.noche);
      expect(codigos(vm), ['BAS-01']);
      vm.filtrarFranja(FranjaHoraria.manana);
      expect(codigos(vm), ['TEN-01']);
      vm.filtrarDia(DiaSemana.lunes);
      expect(codigos(vm), isEmpty);
    });

    test('filtra solo los que tienen cupos y combina los filtros', () {
      vm.filtrarSoloConCupos(true);
      expect(codigos(vm), ['FUT-01', 'TEN-01']);
      vm.filtrarCategoria('Colectivo');
      expect(codigos(vm), ['FUT-01']);
      expect(vm.hayFiltros, isTrue);
    });

    test('limpiar filtros devuelve el catálogo completo', () {
      vm.buscar('xyz');
      vm.filtrarDia(DiaSemana.domingo);
      expect(vm.resultados, isEmpty);
      vm.limpiarFiltros();
      expect(vm.hayFiltros, isFalse);
      expect(codigos(vm), ['BAS-01', 'FUT-01', 'TEN-01']);
    });
  });

  group('Detalle de un deporte (RF-06)', () {
    test('trae entrenador, horarios, cupos, costo y reseñas, y cuenta la consulta', () async {
      final repo = DeporteRepositoryFalso.conDatosDePrueba();
      final vm = DetalleDeporteViewModel(repo, 'FUT-01');
      await esperar();
      expect(vm.deporte!.entrenador!.nombre, 'Entrenador Prueba');
      expect(vm.deporte!.costoReserva, 5);
      expect(vm.horarios.map((h) => h.etiqueta), ['Martes 16:00 - 18:00', 'Jueves 16:00 - 18:00']);
      expect(vm.totalResenas, 2);
      expect(vm.calificacionPromedio, 4.5);
      expect(vm.resenasRecientes.first.id, 'r2');
      expect(repo.consultas['FUT-01'], 1);
    });

    test('los cupos del detalle cambian sin recargar', () async {
      final repo = DeporteRepositoryFalso.conDatosDePrueba();
      final vm = DetalleDeporteViewModel(repo, 'TEN-01');
      await esperar();
      expect(vm.deporte!.cuposDisponibles(), 6);
      repo.cambiarCupos('TEN-01', 8);
      await esperar();
      expect(vm.deporte!.hayCupo(), isFalse);
      expect(vm.calificacionPromedio, isNull);
    });

    test('un deporte inexistente o dado de baja no está disponible', () async {
      final repo = DeporteRepositoryFalso.conDatosDePrueba();
      final inexistente = DetalleDeporteViewModel(repo, 'NO-EXISTE');
      final inactivo = DetalleDeporteViewModel(repo, 'NAT-01');
      await esperar();
      expect(inexistente.noDisponible, isTrue);
      expect(inactivo.noDisponible, isTrue);
    });
  });

  group('Modelo del catálogo', () {
    test('la franja horaria sale de la hora de inicio', () {
      Horario h(String inicio) => Horario(id: 'x', dia: DiaSemana.lunes, horaInicio: inicio, horaFin: '23:00', lugar: '');
      expect(h('06:30').franja, FranjaHoraria.manana);
      expect(h('11:59').franja, FranjaHoraria.manana);
      expect(h('12:00').franja, FranjaHoraria.tarde);
      expect(h('18:00').franja, FranjaHoraria.noche);
    });

    test('el entrenador asignado se guarda y se lee con el deporte', () {
      const d = Deporte(
        codigo: 'FUT-01',
        nombre: 'Fútbol',
        cupoMaximo: 25,
        entrenadorId: 't1',
        entrenador: EntrenadorAsignado(nombre: 'Carlos Ruiz', especialidad: 'Fútbol', aniosExperiencia: 8),
      );
      final copia = Deporte.desdeMapa('FUT-01', d.aMapa());
      expect(copia.entrenador!.nombre, 'Carlos Ruiz');
      expect(copia.aMapa(), d.aMapa());
      expect(Deporte.desdeMapa('X', {'nombre': 'X', 'cupoMaximo': 1}).entrenador, isNull);
    });
  });
}
