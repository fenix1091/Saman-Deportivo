import 'dart:async';

import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/repositories/asistencia_repository.dart';

import 'deporte_repository_falso.dart';

/// [AsistenciaRepository] en memoria para las pruebas, sin conexión a Firebase.
///
/// La nómina sale de los inscritos que se registren con [inscribir]; al guardar
/// la asistencia actualiza los contadores igual que la versión de Firestore.
class AsistenciaRepositoryFalso implements AsistenciaRepository {
  AsistenciaRepositoryFalso(this.deportes);

  final DeporteRepositoryFalso deportes;
  final inscritos = <String, List<EstudianteInscrito>>{};
  final asistencias = <String, Asistencia>{};
  final _cambios = StreamController<void>.broadcast();

  /// Si se asigna, las lecturas y escrituras fallan con este error.
  AsistenciaException? fallo;

  void inscribir(String codigo, EstudianteInscrito e) {
    inscritos.putIfAbsent(codigo, () => []).add(e);
    _cambios.add(null);
  }

  Stream<T> _vigilar<T>(T Function() leer) async* {
    if (fallo != null) throw fallo!;
    yield leer();
    yield* _cambios.stream.map((_) => leer());
  }

  @override
  Stream<List<Deporte>> deportesDe(String entrenadorId) =>
      _vigilar(() => deportes.todos.where((d) => d.entrenadorId == entrenadorId).toList());

  @override
  Stream<List<EstudianteInscrito>> nomina(String codigo) => _vigilar(() => List.of(inscritos[codigo] ?? const []));

  @override
  Stream<List<Asistencia>> asistenciasDe(String codigo) =>
      _vigilar(() => asistencias.values.where((a) => a.deporteCodigo == codigo).toList());

  @override
  Future<void> registrarAsistencia({
    required String codigo,
    required DateTime fecha,
    required Map<String, bool> presentes,
  }) async {
    if (fallo != null) throw fallo!;
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final lista = inscritos[codigo] ?? [];
    for (final entrada in presentes.entries) {
      final id = idAsistencia(codigo, entrada.key, dia);
      final previa = asistencias[id];
      asistencias[id] = Asistencia(
        id: id,
        inscripcionId: Inscripcion.idPara(codigo, entrada.key),
        estudianteId: entrada.key,
        deporteCodigo: codigo,
        fecha: dia,
        estado: entrada.value ? EstadoAsistencia.presente : EstadoAsistencia.ausente,
      );
      final i = lista.indexWhere((e) => e.uid == entrada.key);
      if (i >= 0) {
        final e = lista[i];
        final estabaPresente = previa?.estado == EstadoAsistencia.presente;
        lista[i] = EstudianteInscrito(
          uid: e.uid,
          inscripcionId: e.inscripcionId,
          nombreCompleto: e.nombreCompleto,
          cedulaTexto: e.cedulaTexto,
          carnet: e.carnet,
          sesiones: e.sesiones + (previa == null ? 1 : 0),
          sesionesAsistidas: e.sesionesAsistidas + (entrada.value ? 1 : 0) - (estabaPresente ? 1 : 0),
        );
      }
    }
    _cambios.add(null);
  }
}
