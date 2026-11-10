import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

/// Marco de las pantallas de acceso (entrar, crear cuenta, recuperar contraseña).
///
/// En escritorio parte la pantalla en dos: a la izquierda la foto con la marca y a
/// la derecha el formulario. En el teléfono la foto pasa a ser una cabecera (RNF-01).
class MarcoAcceso extends StatelessWidget {
  const MarcoAcceso({
    super.key,
    required this.child,
    this.lema = 'Tu deporte empieza aquí',
    this.detalle = 'Consulta las disciplinas de la UNIMET, reserva tu cupo y lleva tu asistencia en un solo lugar.',
    this.conVolver = true,
  });

  /// El formulario.
  final Widget child;

  /// Frase grande sobre la foto.
  final String lema;
  final String detalle;

  /// Muestra el botón "Volver" sobre el formulario.
  final bool conVolver;

  static const _foto = 'design/fotos/acceso.jpg';

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final partido = ancho >= 960;
    final formulario = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, partido ? 32 : 20, 24, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (conVolver) const Align(alignment: Alignment.centerLeft, child: _Volver()),
              SizedBox(height: conVolver ? 12 : 24),
              child,
            ],
          ),
        ),
      ),
    );

    if (partido) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            Expanded(flex: 5, child: _Panel(lema: lema, detalle: detalle)),
            Expanded(flex: 6, child: SafeArea(child: formulario)),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 132, child: _Panel.cabecera()),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (conVolver) const Align(alignment: Alignment.centerLeft, child: _Volver()),
                        const SizedBox(height: 8),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Regresa a la pantalla anterior o, si se llegó directo, a la de bienvenida.
class _Volver extends StatelessWidget {
  const _Volver();

  @override
  Widget build(BuildContext context) => TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gris,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 44),
        ),
        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('Volver'),
      );
}

/// Foto con velo naranja y la marca encima.
class _Panel extends StatelessWidget {
  const _Panel({required this.lema, required this.detalle}) : compacto = false;

  const _Panel.cabecera()
      : lema = '',
        detalle = '',
        compacto = true;

  final String lema;
  final String detalle;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final logo = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Image.asset('design/marca/logo_horizontal.png',
          height: compacto ? 44 : 52, semanticLabel: 'Samán Deportivo'),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(MarcoAcceso._foto, fit: BoxFit.cover, excludeFromSemantics: true),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xBFF58220), Color(0xE6C2410C)],
            ),
          ),
        ),
        if (compacto)
          Center(child: logo)
        else
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                logo,
                const Spacer(),
                Text(
                  lema,
                  style: textos.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.1),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(detalle, style: textos.titleMedium?.copyWith(color: Colors.white, height: 1.5)),
                ),
                const SizedBox(height: 28),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Sello(Icons.event_available_outlined, 'Cupos en tiempo real'),
                    _Sello(Icons.verified_user_outlined, 'Correo UNIMET'),
                    _Sello(Icons.fact_check_outlined, 'Asistencia al día'),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Sello extends StatelessWidget {
  const _Sello(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
}
