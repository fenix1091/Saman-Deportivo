import 'package:flutter/material.dart';

import '../../core/novedades.dart';
import '../../core/theme.dart';

/// Ventana con el registro de actualizaciones del sistema (solo para el administrador).
class NovedadesDialog extends StatelessWidget {
  const NovedadesDialog({super.key, this.lista});

  /// Actualizaciones a mostrar; por defecto, las del sistema.
  final List<Novedad>? lista;

  static Future<void> mostrar(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const NovedadesDialog());

  static const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  static String fechaCorta(DateTime f) => '${f.day} ${_meses[f.month - 1]} ${f.year}';

  @override
  Widget build(BuildContext context) {
    final todas = lista ?? novedades;
    final textos = Theme.of(context).textTheme;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.naranjaClaro, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.history, color: AppColors.naranjaProfundo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Registro de actualizaciones'),
                Text(
                  todas.isEmpty ? 'Sin actualizaciones registradas' : 'Versión actual: ${todas.first.version}',
                  style: textos.bodySmall?.copyWith(color: AppColors.gris),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: todas.length,
          itemBuilder: (_, i) => _Entrada(novedad: todas[i], actual: i == 0, ultima: i == todas.length - 1),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

/// Una versión dentro de la línea de tiempo.
class _Entrada extends StatelessWidget {
  const _Entrada({required this.novedad, required this.actual, required this.ultima});

  final Novedad novedad;
  final bool actual;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Punto y línea de la línea de tiempo.
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: actual ? AppColors.naranjaProfundo : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: actual ? AppColors.naranjaProfundo : AppColors.borde, width: 2),
                  ),
                ),
                if (!ultima) Expanded(child: Container(width: 2, color: AppColors.borde)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: ultima ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: actual ? AppColors.naranjaProfundo : AppColors.naranjaClaro,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Versión ${novedad.version}',
                          style: TextStyle(
                            color: actual ? Colors.white : AppColors.naranjaProfundo,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(NovedadesDialog.fechaCorta(novedad.fecha),
                          style: textos.bodySmall?.copyWith(color: AppColors.gris)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(novedad.titulo, style: textos.titleMedium),
                  const SizedBox(height: 6),
                  for (final cambio in novedad.cambios)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 7, right: 8),
                            child: Icon(Icons.circle, size: 5, color: AppColors.gris),
                          ),
                          Expanded(child: Text(cambio, style: textos.bodyMedium?.copyWith(height: 1.4))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
