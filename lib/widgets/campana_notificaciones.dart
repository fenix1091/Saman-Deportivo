import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/notificacion.dart';
import '../viewmodels/notificaciones_view_model.dart';

/// Campana con el contador de avisos sin leer. Al pulsarla abre la lista.
class CampanaNotificaciones extends StatelessWidget {
  const CampanaNotificaciones({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificacionesViewModel>();
    final n = vm.noLeidas;
    return IconButton(
      tooltip: n == 0 ? 'Notificaciones' : '$n ${n == 1 ? 'aviso sin leer' : 'avisos sin leer'}',
      onPressed: () => _abrir(context),
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text('$n'),
        backgroundColor: AppColors.naranja,
        child: Icon(n > 0 ? Icons.notifications_active_outlined : Icons.notifications_none),
      ),
    );
  }

  void _abrir(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    if (ancho < 720) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<NotificacionesViewModel>(),
          child: const SizedBox(height: 520, child: _ListaNotificaciones()),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<NotificacionesViewModel>(),
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
            child: Material(
              color: Colors.white,
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: const SizedBox(width: 400, height: 520, child: _ListaNotificaciones()),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListaNotificaciones extends StatelessWidget {
  const _ListaNotificaciones();

  static (IconData, Color) _estilo(TipoNotificacion t) => switch (t) {
        TipoNotificacion.reservaRecibida => (Icons.hourglass_top, AppColors.naranja),
        TipoNotificacion.reservaConfirmada => (Icons.verified_outlined, AppColors.verdeHoja),
        TipoNotificacion.reservaRechazada => (Icons.cancel_outlined, AppColors.rojo),
        TipoNotificacion.inscripcionDirecta => (Icons.how_to_reg_outlined, AppColors.verdeHoja),
        TipoNotificacion.retiro => (Icons.person_remove_outlined, AppColors.gris),
        TipoNotificacion.aviso => (Icons.info_outline, AppColors.azul),
      };

  static String _hace(DateTime f) {
    final d = DateTime.now().difference(f);
    if (d.inMinutes < 1) return 'ahora';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    if (d.inDays == 1) return 'ayer';
    if (d.inDays < 7) return 'hace ${d.inDays} días';
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificacionesViewModel>();
    final textos = Theme.of(context).textTheme;
    final lista = vm.notificaciones;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(
            children: [
              Expanded(child: Text('Notificaciones', style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              if (vm.noLeidas > 0) TextButton(onPressed: vm.marcarTodas, child: const Text('Marcar todas leídas')),
              IconButton(
                  tooltip: 'Cerrar', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: lista.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_off_outlined, size: 44, color: AppColors.gris),
                        const SizedBox(height: 10),
                        Text('No tienes avisos todavía.', style: textos.bodyLarge),
                        Text('Aquí verás las confirmaciones de tus reservas y los cambios importantes.',
                            style: textos.bodySmall?.copyWith(color: AppColors.gris), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, i) {
                    final n = lista[i];
                    final (icono, color) = _estilo(n.tipo);
                    return ListTile(
                      tileColor: n.leida ? null : AppColors.naranjaClaro.withValues(alpha: 0.55),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                        child: Icon(icono, color: color),
                      ),
                      title: Text(n.titulo,
                          style: textos.bodyLarge?.copyWith(fontWeight: n.leida ? FontWeight.w500 : FontWeight.w700)),
                      subtitle: Text('${n.mensaje}\n${_hace(n.fecha)}', style: textos.bodySmall),
                      isThreeLine: true,
                      trailing: n.leida ? null : const Icon(Icons.circle, size: 10, color: AppColors.naranja),
                      onTap: () {
                        vm.marcarLeida(n);
                        Navigator.of(context).pop();
                        if (n.ruta.isNotEmpty) context.go(n.ruta);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
