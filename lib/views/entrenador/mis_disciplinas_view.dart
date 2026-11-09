import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/deporte.dart';
import '../../repositories/asistencia_repository.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/barra_cupos.dart';
import '../../widgets/encabezado_panel.dart';
import '../../widgets/panel_con_menu.dart';

/// Inicio del entrenador (CU-13): sus disciplinas asignadas, en tiempo real, con
/// los inscritos y el acceso a la toma de asistencia de cada una.
class MisDisciplinasView extends StatelessWidget {
  const MisDisciplinasView({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthViewModel>().usuario;
    final repositorio = context.read<AsistenciaRepository>();
    return PanelConMenu(
      titulo: const Text('Mis disciplinas'),
      body: usuario == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<Deporte>>(
              stream: repositorio.deportesDe(usuario.uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const EstadoVacio(
                    icono: Icons.cloud_off_outlined,
                    mensaje: 'No se pudieron cargar tus disciplinas. Revisa tu conexión.',
                  );
                }
                if (!snap.hasData) return const Esqueleto(filas: 2, alto: 150);
                final deportes = snap.data!;
                if (deportes.isEmpty) {
                  return const EstadoVacio(
                    icono: Icons.sports_outlined,
                    mensaje:
                        'Aún no tienes disciplinas asignadas.\nLa Coordinación de Deportes te asignará una desde el panel.',
                  );
                }
                final inscritos = deportes.fold<int>(0, (s, d) => s + d.cuposOcupados);
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                      children: [
                        EncabezadoPanel(
                          nombre: usuario.nombreCompleto,
                          fotoUrl: usuario.fotoUrl,
                          saludo: 'HOLA, PROFESOR',
                          mensaje:
                              'Tienes ${deportes.length} ${deportes.length == 1 ? 'disciplina asignada' : 'disciplinas asignadas'} y '
                              '$inscritos ${inscritos == 1 ? 'estudiante inscrito' : 'estudiantes inscritos'}. '
                              'Elige una para pasar la asistencia de hoy o revisar el historial.',
                        ),
                        const TituloSeccion(antetitulo: 'Mis disciplinas', titulo: 'Toma de asistencia'),
                        for (var i = 0; i < deportes.length; i++)
                          Revelar(
                            key: ValueKey(deportes[i].codigo),
                            orden: (i + 2).clamp(0, 6),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TarjetaDisciplina(deporte: deportes[i]),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _TarjetaDisciplina extends StatelessWidget {
  const _TarjetaDisciplina({required this.deporte});

  final Deporte deporte;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Elevable(
      radio: 16,
      alPulsar: () => context.push('/entrenador/asistencia/${Uri.encodeComponent(deporte.codigo)}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deporte.nombre, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        [deporte.codigo, if (deporte.categoria.isNotEmpty) deporte.categoria].join(' · '),
                        style: textos.bodySmall?.copyWith(color: AppColors.gris),
                      ),
                    ],
                  ),
                ),
                if (!deporte.activo) const EtiquetaEstado('Inactiva', color: AppColors.gris),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.gris),
              ],
            ),
            const SizedBox(height: 12),
            Text('${deporte.cuposOcupados} ${deporte.cuposOcupados == 1 ? 'inscrito' : 'inscritos'}',
                style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            BarraCupos(deporte: deporte),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => context.push('/entrenador/asistencia/${Uri.encodeComponent(deporte.codigo)}'),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Tomar asistencia'),
            ),
          ],
        ),
      ),
    );
  }
}
