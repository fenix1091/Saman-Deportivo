import 'dart:async';

import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/resena.dart';
import 'package:saman_deportivo/repositories/deporte_repository.dart';

/// [DeporteRepository] en memoria para las pruebas, sin conexión a Firebase.
///
/// [cambiarCupos] imita a otro estudiante ocupando un cupo, para comprobar que
/// el catálogo y el detalle se actualizan en tiempo real.
class DeporteRepositoryFalso implements DeporteRepository {
  DeporteRepositoryFalso({List<Deporte> deportes = const [], Map<String, List<Horario>> horarios = const {}})
      : _deportes = {for (final d in deportes) d.codigo: d},
        _horarios = Map.of(horarios);

  /// Catálogo de ejemplo con cuatro disciplinas (una sin cupos y una inactiva).
  factory DeporteRepositoryFalso.conDatosDePrueba() {
    const entrenador = EntrenadorAsignado(nombre: 'Entrenador Prueba', especialidad: 'Fútbol', aniosExperiencia: 8);
    final repo = DeporteRepositoryFalso(
      deportes: const [
        Deporte(
          codigo: 'FUT-01',
          nombre: 'Fútbol',
          categoria: 'Colectivo',
          descripcion: 'Selección de fútbol campo de la UNIMET.',
          cupoMaximo: 25,
          cuposOcupados: 20,
          costoReserva: 5,
          entrenadorId: 'ent-demo',
          entrenador: entrenador,
        ),
        Deporte(
          codigo: 'BAS-01',
          nombre: 'Baloncesto',
          categoria: 'Colectivo',
          cupoMaximo: 15,
          cuposOcupados: 15,
          costoReserva: 5,
        ),
        Deporte(
          codigo: 'TEN-01',
          nombre: 'Tenis',
          categoria: 'Raqueta',
          cupoMaximo: 8,
          cuposOcupados: 2,
          entrenadorId: 'ent-demo',
          entrenador: entrenador,
        ),
        Deporte(codigo: 'NAT-01', nombre: 'Natación', categoria: 'Acuático', cupoMaximo: 10, activo: false),
      ],
      horarios: {
        'FUT-01': [
          const Horario(id: 'h1', dia: DiaSemana.martes, horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha 1'),
          const Horario(id: 'h2', dia: DiaSemana.jueves, horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha 1'),
        ],
        'BAS-01': [
          const Horario(id: 'h3', dia: DiaSemana.lunes, horaInicio: '18:30', horaFin: '20:00', lugar: 'Gimnasio'),
        ],
        'TEN-01': [
          const Horario(id: 'h4', dia: DiaSemana.sabado, horaInicio: '09:00', horaFin: '11:00', lugar: 'Canchas de tenis'),
        ],
      },
    );
    repo.resenasGuardadas.addAll([
      Resena(
        id: 'r1',
        estudianteId: 'e1',
        autor: 'Ana Pérez',
        deporteCodigo: 'FUT-01',
        calificacion: 5,
        comentario: 'Muy buen ambiente.',
        fecha: DateTime(2026, 10, 1),
      ),
      Resena(id: 'r2', estudianteId: 'e2', deporteCodigo: 'FUT-01', calificacion: 4, fecha: DateTime(2026, 10, 5)),
    ]);
    return repo;
  }

  final Map<String, Deporte> _deportes;
  final Map<String, List<Horario>> _horarios;
  final resenasGuardadas = <Resena>[];
  final consultas = <String, int>{};
  final _cambios = StreamController<void>.broadcast();

  /// Si se asigna, las lecturas fallan con este error (para probar los avisos).
  CatalogoException? fallo;

  Deporte? leer(String codigo) => _deportes[codigo];

  /// Cambia los cupos ocupados como lo haría otro estudiante al inscribirse.
  void cambiarCupos(String codigo, int ocupados) {
    final d = _deportes[codigo]!;
    _deportes[codigo] = Deporte.desdeMapa(codigo, {...d.aMapa(), 'cuposOcupados': ocupados});
    _cambios.add(null);
  }

  Stream<T> _vigilar<T>(T Function() leer) async* {
    if (fallo != null) throw fallo!;
    yield leer();
    yield* _cambios.stream.map((_) => leer());
  }

  @override
  Stream<List<Deporte>> deportesActivos() => _vigilar(() {
        final lista = _deportes.values.where((d) => d.activo).toList();
        lista.sort((a, b) => a.nombre.compareTo(b.nombre));
        return lista;
      });

  @override
  Stream<Deporte?> deporte(String codigo) => _vigilar(() => _deportes[codigo]);

  @override
  Future<List<Horario>> horarios(String codigo) async {
    if (fallo != null) throw fallo!;
    return [...?_horarios[codigo]]..sort(compararHorarios);
  }

  @override
  Stream<List<Resena>> resenas(String codigo) => _vigilar(() {
        final lista = resenasGuardadas.where((r) => r.deporteCodigo == codigo).toList();
        lista.sort((a, b) => b.fecha.compareTo(a.fecha));
        return lista;
      });

  @override
  Future<void> registrarConsulta(String codigo) async {
    consultas[codigo] = (consultas[codigo] ?? 0) + 1;
  }
}
