import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'animaciones.dart';
import 'avatar_usuario.dart';

/// Naranja profundo de la marca: con texto blanco da 5,2:1 de contraste.
const naranjaProfundo = Color(0xFFC2410C);

/// Encabezado grande de los paneles (estudiante y entrenador): degradado naranja,
/// avatar, saludo, un mensaje de contexto y hasta dos acciones principales.
class EncabezadoPanel extends StatelessWidget {
  const EncabezadoPanel({
    super.key,
    required this.nombre,
    required this.saludo,
    required this.mensaje,
    this.fotoUrl = '',
    this.acciones = const [],
  });

  final String nombre;
  final String saludo;
  final String mensaje;
  final String fotoUrl;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final ancho = MediaQuery.sizeOf(context).width;
    final compacto = ancho < 640;
    final tamanoTitulo = (ancho * 0.028).clamp(26.0, 38.0);
    return Revelar(
      child: Container(
        padding: EdgeInsets.all(compacto ? 22 : 32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.naranja, naranjaProfundo],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: naranjaProfundo.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 14))
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)),
              ),
            ),
            Positioned(
              right: 90,
              bottom: -80,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.9)),
                      child: AvatarUsuario(nombre: nombre, fotoUrl: fotoUrl, radio: compacto ? 28 : 34),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            saludo,
                            style: textos.labelLarge
                                ?.copyWith(color: Colors.white.withValues(alpha: 0.9), letterSpacing: 1.2),
                          ),
                          Text(
                            nombre,
                            style: textos.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: tamanoTitulo,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  mensaje,
                  style: textos.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.95), height: 1.4),
                ),
                if (acciones.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Wrap(spacing: 12, runSpacing: 12, children: acciones),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón blanco con texto naranja profundo, para usar sobre el encabezado.
class BotonClaro extends StatelessWidget {
  const BotonClaro({super.key, required this.texto, required this.icono, required this.alPulsar, this.relleno = true});

  final String texto;
  final IconData icono;
  final VoidCallback alPulsar;
  final bool relleno;

  @override
  Widget build(BuildContext context) {
    final estilo = relleno
        ? FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: naranjaProfundo,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          );
    return relleno
        ? FilledButton.icon(style: estilo, onPressed: alPulsar, icon: Icon(icono), label: Text(texto))
        : OutlinedButton.icon(style: estilo, onPressed: alPulsar, icon: Icon(icono), label: Text(texto));
  }
}

/// Tarjeta de acceso grande: icono en círculo, título, detalle y flecha.
class TarjetaAcceso extends StatelessWidget {
  const TarjetaAcceso({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.alPulsar,
    this.color = AppColors.naranja,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback alPulsar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Elevable(
      radio: 20,
      alPulsar: alPulsar,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Icon(icono, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(detalle, style: textos.bodyMedium?.copyWith(color: AppColors.gris)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.gris),
          ],
        ),
      ),
    );
  }
}

/// Título de sección con antetítulo naranja, como en la landing.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion({super.key, required this.antetitulo, required this.titulo, this.accion});

  final String antetitulo;
  final String titulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(antetitulo.toUpperCase(),
                    style: textos.labelMedium
                        ?.copyWith(color: naranjaProfundo, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(titulo, style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}
