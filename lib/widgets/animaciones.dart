import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Revela a su hijo con un fundido y un leve ascenso cuando entra en pantalla.
///
/// [orden] escalona varios elementos de la misma sección. Si el sistema pide
/// reducir las animaciones, el contenido aparece de inmediato.
class Revelar extends StatefulWidget {
  const Revelar({super.key, required this.child, this.orden = 0});

  final Widget child;
  final int orden;

  @override
  State<Revelar> createState() => _RevelarState();
}

class _RevelarState extends State<Revelar> with SingleTickerProviderStateMixin {
  static const _duracion = 550;
  static const _escalon = 90;

  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _duracion + widget.orden * _escalon),
  );
  late final Animation<double> _curva = CurvedAnimation(
    parent: _control,
    curve: Interval(
      widget.orden * _escalon / (_duracion + widget.orden * _escalon),
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  ScrollPosition? _posicion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _control.value = 1;
      return;
    }
    _posicion?.removeListener(_revisar);
    _posicion = Scrollable.maybeOf(context)?.position;
    _posicion?.addListener(_revisar);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revisar());
  }

  void _revisar() {
    if (!mounted || _control.isAnimating || _control.isCompleted) return;
    final caja = context.findRenderObject();
    if (caja is! RenderBox || !caja.attached) return;
    final arriba = caja.localToGlobal(Offset.zero).dy;
    if (arriba < MediaQuery.sizeOf(context).height * 0.92) {
      _posicion?.removeListener(_revisar);
      _control.forward();
    }
  }

  @override
  void dispose() {
    _posicion?.removeListener(_revisar);
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curva,
      child: widget.child,
      builder: (_, hijo) => Opacity(
        opacity: _curva.value,
        child: Transform.translate(offset: Offset(0, 28 * (1 - _curva.value)), child: hijo),
      ),
    );
  }
}

/// Tarjeta blanca que sube y proyecta sombra al pasar el ratón (micro-interacción).
class Elevable extends StatefulWidget {
  const Elevable({super.key, required this.child, this.radio = 20, this.alPulsar});

  final Widget child;
  final double radio;
  final VoidCallback? alPulsar;

  @override
  State<Elevable> createState() => _ElevableState();
}

class _ElevableState extends State<Elevable> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(widget.radio);
    final animar = !MediaQuery.of(context).disableAnimations;
    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: animar ? 220 : 0),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _encima ? -6 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: forma,
          border: Border.all(color: _encima ? AppColors.naranja.withValues(alpha: 0.45) : const Color(0xFFE3E8EE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _encima ? 0.10 : 0.04),
              blurRadius: _encima ? 28 : 12,
              offset: Offset(0, _encima ? 14 : 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(borderRadius: forma, onTap: widget.alPulsar, child: widget.child),
        ),
      ),
    );
  }
}

/// Esqueleto de carga: bloques grises que laten mientras llegan los datos.
/// Reserva el espacio de la lista para que nada salte al cargar.
class Esqueleto extends StatefulWidget {
  const Esqueleto({super.key, this.filas = 3, this.alto = 116});

  final int filas;
  final double alto;

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto> with SingleTickerProviderStateMixin {
  late final AnimationController _control =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _control.stop();
      _control.value = 0.5;
    } else if (!_control.isAnimating) {
      _control.repeat(reverse: true);
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
      label: 'Cargando',
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.filas,
        itemBuilder: (_, i) => AnimatedBuilder(
          animation: _control,
          builder: (_, __) => Container(
            height: widget.alto,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Color.lerp(const Color(0xFFEDF1EE), const Color(0xFFDDE3EA), _control.value),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de estado con color de fondo; el texto siempre va en blanco sobre
/// colores con contraste suficiente.
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.texto, {super.key, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Estado vacío con icono, mensaje y una acción opcional.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.icono, required this.mensaje, this.accion});

  final IconData icono;
  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Revelar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 48, color: AppColors.gris),
              const SizedBox(height: 12),
              Text(mensaje, textAlign: TextAlign.center),
              if (accion != null) ...[const SizedBox(height: 12), accion!],
            ],
          ),
        ),
      ),
    );
  }
}
