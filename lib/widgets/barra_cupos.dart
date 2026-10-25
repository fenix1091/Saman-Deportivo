import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/deporte.dart';

/// Barra de cupos libres sobre el cupo máximo (CU-04, paso 2).
///
/// Verde con cupos de sobra, naranja cuando quedan pocos y roja sin cupos.
class BarraCupos extends StatelessWidget {
  const BarraCupos({super.key, required this.deporte});

  /// Desde este porcentaje de ocupación se avisa que quedan pocos cupos.
  static const umbralPocos = 0.8;

  final Deporte deporte;

  @override
  Widget build(BuildContext context) {
    final libres = deporte.cuposDisponibles();
    final maximo = deporte.cupoMaximo;
    final ocupacion = maximo == 0 ? 1.0 : (maximo - libres) / maximo;
    final color = libres == 0
        ? AppColors.rojo
        : ocupacion >= umbralPocos
            ? AppColors.naranja
            : AppColors.verdeHoja;
    final texto = libres == 0 ? 'Sin cupos' : '$libres de $maximo cupos libres';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ocupacion.clamp(0, 1),
            minHeight: 8,
            color: color,
            backgroundColor: AppColors.verdeClaro,
            semanticsLabel: 'Ocupación de cupos',
          ),
        ),
        const SizedBox(height: 4),
        Text(texto, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
