import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/deporte.dart';
import '../../repositories/asistencia_repository.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/acciones_sesion.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/barra_cupos.dart';

/// Inicio del entrenador (CU-13): sus disciplinas asignadas, en tiempo real, con
/// los inscritos y el acceso a la toma de asistencia de cada una.
class MisDisciplinasView extends StatelessWidget {
  const MisDisciplinasView({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthViewModel>().usuario;
    final repositorio = context.read<AsistenciaRepository>();
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis disciplinas'), actions: const [AccionesSesion()]),
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
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        Revelar(
                          child: Text(
                            'Hola, ${usuario.nombre}',
                            style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Revelar(
                          orden: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 16),
                            child: Text(
                              '${deportes.length} ${deportes.length == 1 ? 'disciplina' : 'disciplinas'} · '
                              '$inscritos ${inscritos == 1 ? 'estudiante inscrito' : 'estudiantes inscritos'}',
                              style: textos.bodyMedium?.copyWith(color: AppColors.gris),
                            ),
                          ),
                        ),
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
