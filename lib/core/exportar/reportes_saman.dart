import '../../models/asistencia.dart';
import '../../models/deporte.dart';
import '../../models/inscripcion.dart';
import '../../models/persona.dart';
import '../../repositories/asistencia_repository.dart';
import 'reportes.dart';

/// Los reportes que se descargan desde la aplicación:
/// - CU-13 / CU-16: lista de inscritos y asistencia de una disciplina (entrenador y administrador).
/// - CU-20: reporte general del administrador.
class ReportesSaman {
  ReportesSaman._();

  static String _fecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

  static double _pct(int parte, int total) => total == 0 ? 0 : (parte * 1000 / total).round() / 10;

  static String _pctTexto(double p) =>
      p.truncateToDouble() == p ? p.toStringAsFixed(0) : p.toStringAsFixed(1).replaceAll('.', ',');

  static String _archivo(String base) => base.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Lista de inscritos y asistencia de una disciplina (vista del entrenador).
  static Reporte asistenciaDisciplina(Deporte d, List<EstudianteInscrito> nomina, List<Asistencia> asistencias,
      {DateTime? fecha}) {
    final nombres = {for (final e in nomina) e.uid: e};
    final porDia = <DateTime, List<Asistencia>>{};
    for (final a in asistencias) {
      porDia.putIfAbsent(DateTime(a.fecha.year, a.fecha.month, a.fecha.day), () => []).add(a);
    }
    final dias = porDia.keys.toList()..sort();
    final ordenados = [...nomina]..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));
    int asistidas(String uid) =>
        asistencias.where((a) => a.estudianteId == uid && a.estado == EstadoAsistencia.presente).length;
    int sesiones(String uid) => asistencias.where((a) => a.estudianteId == uid).length;

    final presentesTotal = asistencias.where((a) => a.estado == EstadoAsistencia.presente).length;
    return Reporte(
      titulo: 'Asistencia de ${d.nombre}',
      subtitulo: '${d.codigo}${d.categoria.isEmpty ? '' : ' · ${d.categoria}'} · ${nomina.length} inscritos · '
          '${dias.length} sesiones · ${_pctTexto(_pct(presentesTotal, asistencias.length))} % de asistencia',
      archivo: _archivo('asistencia_${d.codigo}'),
      fecha: fecha,
      tablas: [
        TablaReporte(
          titulo: 'Inscritos',
          columnas: const ['#', 'Estudiante', 'Cédula', 'Carnet', 'Sesiones', 'Asistidas', '% asistencia'],
          filas: [
            for (var i = 0; i < ordenados.length; i++)
              [
                i + 1,
                ordenados[i].nombreCompleto,
                ordenados[i].cedulaTexto,
                ordenados[i].carnet,
                sesiones(ordenados[i].uid),
                asistidas(ordenados[i].uid),
                _pct(asistidas(ordenados[i].uid), sesiones(ordenados[i].uid)),
              ],
          ],
        ),
        TablaReporte(
          titulo: 'Sesiones',
          columnas: const ['Fecha', 'Presentes', 'Ausentes', 'Total', '% asistencia'],
          filas: [
            for (final dia in dias.reversed)
              () {
                final l = porDia[dia]!;
                final p = l.where((a) => a.estado == EstadoAsistencia.presente).length;
                return <Object>[_fecha(dia), p, l.length - p, l.length, _pct(p, l.length)];
              }(),
          ],
        ),
        TablaReporte(
          titulo: 'Detalle por fecha',
          columnas: const ['Fecha', 'Estudiante', 'Cédula', 'Estado'],
          filas: [
            for (final dia in dias.reversed)
              for (final a in [...porDia[dia]!]
                ..sort((x, y) =>
                    (nombres[x.estudianteId]?.nombreCompleto ?? '').compareTo(nombres[y.estudianteId]?.nombreCompleto ?? '')))
                [
                  _fecha(dia),
                  nombres[a.estudianteId]?.nombreCompleto ?? a.estudianteId,
                  nombres[a.estudianteId]?.cedulaTexto ?? '',
                  a.estado == EstadoAsistencia.presente ? 'Presente' : 'Ausente',
                ],
          ],
        ),
      ],
    );
  }

  /// Lista de inscritos de una disciplina (vista del administrador, CU-13).
  static Reporte inscritosDisciplina(Deporte d, List<Inscripcion> vigentes, Map<String, Persona> usuarios,
      {DateTime? fecha}) {
    final ordenadas = [...vigentes]
      ..sort((a, b) => (usuarios[a.estudianteId]?.apellido ?? '').compareTo(usuarios[b.estudianteId]?.apellido ?? ''));
    return Reporte(
      titulo: 'Inscritos en ${d.nombre}',
      subtitulo: '${d.codigo} · ${d.cuposOcupados} de ${d.cupoMaximo} cupos ocupados',
      archivo: _archivo('inscritos_${d.codigo}'),
      fecha: fecha,
      tablas: [
        TablaReporte(
          titulo: 'Inscritos',
          columnas: const ['#', 'Estudiante', 'Cédula', 'Carnet', 'Correo', 'Teléfono', 'Estado', 'Inscrito el', '% asistencia'],
          filas: [
            for (var i = 0; i < ordenadas.length; i++)
              () {
                final ins = ordenadas[i];
                final u = usuarios[ins.estudianteId];
                return <Object>[
                  i + 1,
                  u?.nombreCompleto ?? ins.estudianteId,
                  u?.cedulaTexto ?? '',
                  u is Estudiante ? u.carnet : '',
                  u?.correo ?? '',
                  u?.telefono ?? '',
                  ins.estado.etiqueta,
                  _fecha(ins.fechaInscripcion),
                  _pct(ins.sesionesAsistidas, ins.sesiones),
                ];
              }(),
          ],
        ),
      ],
    );
  }

  /// Reporte general del administrador (CU-20): disciplinas, reservas y estudiantes.
  static Reporte general(List<Deporte> deportes, List<Inscripcion> inscripciones, List<Persona> usuarios,
      {DateTime? fecha}) {
    final ordenados = [...deportes]..sort((a, b) => a.nombre.compareTo(b.nombre));
    final estudiantes = usuarios.whereType<Estudiante>().toList();
    final entrenadores = {for (final e in usuarios.whereType<Entrenador>()) e.uid: e};
    final ingresos = inscripciones.where((i) => i.ocupaCupo).fold<double>(0, (s, i) => s + i.monto);
    final sesiones = inscripciones.fold<int>(0, (s, i) => s + i.sesiones);
    final asistidas = inscripciones.fold<int>(0, (s, i) => s + i.sesionesAsistidas);
    return Reporte(
      titulo: 'Reporte general',
      subtitulo: '${deportes.length} disciplinas · ${estudiantes.length} estudiantes · '
          '${inscripciones.where((i) => i.estado == EstadoInscripcion.confirmada).length} inscripciones confirmadas',
      archivo: 'reporte_general_saman_deportivo',
      fecha: fecha,
      tablas: [
        TablaReporte(
          titulo: 'Resumen',
          columnas: const ['Indicador', 'Valor'],
          filas: [
            ['Disciplinas activas', deportes.where((d) => d.activo).length],
            ['Cupos libres', deportes.where((d) => d.activo).fold<int>(0, (s, d) => s + d.cuposDisponibles())],
            for (final e in EstadoInscripcion.values)
              ['Reservas: ${e.etiqueta.toLowerCase()}', inscripciones.where((i) => i.estado == e).length],
            ['Ingresos por reservas (USD)', (ingresos * 100).round() / 100],
            ['Asistencia promedio (%)', _pct(asistidas, sesiones)],
            ['Estudiantes no solventes', estudiantes.where((e) => !e.solvente).length],
            ['Entrenadores', entrenadores.length],
          ],
        ),
        TablaReporte(
          titulo: 'Disciplinas',
          columnas: const ['Código', 'Disciplina', 'Entrenador', 'Estado', 'Ocupados', 'Cupo', '% ocupación', 'Búsquedas', '% asistencia'],
          filas: [
            for (final d in ordenados)
              () {
                final suyas = inscripciones.where((i) => i.deporteCodigo == d.codigo);
                final s = suyas.fold<int>(0, (t, i) => t + i.sesiones);
                final a = suyas.fold<int>(0, (t, i) => t + i.sesionesAsistidas);
                return <Object>[
                  d.codigo,
                  d.nombre,
                  entrenadores[d.entrenadorId]?.nombreCompleto ?? d.entrenador?.nombre ?? 'Sin asignar',
                  d.activo ? 'Activa' : 'Inactiva',
                  d.cuposOcupados,
                  d.cupoMaximo,
                  _pct(d.cuposOcupados, d.cupoMaximo),
                  d.vecesBuscado,
                  _pct(a, s),
                ];
              }(),
          ],
        ),
        TablaReporte(
          titulo: 'Estudiantes',
          columnas: const ['Estudiante', 'Cédula', 'Carnet', 'Carrera', 'Solvente', 'Inscripciones vigentes'],
          filas: [
            for (final e in [...estudiantes]..sort((a, b) => a.apellido.compareTo(b.apellido)))
              [
                e.nombreCompleto,
                e.cedulaTexto,
                e.carnet,
                e.carrera,
                e.solvente ? 'Sí' : 'No',
                inscripciones.where((i) => i.estudianteId == e.uid && i.estaVigente()).length,
              ],
          ],
        ),
      ],
    );
  }
}
