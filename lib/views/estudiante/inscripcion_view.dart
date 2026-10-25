import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/validacion_inscripcion.dart';
import '../../models/deporte.dart';
import '../../models/pago.dart';
import '../../viewmodels/inscripcion_view_model.dart';
import '../../widgets/acciones_sesion.dart';
import '../../widgets/barra_cupos.dart';
import '../../widgets/formulario_centrado.dart';

/// Inscripción en un deporte con validación, control de cupo y pago (CU-07).
class InscripcionView extends StatelessWidget {
  const InscripcionView({super.key});

  String _dinero(double monto) => '\$${monto.toStringAsFixed(2)}';

  Future<void> _pagar(BuildContext context) async {
    final vm = context.read<InscripcionViewModel>();
    final deporte = vm.deporte!;
    if (vm.monto > 0) {
      final aprobado = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          icon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.azul),
          title: const Text('PayPal (sandbox)'),
          content: Text(
            'Vas a pagar ${_dinero(vm.monto)} a Samán Deportivo por la reserva del cupo en '
            '${deporte.nombre} (${deporte.codigo}).',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(contexto).pop(false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.of(contexto).pop(true),
              child: const Text('Aprobar pago'),
            ),
          ],
        ),
      );
      if (aprobado != true) return;
    }
    await vm.inscribirYPagar();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InscripcionViewModel>();
    final deporte = vm.deporte;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscripción'),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/catalogo/${Uri.encodeComponent(vm.codigo)}'),
        ),
        actions: const [AccionesSesion()],
      ),
      body: () {
        if (vm.cargando) return const Center(child: CircularProgressIndicator());
        if (deporte == null || !deporte.activo) {
          return const Center(child: Text('Esta disciplina no está disponible.'));
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: vm.confirmada
                  ? [_Comprobante(deporte: deporte, pago: vm.pago)]
                  : [
                      _Resumen(deporte: deporte, horarios: vm.horarios, dinero: _dinero),
                      _Requisitos(resultado: vm.validacion),
                      if (vm.reservaPendiente != null) ...[
                        const SizedBox(height: 16),
                        _Aviso(
                          'Tienes este cupo apartado hasta las ${_hora(vm.reservaPendiente!.vencePago)}. '
                          'Completa el pago antes de esa hora.',
                        ),
                      ],
                      if (vm.error != null) ...[const SizedBox(height: 16), MensajeError(vm.error!)],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: vm.puedePagar ? () => _pagar(context) : null,
                        icon: vm.procesando
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(vm.monto > 0 ? Icons.lock_outline : Icons.check),
                        label: Text(vm.monto > 0 ? 'Pagar ${_dinero(vm.monto)} con PayPal' : 'Confirmar inscripción'),
                      ),
                      if (vm.monto > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'El pago se hace en PayPal; Samán Deportivo solo guarda la referencia de la orden.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.gris),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
            ),
          ),
        );
      }(),
    );
  }
}

String _hora(DateTime f) => '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

class _Resumen extends StatelessWidget {
  const _Resumen({required this.deporte, required this.horarios, required this.dinero});

  final Deporte deporte;
  final List<Horario> horarios;
  final String Function(double) dinero;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deporte.nombre, style: textos.titleLarge),
            Text(deporte.codigo, style: textos.bodySmall?.copyWith(color: AppColors.gris)),
            const SizedBox(height: 12),
            for (final h in horarios)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 18, color: AppColors.verdeSaman),
                    const SizedBox(width: 8),
                    Expanded(child: Text(h.lugar.isEmpty ? h.etiqueta : '${h.etiqueta} · ${h.lugar}')),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            BarraCupos(deporte: deporte),
            const SizedBox(height: 12),
            Text(
              deporte.costoReserva == 0 ? 'Reserva gratuita' : 'Reserva del cupo: ${dinero(deporte.costoReserva)}',
              style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de requisitos con su resultado y, si falla, cómo resolverlo (CU-07 A1-A3, CU-08).
class _Requisitos extends StatelessWidget {
  const _Requisitos({required this.resultado});

  final ResultadoValidacion? resultado;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    final textos = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Requisitos', style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (r == null)
              const LinearProgressIndicator()
            else
              for (final requisito in Requisito.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        r.cumple(requisito) ? Icons.check_circle : Icons.cancel,
                        size: 20,
                        color: r.cumple(requisito) ? AppColors.verdeHoja : AppColors.rojo,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(requisito.etiqueta, style: textos.bodyLarge),
                            if (r.motivoDe(requisito) case final falla?)
                              Text(falla.motivo, style: textos.bodySmall?.copyWith(color: AppColors.rojo)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Comprobante de la inscripción confirmada (CU-07, paso 7).
class _Comprobante extends StatelessWidget {
  const _Comprobante({required this.deporte, required this.pago});

  final Deporte deporte;
  final Pago? pago;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final p = pago;
    Widget fila(String etiqueta, String valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(etiqueta, style: textos.bodyMedium?.copyWith(color: AppColors.gris))),
              Flexible(child: Text(valor, style: textos.bodyMedium, textAlign: TextAlign.end)),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.verified, size: 56, color: AppColors.verdeHoja),
            const SizedBox(height: 8),
            Text('¡Inscripción confirmada!', style: textos.titleLarge),
            const SizedBox(height: 4),
            Text('Ya tienes tu cupo en ${deporte.nombre}.', textAlign: TextAlign.center),
            const Divider(height: 32),
            fila('Disciplina', '${deporte.nombre} (${deporte.codigo})'),
            if (p != null) ...[
              fila('Monto', p.monto == 0 ? 'Gratuita' : '\$${p.monto.toStringAsFixed(2)} ${p.moneda}'),
              fila('Método', p.metodo),
              fila('Referencia', p.referenciaExterna),
              fila('Fecha', '${p.fecha.day}/${p.fecha.month}/${p.fecha.year} ${_hora(p.fecha)}'),
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => context.go('/catalogo'),
              child: const Text('Volver al catálogo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.verdeClaro, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.verdeSaman),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
