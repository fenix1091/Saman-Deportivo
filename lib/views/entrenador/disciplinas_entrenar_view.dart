import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/deporte.dart';
import '../../repositories/asistencia_repository.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/barra_cupos.dart';
import '../../widgets/cuadricula_adaptable.dart';
import '../../widgets/encabezado_panel.dart';
import '../../widgets/panel_con_menu.dart';
import 'mis_disciplinas_view.dart';

/// Página con únicamente las disciplinas asignadas al entrenador.
/// Al tocar una, abre su ficha.
class DisciplinasEntrenadorView extends StatelessWidget {
  const DisciplinasEntrenadorView({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthViewModel>().usuario;
    final repositorio = context.read<AsistenciaRepository>();
    return PanelConMenu(
      titulo: const Text('Disciplinas'),
      body: usuario == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<Deporte>>(
              stream: repositorio.deportesDe(usuario.uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const EstadoVacio(
                    icono: Icons.cloud_off_outlined,
                    mensaje:
                        'No se pudieron cargar tus disciplinas. Revisa tu conexión.',
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
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                      children: [
                        const TituloSeccion(
                            antetitulo: 'Asignadas a ti',
                            titulo: 'Mis disciplinas'),
                        CuadriculaAdaptable(
                          anchoMinimo: 420,
                          maxColumnas: 2,
                          hijos: [
                            for (var i = 0; i < deportes.length; i++)
                              Revelar(
                                key: ValueKey(deportes[i].codigo),
                                orden: i.clamp(0, 6),
                                child: _TarjetaSoloDisciplina(
                                    deporte: deportes[i]),
                              ),
                          ],
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

class _TarjetaSoloDisciplina extends StatelessWidget {
  const _TarjetaSoloDisciplina({required this.deporte});

  final Deporte deporte;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Elevable(
      radio: 16,
      alPulsar: () => context.push(rutaDisciplina(deporte.codigo)),
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
                      Text(deporte.nombre,
                          style: textos.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          deporte.codigo,
                          if (deporte.categoria.isNotEmpty) deporte.categoria
                        ].join(' · '),
                        style:
                            textos.bodySmall?.copyWith(color: AppColors.gris),
                      ),
                    ],
                  ),
                ),
                if (!deporte.activo)
                  const EtiquetaEstado('Inactiva', color: AppColors.gris),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.gris),
              ],
            ),
            const SizedBox(height: 12),
            Text(
                '${deporte.cuposOcupados} ${deporte.cuposOcupados == 1 ? 'inscrito' : 'inscritos'}',
                style:
                    textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            BarraCupos(deporte: deporte),
          ],
        ),
      ),
    );
  }
}
