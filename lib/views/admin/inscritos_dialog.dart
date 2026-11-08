import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/deporte.dart';
import '../../models/inscripcion.dart';
import '../../models/persona.dart';
import '../../repositories/admin_repository_firebase.dart';
import '../../widgets/animaciones.dart';

/// Inscritos de una disciplina (Hito 3, punto 7): el administrador ve quién está
/// inscrito, retira a un estudiante o inscribe a uno directamente, con validación.
class InscritosDialog extends StatefulWidget {
  const InscritosDialog({super.key, required this.deporte, required this.repositorio});

  final Deporte deporte;
  final AdminRepository repositorio;

  @override
  State<InscritosDialog> createState() => _InscritosDialogState();
}

class _InscritosDialogState extends State<InscritosDialog> {
  final _ocupados = <String>{};
  String _busqueda = '';

  Future<void> _ejecutar(String id, Future<void> Function() accion, String exito) async {
    setState(() => _ocupados.add(id));
    String mensaje;
    try {
      await accion();
      mensaje = exito;
    } on OperacionNoPermitidaException catch (e) {
      mensaje = e.mensaje;
    } catch (_) {
      mensaje = 'No se pudo completar la operación. Inténtalo de nuevo.';
    }
    if (!mounted) return;
    setState(() => _ocupados.remove(id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text('Inscritos en ${widget.deporte.nombre}'),
      content: SizedBox(
        width: 560,
        height: 520,
        child: StreamBuilder<List<Persona>>(
          stream: widget.repositorio.observarUsuarios(),
          builder: (context, usuariosSnap) {
            final usuarios = {for (final u in usuariosSnap.data ?? const <Persona>[]) u.uid: u};
            return StreamBuilder<List<Inscripcion>>(
              stream: widget.repositorio.observarInscripciones(),
              builder: (context, snap) {
                if (!snap.hasData || !usuariosSnap.hasData) return const Esqueleto(filas: 3, alto: 64);
                final vigentes = snap.data!
                    .where((i) => i.deporteCodigo == widget.deporte.codigo && i.estaVigente())
                    .toList()
                  ..sort((a, b) =>
                      (usuarios[a.estudianteId]?.apellido ?? '').compareTo(usuarios[b.estudianteId]?.apellido ?? ''));
                final inscritosIds = vigentes.map((i) => i.estudianteId).toSet();
                final q = _busqueda.trim().toLowerCase();
                final candidatos = usuarios.values
                    .whereType<Estudiante>()
                    .where((e) => !inscritosIds.contains(e.uid))
                    .where((e) =>
                        q.isNotEmpty && '${e.nombreCompleto} ${e.cedulaTexto} ${e.correo}'.toLowerCase().contains(q))
                    .take(5)
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vigentes.length} ${vigentes.length == 1 ? 'inscripción vigente' : 'inscripciones vigentes'} · '
                      '${widget.deporte.cuposOcupados} de ${widget.deporte.cupoMaximo} cupos ocupados',
                      style: textos.bodySmall?.copyWith(color: AppColors.gris),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_add_alt_1_outlined),
                        hintText: 'Inscribir estudiante: busca por nombre o cédula',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _busqueda = v),
                    ),
                    if (candidatos.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in candidatos)
                              ActionChip(
                                avatar: Icon(
                                  e.solvente ? Icons.check_circle_outline : Icons.error_outline,
                                  size: 18,
                                  color: e.solvente ? AppColors.verdeHoja : AppColors.rojo,
                                ),
                                label: Text('${e.nombreCompleto} · ${e.cedulaTexto}'),
                                onPressed: _ocupados.contains(e.uid)
                                    ? null
                                    : () => _ejecutar(
                                          e.uid,
                                          () => widget.repositorio.inscribirEstudiante(widget.deporte.codigo, e.uid),
                                          '${e.nombreCompleto} quedó inscrito en ${widget.deporte.nombre}.',
                                        ).then((_) => setState(() => _busqueda = '')),
                              ),
                          ],
                        ),
                      ),
                    const Divider(height: 24),
                    Expanded(
                      child: vigentes.isEmpty
                          ? const EstadoVacio(
                              icono: Icons.group_off_outlined,
                              mensaje: 'Nadie está inscrito todavía. Busca arriba a un estudiante para inscribirlo.',
                            )
                          : ListView.builder(
                              itemCount: vigentes.length,
                              itemBuilder: (context, i) {
                                final ins = vigentes[i];
                                final u = usuarios[ins.estudianteId];
                                final color = switch (ins.estado) {
                                  EstadoInscripcion.confirmada => AppColors.verdeHoja,
                                  EstadoInscripcion.enRevision => AppColors.naranja,
                                  _ => AppColors.azul,
                                };
                                return ListTile(
                                  key: ValueKey(ins.id),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(u?.nombreCompleto ?? ins.estudianteId),
                                  subtitle: Text(
                                    [
                                      if (u != null) u.cedulaTexto,
                                      if (ins.sesiones > 0) 'asistencia ${ins.sesionesAsistidas}/${ins.sesiones}'
                                    ].join(' · '),
                                  ),
                                  leading: EtiquetaEstado(ins.estado.etiqueta, color: color),
                                  trailing: TextButton.icon(
                                    style: TextButton.styleFrom(foregroundColor: AppColors.rojo),
                                    icon: const Icon(Icons.person_remove_outlined, size: 18),
                                    label: const Text('Retirar'),
                                    onPressed: _ocupados.contains(ins.id)
                                        ? null
                                        : () => _confirmarRetiro(context, ins, u?.nombreCompleto ?? 'este estudiante'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }

  Future<void> _confirmarRetiro(BuildContext context, Inscripcion ins, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Retirar estudiante'),
        content: Text(
          '¿Retirar a $nombre de ${widget.deporte.nombre}? '
          '${ins.ocupaCupo ? 'Su cupo quedará libre' : 'Su reserva pendiente se cancelará'} y la inscripción pasará al historial.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Atrás')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _ejecutar(ins.id, () => widget.repositorio.retirarEstudiante(ins.id),
        '$nombre fue retirado de ${widget.deporte.nombre}.');
  }
}
