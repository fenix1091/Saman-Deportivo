import 'package:flutter/material.dart';

/// Reparte [hijos] en columnas del mismo ancho según el espacio disponible: en
/// una pantalla ancha caben varias tarjetas por fila y en el teléfono, una.
///
/// [anchoMinimo] es lo menos que puede medir cada tarjeta; con él se calcula
/// cuántas columnas entran, hasta [maxColumnas].
class CuadriculaAdaptable extends StatelessWidget {
  const CuadriculaAdaptable({
    super.key,
    required this.hijos,
    this.anchoMinimo = 340,
    this.maxColumnas = 3,
    this.espacio = 12,
  });

  final List<Widget> hijos;
  final double anchoMinimo;
  final int maxColumnas;
  final double espacio;

  /// Columnas que caben en [ancho].
  static int columnasPara(double ancho, {double anchoMinimo = 340, int maxColumnas = 3, double espacio = 12}) =>
      ((ancho + espacio) ~/ (anchoMinimo + espacio)).clamp(1, maxColumnas);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columnas = columnasPara(c.maxWidth, anchoMinimo: anchoMinimo, maxColumnas: maxColumnas, espacio: espacio);
      final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
      // Ocupa todo el ancho aunque haya una sola tarjeta (dentro de un
      // desplazamiento el ancho es libre y el Wrap se encogería al centro).
      return SizedBox(
        width: c.maxWidth,
        child: Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [for (final h in hijos) SizedBox(width: ancho, child: h)],
        ),
      );
    });
  }
}
