import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/inscripcion.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/mis_inscripciones_view_model.dart';
import '../widgets/cuadricula_adaptable.dart';
import '../widgets/animaciones.dart';
import '../widgets/panel_con_menu.dart';
import 'dialogs/publicar_resena_dialog.dart';

/// Reservas del estudiante (CU-10, CU-11, CU-12): vigentes e historial, en tiempo real.
class MisInscripcionesView extends StatefulWidget {
  const MisInscripcionesView({super.key});

  @override
  State<MisInscripcionesView> createState() => _MisInscripcionesViewState();
}

class _MisInscripcionesViewState extends State<MisInscripcionesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = context.read<AuthViewModel>();
      if (authVM.usuario != null) {
        context.read<MisInscripcionesViewModel>().escucharInscripciones(authVM.usuario!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MisInscripcionesViewModel>();

    return DefaultTabController(
      length: 2,
      child: PanelConMenu(
        titulo: const Text('Mis inscripciones'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Vigentes'),
            Tab(text: 'Historial'),
          ],
        ),
        body: vm.cargando
            ? const Esqueleto(filas: 3, alto: 150)
            : TabBarView(
                children: [
                  _ListaInscripciones(inscripciones: vm.vigentes, esVigente: true),
                  _ListaInscripciones(inscripciones: vm.historial, esVigente: false),
                ],
              ),
      ),
    );
  }
}

class _ListaInscripciones extends StatelessWidget {
  const _ListaInscripciones({required this.inscripciones, required this.esVigente});

  final List<Inscripcion> inscripciones;
  final bool esVigente;

  @override
  Widget build(BuildContext context) {
    if (inscripciones.isEmpty) {
      return EstadoVacio(
        icono: esVigente ? Icons.event_busy_outlined : Icons.history,
        mensaje: esVigente ? 'No tienes reservas vigentes.' : 'Aún no hay inscripciones en tu historial.',
        accion: esVigente
            ? FilledButton(onPressed: () => context.go('/catalogo'), child: const Text('Explorar deportes'))
            : null,
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CuadriculaAdaptable(
            anchoMinimo: 460,
            maxColumnas: 2,
            hijos: [
              for (var index = 0; index < inscripciones.length; index++)
                Revelar(
                  key: ValueKey(inscripciones[index].id),
                  orden: index.clamp(0, 5),
                  child: _TarjetaInscripcion(inscripcion: inscripciones[index], esVigente: esVigente),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaInscripcion extends StatelessWidget {
  const _TarjetaInscripcion({required this.inscripcion, required this.esVigente});

  final Inscripcion inscripcion;
  final bool esVigente;

  Color _color(EstadoInscripcion e) => switch (e) {
        EstadoInscripcion.confirmada => AppColors.verdeHoja,
        EstadoInscripcion.enRevision => AppColors.naranja,
        EstadoInscripcion.pendientePago => AppColors.azul,
        EstadoInscripcion.cancelada || EstadoInscripcion.expirada => AppColors.gris,
        EstadoInscripcion.rechazada => AppColors.rojo,
      };

  String _explicacion(EstadoInscripcion e) => switch (e) {
        EstadoInscripcion.pendientePago =>
          'Completa el pago antes de las ${_hora(inscripcion.vencePago)} para apartar tu cupo.',
        EstadoInscripcion.enRevision =>
          'Pago recibido. Tu cupo está apartado mientras la Coordinación de Deportes valida el pago.',
        EstadoInscripcion.confirmada =>
          'Tu cupo está confirmado. Asiste a los entrenamientos para poder dejar tu reseña.',
        EstadoInscripcion.cancelada => inscripcion.motivo.isEmpty ? 'Cancelaste esta inscripción.' : inscripcion.motivo,
        EstadoInscripcion.rechazada => inscripcion.motivo.isEmpty ? 'La reserva fue rechazada.' : inscripcion.motivo,
        EstadoInscripcion.expirada => 'La reserva venció sin completar el pago.',
      };

  static String _hora(DateTime f) => '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final color = _color(inscripcion.estado);
    final nombre = inscripcion.nombreDeporte.isEmpty ? inscripcion.deporteCodigo : inscripcion.nombreDeporte;
    final confirmada = inscripcion.estado == EstadoInscripcion.confirmada;
    final puedeResenar = confirmada && inscripcion.sesionesAsistidas > 0;

    Widget dato(IconData icono, String valor) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 16, color: AppColors.gris),
              const SizedBox(width: 6),
              Expanded(child: Text(valor, style: textos.bodySmall)),
            ],
          ),
        );

    return Padding(
      padding: EdgeInsets.zero,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text(inscripcion.deporteCodigo, style: textos.bodySmall?.copyWith(color: AppColors.gris)),
                      ],
                    ),
                  ),
                  EtiquetaEstado(inscripcion.estado.etiqueta, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(_explicacion(inscripcion.estado), style: textos.bodyMedium),
              if (inscripcion.horarios.isNotEmpty) dato(Icons.schedule, inscripcion.horarios),
              if (inscripcion.duracion.isNotEmpty) dato(Icons.calendar_month_outlined, inscripcion.duracion),
              dato(Icons.payments_outlined,
                  inscripcion.monto == 0 ? 'Reserva gratuita' : 'Monto: \$${inscripcion.monto.toStringAsFixed(2)}'),
              if (confirmada)
                dato(
                  Icons.fact_check_outlined,
                  inscripcion.sesiones == 0
                      ? 'Asistencia: aún no hay sesiones registradas'
                      : 'Asistencia: ${inscripcion.sesionesAsistidas} de ${inscripcion.sesiones} sesiones '
                          '(${inscripcion.porcentajeAsistencia.round()} %)',
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (confirmada)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Dejar reseña'),
                      onPressed: puedeResenar
                          ? () => showDialog(
                                context: context,
                                builder: (_) => PublicarResenaDialog(
                                    deporteCodigo: inscripcion.deporteCodigo, nombreDeporte: inscripcion.nombreDeporte),
                              )
                          : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Podrás reseñar cuando hayas asistido al menos a un entrenamiento.'),
                              )),
                    ),
                  if (inscripcion.estado == EstadoInscripcion.pendientePago)
                    FilledButton.icon(
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Completar pago'),
                      onPressed: () =>
                          context.push('/estudiante/inscribir/${Uri.encodeComponent(inscripcion.deporteCodigo)}'),
                    ),
                  if (esVigente && inscripcion.estaVigente())
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppColors.rojo),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancelar inscripción'),
                      onPressed: () => _confirmarCancelacion(context, inscripcion, nombre),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmarCancelacion(BuildContext context, Inscripcion inscripcion, String nombre) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar inscripción'),
        content: Text(
          inscripcion.devuelvePagoAlCancelar
              ? 'Tu inscripción en $nombre aún no ha sido aprobada, así que si la cancelas se te devolverán '
                  '\$${inscripcion.monto.toStringAsFixed(2)} a la cuenta de PayPal con la que pagaste. '
                  '¿Quieres cancelarla?'
              : inscripcion.ocupaCupo
                  ? '¿Seguro que quieres cancelar tu inscripción en $nombre? Se liberará tu cupo.'
                  : '¿Seguro que quieres cancelar tu reserva en $nombre?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Atrás')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rojo),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final vm = context.read<MisInscripcionesViewModel>();
              final devolucion = await vm.cancelarInscripcion(inscripcion.id, inscripcion.deporteCodigo);
              if (!context.mounted) return;
              if (devolucion != null && devolucion > 0) {
                await showDialog<void>(
                  context: context,
                  builder: (contexto) => AlertDialog(
                    icon: const Icon(Icons.currency_exchange, color: AppColors.verdeHoja, size: 40),
                    title: const Text('Se te devolverá el dinero'),
                    content: Text(
                      'Cancelaste tu inscripción en $nombre. Como todavía no estaba aprobada, la inscripción no '
                      'se completó y se te devolverán \$${devolucion.toStringAsFixed(2)} a la cuenta de PayPal con '
                      'la que pagaste.\n\nLa Coordinación de Deportes ya recibió el aviso; te avisaremos cuando la '
                      'devolución esté hecha.',
                    ),
                    actions: [
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: () => Navigator.pop(contexto),
                        child: const Text('Entendido'),
                      ),
                    ],
                  ),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(devolucion != null ? 'Inscripción cancelada' : vm.error ?? 'No se pudo cancelar')),
              );
            },
            child: const Text('Confirmar cancelación'),
          ),
        ],
      ),
    );
  }
}
