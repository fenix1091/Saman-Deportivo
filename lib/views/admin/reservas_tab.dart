import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/validacion_admin.dart';
import '../../models/deporte.dart';
import '../../models/inscripcion.dart';
import '../../models/persona.dart';
import '../../repositories/admin_repository_firebase.dart';
import '../../widgets/cuadricula_adaptable.dart';
import '../../widgets/animaciones.dart';

/// Revisión de reservas (Hito 3): el administrador valida el pago de cada reserva
/// que quedó EN REVISIÓN y la confirma o la rechaza. También consulta el resto y
/// puede cancelar a mano o cambiar de disciplina cualquier reserva vigente (por
/// ejemplo, si el estudiante no se presenta a los entrenamientos).
class ReservasTab extends StatefulWidget {
  const ReservasTab({super.key, required this.repositorio});

  final AdminRepository repositorio;

  @override
  State<ReservasTab> createState() => _ReservasTabState();
}

class _ReservasTabState extends State<ReservasTab> {
  EstadoInscripcion? _filtro = EstadoInscripcion.enRevision;

  /// Filtro especial: reservas confirmadas de estudiantes que no se presentan.
  bool _soloAusentes = false;
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
            final ausentes = todas.where(ValidacionAdmin.noSePresenta).length;
            final texto = _busqueda.trim().toLowerCase();
            final visibles = todas.where((i) {
              if (_soloAusentes) {
                if (!ValidacionAdmin.noSePresenta(i)) return false;
              } else if (_filtro != null && i.estado != _filtro) {
                return false;
              }
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
                      FilterChip(
                        avatar: const Icon(Icons.person_off_outlined, size: 18),
                        label: Text('No se presentan ($ausentes)'),
                        selected: _soloAusentes,
                        onSelected: (_) => setState(() {
                          _soloAusentes = true;
                          _filtro = null;
                        }),
                      ),
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
                          mensaje: _soloAusentes
                              ? 'Nadie con reserva confirmada ha faltado a todas sus sesiones.'
                              : _filtro == EstadoInscripcion.enRevision
                                  ? 'No hay reservas pendientes de revisión.'
                                  : 'No hay reservas con ese filtro.',
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          child: CuadriculaAdaptable(
                            anchoMinimo: 480,
                            maxColumnas: 2,
                            hijos: [
                              for (var i = 0; i < visibles.length; i++)
                                Revelar(
                                  key: ValueKey(visibles[i].id),
                                  orden: i.clamp(0, 5),
                                  child: _tarjeta(context, visibles[i], usuarios[visibles[i].estudianteId], todas),
                                ),
                            ],
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
        selected: !_soloAusentes && _filtro == estado,
        onSelected: (_) => setState(() {
          _soloAusentes = false;
          _filtro = estado;
        }),
      );

  Widget _tarjeta(BuildContext context, Inscripcion r, Persona? estudiante, List<Inscripcion> todas) {
    final textos = Theme.of(context).textTheme;
    final ocupado = _procesando.contains(r.id);
    final f = r.fechaInscripcion;
    final fecha = '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} '
        '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
    final quien = estudiante == null
        ? 'Usuario eliminado del sistema'
        : '${estudiante.nombreCompleto} · ${estudiante.cedulaTexto}';
    final ausente = ValidacionAdmin.noSePresenta(r);
    final color = switch (r.estado) {
      EstadoInscripcion.confirmada => AppColors.verdeHoja,
      EstadoInscripcion.enRevision => AppColors.naranja,
      EstadoInscripcion.pendientePago => AppColors.azul,
      EstadoInscripcion.rechazada => AppColors.rojo,
      _ => AppColors.gris,
    };
    return Elevable(
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
                if (ausente) ...[
                  const EtiquetaEstado('No se presenta', color: AppColors.rojo),
                  const SizedBox(width: 6),
                ],
                EtiquetaEstado(r.estado.etiqueta, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(quien, style: estudiante == null ? textos.bodyMedium?.copyWith(color: AppColors.gris) : null),
            Text(
                'Reservada el $fecha · ${r.monto == 0 ? 'gratuita' : '\$${r.monto.toStringAsFixed(2)}'}'
                '${r.pagoId.isEmpty ? '' : ' · pago ${r.pagoId.split('_').last}'}',
                style: textos.bodySmall?.copyWith(color: AppColors.gris)),
            if (r.horarios.isNotEmpty) Text(r.horarios, style: textos.bodySmall),
            if (r.estado == EstadoInscripcion.confirmada && r.sesiones > 0)
              Text('Asistencia: ${r.sesionesAsistidas} de ${r.sesiones} sesiones',
                  style: textos.bodySmall?.copyWith(
                      color: ausente ? AppColors.rojo : AppColors.gris, fontWeight: ausente ? FontWeight.w700 : null)),
            if (r.motivo.isNotEmpty)
              Text('Motivo: ${r.motivo}', style: textos.bodySmall?.copyWith(color: AppColors.rojo)),
            if (r.estaVigente()) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (r.estado == EstadoInscripcion.enRevision) ..._botonesRevision(r, ocupado),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Cambiar disciplina'),
                    onPressed: ocupado ? null : () => _cambiar(r, todas),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.rojo),
                    icon: const Icon(Icons.event_busy_outlined),
                    label: const Text('Cancelar reserva'),
                    onPressed: ocupado ? null : () => _cancelar(r, ausente: ausente),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _botonesRevision(Inscripcion r, bool ocupado) => [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
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
      ];

  /// Ejecuta una acción sobre la reserva con su indicador de "procesando" y
  /// muestra el resultado o el motivo por el que no se pudo.
  Future<void> _ejecutar(Inscripcion r, Future<void> Function() accion, String exito) async {
    setState(() => _procesando.add(r.id));
    String mensaje;
    var ok = false;
    try {
      await accion();
      mensaje = exito;
      ok = true;
    } on OperacionNoPermitidaException catch (e) {
      mensaje = e.mensaje;
    } catch (_) {
      mensaje = 'No se pudo actualizar la reserva. Inténtalo de nuevo.';
    }
    if (!mounted) return;
    setState(() => _procesando.remove(r.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: ok ? AppColors.verdeHoja : AppColors.rojo));
  }

  Future<void> _cancelar(Inscripcion r, {required bool ausente}) async {
    final resultado = await showDialog<(String, bool)>(
      context: context,
      builder: (_) => _CancelarDialog(reserva: r, sugerirAusencia: ausente),
    );
    if (resultado == null) return;
    final (motivo, reembolsar) = resultado;
    await _ejecutar(
      r,
      () => widget.repositorio.cancelarReserva(r.id, motivo: motivo, reembolsar: reembolsar),
      r.ocupaCupo ? 'Reserva cancelada; el cupo quedó libre.' : 'Reserva cancelada.',
    );
  }

  Future<void> _cambiar(Inscripcion r, List<Inscripcion> todas) async {
    final destino = await showDialog<Deporte>(
      context: context,
      builder: (_) => _CambiarDialog(reserva: r, todas: todas, deportes: widget.repositorio.observarDeportes()),
    );
    if (destino == null) return;
    await _ejecutar(
      r,
      () => widget.repositorio.cambiarReserva(r.id, destino.codigo),
      'Reserva cambiada a ${destino.nombre}. Se le avisó al estudiante.',
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

/// Motivos frecuentes para cancelar una reserva a mano.
const motivosCancelacion = [
  'No se presentó a los entrenamientos.',
  'Lo pidió el estudiante.',
  'El pago no es válido.',
];

/// Ventana para cancelar una reserva: elige el motivo (o escribe otro) y decide
/// si el pago se marca como reembolsado. Devuelve (motivo, reembolsar).
class _CancelarDialog extends StatefulWidget {
  const _CancelarDialog({required this.reserva, required this.sugerirAusencia});

  final Inscripcion reserva;
  final bool sugerirAusencia;

  @override
  State<_CancelarDialog> createState() => _CancelarDialogState();
}

class _CancelarDialogState extends State<_CancelarDialog> {
  late String? _elegido = widget.sugerirAusencia ? motivosCancelacion.first : null;
  final _otro = TextEditingController();
  bool _reembolsar = false;

  @override
  void dispose() {
    _otro.dispose();
    super.dispose();
  }

  String get _motivo => _elegido ?? _otro.text.trim();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final r = widget.reserva;
    final tienePago = r.pagoId.isNotEmpty && r.monto > 0;
    return AlertDialog(
      title: const Text('Cancelar reserva'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r.nombreDeporte.isEmpty ? r.deporteCodigo : r.nombreDeporte}: la reserva pasa a cancelada'
                '${r.ocupaCupo ? ' y su cupo queda libre para otro estudiante' : ''}. El estudiante recibe un aviso con el motivo.',
                style: textos.bodyMedium?.copyWith(color: AppColors.gris),
              ),
              const SizedBox(height: 14),
              Text('Motivo', style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in motivosCancelacion)
                    ChoiceChip(
                      label: Text(m.substring(0, m.length - 1)),
                      selected: _elegido == m,
                      onSelected: (_) => setState(() => _elegido = m),
                    ),
                  ChoiceChip(
                    label: const Text('Otro'),
                    selected: _elegido == null,
                    onSelected: (_) => setState(() => _elegido = null),
                  ),
                ],
              ),
              if (_elegido == null) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _otro,
                  autofocus: true,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Escribe el motivo (lo verá el estudiante)'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (tienePago)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _reembolsar,
                  onChanged: (v) => setState(() => _reembolsar = v ?? false),
                  title: Text('Marcar el pago de \$${r.monto.toStringAsFixed(2)} como reembolsado'),
                  subtitle: const Text('Déjalo sin marcar si el estudiante perdió el pago por no asistir.'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Atrás')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
          onPressed: _motivo.isEmpty ? null : () => Navigator.pop(context, (_motivo, _reembolsar)),
          child: const Text('Cancelar reserva'),
        ),
      ],
    );
  }
}

/// Ventana para mover una reserva a otra disciplina. Muestra todas las demás y,
/// en las que no se puede, el motivo ([ValidacionAdmin.cambiarReserva]).
class _CambiarDialog extends StatefulWidget {
  const _CambiarDialog({required this.reserva, required this.todas, required this.deportes});

  final Inscripcion reserva;
  final List<Inscripcion> todas;
  final Stream<List<Deporte>> deportes;

  @override
  State<_CambiarDialog> createState() => _CambiarDialogState();
}

class _CambiarDialogState extends State<_CambiarDialog> {
  Deporte? _elegido;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final r = widget.reserva;
    return AlertDialog(
      title: const Text('Cambiar de disciplina'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: StreamBuilder<List<Deporte>>(
          stream: widget.deportes,
          builder: (context, snap) {
            if (snap.hasError) return const Center(child: Text('No se pudieron cargar las disciplinas.'));
            if (!snap.hasData) return const Esqueleto(filas: 3, alto: 56);
            final otras = [...snap.data!.where((d) => d.codigo != r.deporteCodigo)]
              ..sort((a, b) => a.nombre.compareTo(b.nombre));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'La reserva de ${r.nombreDeporte.isEmpty ? r.deporteCodigo : r.nombreDeporte} pasa a la disciplina que elijas, '
                  'con el mismo estado y el mismo pago. La anterior queda cancelada y el estudiante recibe un aviso.',
                  style: textos.bodyMedium?.copyWith(color: AppColors.gris),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: otras.isEmpty
                      ? const EstadoVacio(icono: Icons.sports_outlined, mensaje: 'No hay otras disciplinas.')
                      : RadioGroup<String>(
                          groupValue: _elegido?.codigo,
                          onChanged: (codigo) => setState(() => _elegido = otras.firstWhere((d) => d.codigo == codigo)),
                          child: ListView(
                            children: [
                              for (final d in otras)
                                () {
                                  final motivo = ValidacionAdmin.cambiarReserva(r, d, widget.todas);
                                  return RadioListTile<String>(
                                    value: d.codigo,
                                    enabled: motivo == null,
                                    title: Text('${d.nombre} (${d.codigo})'),
                                    subtitle: Text(
                                      motivo ?? '${d.cuposDisponibles()} de ${d.cupoMaximo} cupos libres',
                                      style: textos.bodySmall
                                          ?.copyWith(color: motivo == null ? AppColors.verdeHoja : AppColors.gris),
                                    ),
                                  );
                                }(),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Atrás')),
        FilledButton.icon(
          icon: const Icon(Icons.swap_horiz),
          onPressed: _elegido == null ? null : () => Navigator.pop(context, _elegido),
          label: Text(_elegido == null ? 'Elige una disciplina' : 'Cambiar a ${_elegido!.nombre}'),
        ),
      ],
    );
  }
}
