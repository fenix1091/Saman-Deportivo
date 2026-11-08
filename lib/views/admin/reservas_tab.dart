import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/inscripcion.dart';
import '../../models/persona.dart';
import '../../repositories/admin_repository_firebase.dart';
import '../../widgets/animaciones.dart';

/// Revisión de reservas (Hito 3): el administrador valida el pago de cada reserva
/// que quedó EN REVISIÓN y la confirma o la rechaza. También consulta el resto.
class ReservasTab extends StatefulWidget {
  const ReservasTab({super.key, required this.repositorio});

  final AdminRepository repositorio;

  @override
  State<ReservasTab> createState() => _ReservasTabState();
}

class _ReservasTabState extends State<ReservasTab> {
  EstadoInscripcion? _filtro = EstadoInscripcion.enRevision;
  String _busqueda = '';
  final _procesando = <String>{};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Persona>>(
      stream: widget.repositorio.observarUsuarios(),
      builder: (context, usuariosSnap) {
        final usuarios = {for (final u in usuariosSnap.data ?? const <Persona>[]) u.uid: u};
        return StreamBuilder<List<Inscripcion>>(
          stream: widget.repositorio.observarInscripciones(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('No se pudieron cargar las reservas.'));
            }
            if (!snap.hasData) return const Esqueleto(filas: 4, alto: 132);
            final todas = snap.data!;
            final enRevision = todas.where((i) => i.estado == EstadoInscripcion.enRevision).length;
            final texto = _busqueda.trim().toLowerCase();
            final visibles = todas.where((i) {
              if (_filtro != null && i.estado != _filtro) return false;
              if (texto.isEmpty) return true;
              final est = usuarios[i.estudianteId];
              final campos = [
                i.nombreDeporte,
                i.deporteCodigo,
                est?.nombreCompleto ?? '',
                est?.cedulaTexto ?? '',
                est?.correo ?? '',
              ].join(' ').toLowerCase();
              return campos.contains(texto);
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por estudiante, cédula o disciplina',
                    ),
                    onChanged: (v) => setState(() => _busqueda = v),
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      _chip(null, 'Todas', todas.length),
                      const SizedBox(width: 8),
                      _chip(EstadoInscripcion.enRevision, 'En revisión', enRevision),
                      const SizedBox(width: 8),
                      for (final e in [
                        EstadoInscripcion.confirmada,
                        EstadoInscripcion.pendientePago,
                        EstadoInscripcion.rechazada,
                        EstadoInscripcion.cancelada,
                        EstadoInscripcion.expirada,
                      ]) ...[
                        _chip(e, e.etiqueta, todas.where((i) => i.estado == e).length),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: visibles.isEmpty
                      ? EstadoVacio(
                          icono:
                              _filtro == EstadoInscripcion.enRevision ? Icons.task_alt : Icons.filter_alt_off_outlined,
                          mensaje: _filtro == EstadoInscripcion.enRevision
                              ? 'No hay reservas pendientes de revisión.'
                              : 'No hay reservas con ese filtro.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: visibles.length,
                          itemBuilder: (context, i) => Revelar(
                            key: ValueKey(visibles[i].id),
                            orden: i.clamp(0, 5),
                            child: _tarjeta(context, visibles[i], usuarios[visibles[i].estudianteId]),
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _chip(EstadoInscripcion? estado, String etiqueta, int cantidad) => FilterChip(
        label: Text('$etiqueta ($cantidad)'),
        selected: _filtro == estado,
        onSelected: (_) => setState(() => _filtro = estado),
      );

  Widget _tarjeta(BuildContext context, Inscripcion r, Persona? estudiante) {
    final textos = Theme.of(context).textTheme;
    final ocupado = _procesando.contains(r.id);
    final f = r.fechaInscripcion;
    final fecha = '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} '
        '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
    final quien = estudiante == null ? r.estudianteId : '${estudiante.nombreCompleto} · ${estudiante.cedulaTexto}';
    final color = switch (r.estado) {
      EstadoInscripcion.confirmada => AppColors.verdeHoja,
      EstadoInscripcion.enRevision => AppColors.naranja,
      EstadoInscripcion.pendientePago => AppColors.azul,
      EstadoInscripcion.rechazada => AppColors.rojo,
      _ => AppColors.gris,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Elevable(
        radio: 16,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.nombreDeporte.isEmpty ? r.deporteCodigo : '${r.nombreDeporte} (${r.deporteCodigo})',
                      style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  EtiquetaEstado(r.estado.etiqueta, color: color),
                ],
              ),
              const SizedBox(height: 6),
              Text(quien),
              Text(
                  'Reservada el $fecha · ${r.monto == 0 ? 'gratuita' : '\$${r.monto.toStringAsFixed(2)}'}'
                  '${r.pagoId.isEmpty ? '' : ' · pago ${r.pagoId.split('_').last}'}',
                  style: textos.bodySmall?.copyWith(color: AppColors.gris)),
              if (r.horarios.isNotEmpty) Text(r.horarios, style: textos.bodySmall),
              if (r.motivo.isNotEmpty)
                Text('Motivo: ${r.motivo}', style: textos.bodySmall?.copyWith(color: AppColors.rojo)),
              if (r.estado == EstadoInscripcion.enRevision) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar'),
                      onPressed: ocupado ? null : () => _resolver(r, confirmar: true),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.rojo),
                      icon: const Icon(Icons.close),
                      label: const Text('Rechazar'),
                      onPressed: ocupado ? null : () => _resolver(r, confirmar: false),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resolver(Inscripcion r, {required bool confirmar}) async {
    String motivo = '';
    if (!confirmar) {
      final texto = await showDialog<String>(
        context: context,
        builder: (contexto) {
          final control = TextEditingController();
          return AlertDialog(
            title: const Text('Rechazar reserva'),
            content: TextField(
              controller: control,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Motivo (lo verá el estudiante)'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Atrás')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
                onPressed: () => Navigator.pop(contexto, control.text.trim()),
                child: const Text('Rechazar y liberar cupo'),
              ),
            ],
          );
        },
      );
      if (texto == null) return;
      motivo = texto.isEmpty ? 'Pago no validado por la Coordinación de Deportes.' : texto;
    }
    setState(() => _procesando.add(r.id));
    String mensaje;
    try {
      if (confirmar) {
        await widget.repositorio.confirmarReserva(r.id);
        mensaje = 'Reserva confirmada.';
      } else {
        await widget.repositorio.rechazarReserva(r.id, motivo);
        mensaje = 'Reserva rechazada; el cupo quedó libre.';
      }
    } on ReservaNoRevisableException {
      mensaje = 'Esta reserva ya no estaba en revisión.';
    } catch (_) {
      mensaje = 'No se pudo actualizar la reserva. Inténtalo de nuevo.';
    }
    if (!mounted) return;
    setState(() => _procesando.remove(r.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }
}
