import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/deporte.dart';
import '../../models/inscripcion.dart';
import '../../models/persona.dart';
import '../../repositories/admin_repository_firebase.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/grafico_barras.dart';

/// Dashboard del administrador (RF-21, CU-20): cifras y gráficos con los datos
/// reales de Firestore, en tiempo real: deportes más buscados, ocupación de cupos,
/// reservas por estado y asistencia.
class ResumenTab extends StatelessWidget {
  const ResumenTab({super.key, required this.repositorio});

  final AdminRepository repositorio;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Deporte>>(
      stream: repositorio.observarDeportes(),
      builder: (context, deportesSnap) => StreamBuilder<List<Inscripcion>>(
        stream: repositorio.observarInscripciones(),
        builder: (context, inscripcionesSnap) => StreamBuilder<List<Persona>>(
          stream: repositorio.observarUsuarios(),
          builder: (context, usuariosSnap) {
            if (deportesSnap.hasError || inscripcionesSnap.hasError || usuariosSnap.hasError) {
              return const EstadoVacio(
                  icono: Icons.cloud_off_outlined, mensaje: 'No se pudieron cargar los datos del resumen.');
            }
            if (!deportesSnap.hasData || !inscripcionesSnap.hasData || !usuariosSnap.hasData) {
              return const Esqueleto(filas: 3, alto: 120);
            }
            return _Resumen(
              deportes: deportesSnap.data!,
              inscripciones: inscripcionesSnap.data!,
              usuarios: usuariosSnap.data!,
            );
          },
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.deportes, required this.inscripciones, required this.usuarios});

  final List<Deporte> deportes;
  final List<Inscripcion> inscripciones;
  final List<Persona> usuarios;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final activos = deportes.where((d) => d.activo).toList();
    final confirmadas = inscripciones.where((i) => i.estado == EstadoInscripcion.confirmada).length;
    final enRevision = inscripciones.where((i) => i.estado == EstadoInscripcion.enRevision).length;
    final cuposLibres = activos.fold<int>(0, (s, d) => s + d.cuposDisponibles());
    final ingresos = inscripciones.where((i) => i.ocupaCupo).fold<double>(0, (s, i) => s + i.monto);
    final estudiantes = usuarios.whereType<Estudiante>().toList();
    final noSolventes = estudiantes.where((e) => !e.solvente).length;
    final entrenadores = usuarios.whereType<Entrenador>().length;
    final sesiones = inscripciones.fold<int>(0, (s, i) => s + i.sesiones);
    final asistidas = inscripciones.fold<int>(0, (s, i) => s + i.sesionesAsistidas);
    final asistencia = sesiones == 0 ? null : asistidas * 100 / sesiones;

    final masBuscados = [...deportes]..sort((a, b) => b.vecesBuscado.compareTo(a.vecesBuscado));
    final ocupacion = [...activos]..sort((a, b) {
        final oa = a.cupoMaximo == 0 ? 0 : a.cuposOcupados / a.cupoMaximo;
        final ob = b.cupoMaximo == 0 ? 0 : b.cuposOcupados / b.cupoMaximo;
        return ob.compareTo(oa);
      });
    final porEstado = [
      for (final e in EstadoInscripcion.values)
        DatoBarra(
          etiqueta: e.etiqueta,
          valor: inscripciones.where((i) => i.estado == e).length.toDouble(),
          color: switch (e) {
            EstadoInscripcion.confirmada => AppColors.verdeHoja,
            EstadoInscripcion.enRevision => AppColors.naranja,
            EstadoInscripcion.pendientePago => AppColors.azul,
            EstadoInscripcion.rechazada => AppColors.rojo,
            _ => AppColors.gris,
          },
        ),
    ];

    Widget seccion(String titulo, String subtitulo, Widget hijo, {int orden = 0}) => Revelar(
          orden: orden,
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3E8EE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitulo, style: textos.bodySmall?.copyWith(color: AppColors.gris)),
                const SizedBox(height: 12),
                hijo,
              ],
            ),
          ),
        );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Revelar(
              child: Text('Resumen en tiempo real', style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Revelar(
              orden: 1,
              child: Text(
                'Los datos cambian solos cuando alguien se inscribe, paga o toma asistencia.',
                style: textos.bodyMedium?.copyWith(color: AppColors.gris),
              ),
            ),
            const SizedBox(height: 12),
            Revelar(
              orden: 2,
              child: LayoutBuilder(
                builder: (context, c) {
                  final columnas = c.maxWidth >= 900
                      ? 4
                      : c.maxWidth >= 560
                          ? 3
                          : 2;
                  final ancho = (c.maxWidth - 12 * (columnas - 1)) / columnas;
                  final tarjetas = [
                    TarjetaCifra(
                        icono: Icons.sports_outlined, valor: '${activos.length}', etiqueta: 'disciplinas activas'),
                    TarjetaCifra(
                        icono: Icons.how_to_reg_outlined,
                        valor: '$confirmadas',
                        etiqueta: 'inscripciones confirmadas',
                        color: AppColors.verdeHoja),
                    TarjetaCifra(
                        icono: Icons.hourglass_top,
                        valor: '$enRevision',
                        etiqueta: 'reservas por revisar',
                        color: AppColors.naranja),
                    TarjetaCifra(
                        icono: Icons.event_seat_outlined,
                        valor: '$cuposLibres',
                        etiqueta: 'cupos libres',
                        color: AppColors.azul),
                    TarjetaCifra(
                        icono: Icons.payments_outlined,
                        valor: '\$${ingresos.toStringAsFixed(0)}',
                        etiqueta: 'en reservas pagadas',
                        color: const Color(0xFFC2410C)),
                    TarjetaCifra(
                        icono: Icons.school_outlined,
                        valor: '${estudiantes.length}',
                        etiqueta: 'estudiantes · $noSolventes sin solvencia'),
                    TarjetaCifra(
                        icono: Icons.sports_handball_outlined, valor: '$entrenadores', etiqueta: 'entrenadores'),
                    TarjetaCifra(
                      icono: Icons.fact_check_outlined,
                      valor: asistencia == null ? '—' : '${asistencia.round()} %',
                      etiqueta: asistencia == null ? 'asistencia (sin sesiones aún)' : 'asistencia promedio',
                      color: AppColors.verdeSaman,
                    ),
                  ];
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [for (final t in tarjetas) SizedBox(width: ancho, child: t)],
                  );
                },
              ),
            ),
            seccion(
              'Deportes más buscados',
              'Consultas al detalle de cada disciplina desde el catálogo (RF-21).',
              GraficoBarras(
                datos: [
                  for (final d in masBuscados.take(6))
                    DatoBarra(
                        etiqueta: d.nombre, valor: d.vecesBuscado.toDouble(), detalle: '${d.vecesBuscado} consultas'),
                ],
              ),
              orden: 3,
            ),
            seccion(
              'Ocupación de cupos',
              'Inscritos sobre el cupo máximo de cada disciplina activa.',
              GraficoBarras(
                maximo: 100,
                datos: [
                  for (final d in ocupacion)
                    DatoBarra(
                      etiqueta: d.nombre,
                      valor: d.cupoMaximo == 0 ? 0 : d.cuposOcupados * 100 / d.cupoMaximo,
                      detalle: '${d.cuposOcupados} de ${d.cupoMaximo}',
                      color: d.cuposDisponibles() == 0
                          ? AppColors.rojo
                          : d.cuposOcupados / (d.cupoMaximo == 0 ? 1 : d.cupoMaximo) >= 0.8
                              ? AppColors.naranja
                              : AppColors.verdeHoja,
                    ),
                ],
              ),
              orden: 4,
            ),
            seccion(
              'Reservas por estado',
              'Todas las inscripciones registradas en la plataforma.',
              GraficoBarras(datos: porEstado),
              orden: 5,
            ),
          ],
        ),
      ),
    );
  }
}
