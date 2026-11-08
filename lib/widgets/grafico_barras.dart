import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Una barra del gráfico: etiqueta, valor y, si aplica, el máximo de referencia.
class DatoBarra {
  const DatoBarra({required this.etiqueta, required this.valor, this.detalle = '', this.color});

  final String etiqueta;
  final double valor;

  /// Texto que acompaña al valor (por ejemplo "12 de 20").
  final String detalle;
  final Color? color;
}

/// Gráfico de barras horizontales dibujado con CustomPaint, sin dependencias.
///
/// Las barras crecen desde cero al aparecer (salvo si el sistema pide reducir las
/// animaciones) y cada una lleva su etiqueta y su valor, así se lee sin leyenda.
class GraficoBarras extends StatelessWidget {
  const GraficoBarras({
    super.key,
    required this.datos,
    this.maximo,
    this.formato,
    this.altoBarra = 22,
  });

  final List<DatoBarra> datos;

  /// Valor que llena la barra; si no se da, se usa el mayor de los datos.
  final double? maximo;

  /// Cómo mostrar el valor; por defecto, sin decimales.
  final String Function(double)? formato;
  final double altoBarra;

  @override
  Widget build(BuildContext context) {
    if (datos.isEmpty) {
      return Text('Sin datos todavía.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.gris));
    }
    final animar = !MediaQuery.of(context).disableAnimations;
    final tope = maximo ?? datos.map((d) => d.valor).fold<double>(0, (a, b) => a > b ? a : b);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animar ? 0 : 1, end: 1),
      duration: Duration(milliseconds: animar ? 700 : 0),
      curve: Curves.easeOutCubic,
      builder: (context, progreso, _) => CustomPaint(
        size: Size(double.infinity, datos.length * (altoBarra + 22.0)),
        painter: _PintorBarras(
          datos: datos,
          tope: tope <= 0 ? 1 : tope,
          progreso: progreso,
          altoBarra: altoBarra,
          formato: formato ?? ((v) => v.round().toString()),
          estiloEtiqueta: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.texto),
          estiloValor: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w700),
          direccion: Directionality.of(context),
        ),
      ),
    );
  }
}

class _PintorBarras extends CustomPainter {
  _PintorBarras({
    required this.datos,
    required this.tope,
    required this.progreso,
    required this.altoBarra,
    required this.formato,
    required this.estiloEtiqueta,
    required this.estiloValor,
    required this.direccion,
  });

  final List<DatoBarra> datos;
  final double tope;
  final double progreso;
  final double altoBarra;
  final String Function(double) formato;
  final TextStyle estiloEtiqueta;
  final TextStyle estiloValor;
  final TextDirection direccion;

  @override
  void paint(Canvas canvas, Size size) {
    const alturaFila = 22.0;
    final fondo = Paint()..color = const Color(0xFFEDF1EE);
    for (var i = 0; i < datos.length; i++) {
      final d = datos[i];
      final y = i * (altoBarra + alturaFila);
      // Etiqueta y valor en la línea de arriba.
      final etiqueta = TextPainter(
        text: TextSpan(text: d.etiqueta, style: estiloEtiqueta),
        textDirection: direccion,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: size.width * 0.65);
      etiqueta.paint(canvas, Offset(0, y));
      final texto = d.detalle.isEmpty ? formato(d.valor * progreso) : d.detalle;
      final valor = TextPainter(text: TextSpan(text: texto, style: estiloValor), textDirection: direccion)..layout();
      valor.paint(canvas, Offset(size.width - valor.width, y));
      // Barra.
      final top = y + alturaFila - 2;
      final radio = Radius.circular(altoBarra / 2);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, top, size.width, altoBarra), radio), fondo);
      final ancho = (d.valor / tope).clamp(0.0, 1.0) * size.width * progreso;
      if (ancho > 0) {
        final pincel = Paint()..color = d.color ?? AppColors.naranja;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(0, top, ancho < altoBarra ? altoBarra : ancho, altoBarra), radio),
          pincel,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PintorBarras viejo) => viejo.progreso != progreso || viejo.datos != datos || viejo.tope != tope;
}

/// Tarjeta con una cifra grande y su etiqueta, para los resúmenes.
class TarjetaCifra extends StatelessWidget {
  const TarjetaCifra(
      {super.key, required this.icono, required this.valor, required this.etiqueta, this.color = AppColors.verdeSaman});

  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(height: 10),
          Text(valor, style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: color)),
          Text(etiqueta, style: textos.bodySmall?.copyWith(color: AppColors.gris)),
        ],
      ),
    );
  }
}
