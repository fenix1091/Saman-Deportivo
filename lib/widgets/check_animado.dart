import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Marca de "listo" animada: el círculo crece con un pequeño rebote, el
/// aro se dibuja alrededor, la palomita se traza de izquierda a derecha y
/// salen unas chispas. Si el sistema pide menos animaciones, aparece quieta.
class CheckAnimado extends StatefulWidget {
  const CheckAnimado({super.key, this.tamano = 112, this.color = AppColors.verdeHoja});

  final double tamano;
  final Color color;

  @override
  State<CheckAnimado> createState() => _CheckAnimadoState();
}

class _CheckAnimadoState extends State<CheckAnimado> with SingleTickerProviderStateMixin {
  late final AnimationController _control =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _control.value = 1;
    } else if (!_control.isAnimating && _control.value == 0) {
      _control.forward();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Listo',
      child: SizedBox.square(
        dimension: widget.tamano,
        child: AnimatedBuilder(
          animation: _control,
          builder: (_, __) => CustomPaint(painter: _PintorCheck(_control.value, widget.color)),
        ),
      ),
    );
  }
}

class _PintorCheck extends CustomPainter {
  _PintorCheck(this.t, this.color);

  final double t;
  final Color color;

  /// Avance de [t] dentro del tramo [desde, hasta], de 0 a 1.
  double _tramo(double desde, double hasta, [Curve curva = Curves.easeOutCubic]) =>
      curva.transform(((t - desde) / (hasta - desde)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.width * 0.36;

    // Halo suave que se expande y se desvanece.
    final halo = _tramo(0.15, 0.75);
    if (halo > 0 && halo < 1) {
      canvas.drawCircle(
        centro,
        radio * (1 + 0.38 * halo),
        Paint()..color = color.withValues(alpha: 0.22 * (1 - halo)),
      );
    }

    // Círculo lleno con rebote.
    final escala = _tramo(0.0, 0.45, Curves.elasticOut);
    canvas.drawCircle(centro, radio * escala, Paint()..color = color);

    // Aro que se dibuja alrededor.
    final aro = _tramo(0.1, 0.55);
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio * 1.18),
      -math.pi / 2,
      2 * math.pi * aro,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.025
        ..strokeCap = StrokeCap.round,
    );

    // Palomita trazada.
    final trazo = _tramo(0.38, 0.72);
    if (trazo > 0) {
      final palomita = Path()
        ..moveTo(centro.dx - radio * 0.42, centro.dy + radio * 0.02)
        ..lineTo(centro.dx - radio * 0.1, centro.dy + radio * 0.34)
        ..lineTo(centro.dx + radio * 0.46, centro.dy - radio * 0.3);
      final parcial = Path();
      for (final PathMetric m in palomita.computeMetrics()) {
        parcial.addPath(m.extractPath(0, m.length * trazo), Offset.zero);
      }
      canvas.drawPath(
        parcial,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.075
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Chispas que salen hacia afuera y se apagan.
    final chispas = _tramo(0.5, 1.0);
    if (chispas > 0 && chispas < 1) {
      const colores = [AppColors.naranja, AppColors.verdeHoja, AppColors.azul];
      for (var i = 0; i < 10; i++) {
        final angulo = 2 * math.pi * i / 10 - math.pi / 2;
        final distancia = radio * (1.25 + 0.45 * chispas);
        final punto = centro + Offset(math.cos(angulo), math.sin(angulo)) * distancia;
        canvas.drawCircle(
          punto,
          size.width * 0.028 * (1 - chispas),
          Paint()..color = colores[i % colores.length].withValues(alpha: 1 - chispas),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PintorCheck viejo) => viejo.t != t || viejo.color != color;
}

/// Ventana breve de celebración tras un pago correcto. Se cierra sola.
class VentanaPagoExitoso extends StatefulWidget {
  const VentanaPagoExitoso({super.key, required this.titulo, required this.detalle});

  final String titulo;
  final String detalle;

  /// Muestra la ventana y espera a que se cierre (sola o con el botón).
  static Future<void> mostrar(BuildContext context, {required String titulo, required String detalle}) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => VentanaPagoExitoso(titulo: titulo, detalle: detalle),
      transitionBuilder: (_, animacion, __, hijo) {
        final curva = CurvedAnimation(parent: animacion, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: animacion,
          child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(curva), child: hijo),
        );
      },
    );
  }

  @override
  State<VentanaPagoExitoso> createState() => _VentanaPagoExitosoState();
}

class _VentanaPagoExitosoState extends State<VentanaPagoExitoso> {
  bool _cerrada = false;
  late final Timer _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer(const Duration(milliseconds: 2600), _cerrar);
  }

  @override
  void dispose() {
    _reloj.cancel();
    super.dispose();
  }

  void _cerrar() {
    if (_cerrada || !mounted) return;
    _cerrada = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Center(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadios.ventana),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CheckAnimado(),
                const SizedBox(height: 16),
                Text(widget.titulo, style: textos.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(widget.detalle,
                    style: textos.bodyMedium?.copyWith(color: AppColors.gris), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton(onPressed: _cerrar, child: const Text('Ver comprobante')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
