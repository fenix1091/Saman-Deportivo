import 'package:flutter/material.dart';

import '../models/deporte.dart';
import 'theme.dart';

/// Color e icono de cada disciplina, por categoría y por nombre, para que el
/// catálogo tenga identidad visual aunque la disciplina no tenga foto.
class AparienciaDeporte {
  AparienciaDeporte._();

  static String _plano(String t) {
    const con = 'áéíóúüñ';
    const sin = 'aeiouun';
    final b = StringBuffer();
    for (final c in t.toLowerCase().split('')) {
      final i = con.indexOf(c);
      b.write(i >= 0 ? sin[i] : c);
    }
    return b.toString();
  }

  /// Icono según el nombre de la disciplina; si no se reconoce, por categoría.
  static IconData icono(Deporte d) {
    final n = _plano(d.nombre);
    if (n.contains('futbol') || n.contains('soccer')) return Icons.sports_soccer;
    if (n.contains('balonc') || n.contains('basket')) return Icons.sports_basketball;
    if (n.contains('voleib') || n.contains('voley')) return Icons.sports_volleyball;
    if (n.contains('tenis de mesa') || n.contains('ping')) return Icons.sports_tennis;
    if (n.contains('tenis')) return Icons.sports_tennis;
    if (n.contains('natac') || n.contains('nado')) return Icons.pool;
    if (n.contains('ajedrez')) return Icons.grid_on;
    if (n.contains('beisbol') || n.contains('softbol')) return Icons.sports_baseball;
    if (n.contains('rugby')) return Icons.sports_rugby;
    if (n.contains('atletismo') || n.contains('carrera')) return Icons.directions_run;
    if (n.contains('karate') || n.contains('judo') || n.contains('taekwondo') || n.contains('artes marciales')) {
      return Icons.sports_martial_arts;
    }
    if (n.contains('ciclismo')) return Icons.directions_bike;
    if (n.contains('yoga') || n.contains('pilates')) return Icons.self_improvement;
    if (n.contains('gimnasio') || n.contains('pesas') || n.contains('fitness')) return Icons.fitness_center;
    if (n.contains('golf')) return Icons.sports_golf;
    if (n.contains('esgrima')) return Icons.sports_kabaddi;
    final c = _plano(d.categoria);
    if (c.contains('acuat')) return Icons.pool;
    if (c.contains('raqueta')) return Icons.sports_tennis;
    if (c.contains('mental') || c.contains('mesa')) return Icons.psychology_outlined;
    if (c.contains('individual')) return Icons.directions_run;
    return Icons.sports;
  }

  /// Par de colores del degradado, por categoría.
  static List<Color> colores(Deporte d) {
    final c = _plano(d.categoria);
    if (c.contains('acuat')) return const [Color(0xFF0E7490), Color(0xFF155E75)];
    if (c.contains('raqueta')) return const [Color(0xFF15803D), Color(0xFF166534)];
    if (c.contains('mental') || c.contains('mesa')) return const [Color(0xFF6D28D9), Color(0xFF4C1D95)];
    if (c.contains('individual')) return const [Color(0xFFB45309), Color(0xFF92400E)];
    if (c.contains('combate') || c.contains('marcial')) return const [Color(0xFFB91C1C), Color(0xFF7F1D1D)];
    return const [AppColors.naranja, Color(0xFFC2410C)];
  }

  static Color colorPrincipal(Deporte d) => colores(d).first;
}

/// Portada de una disciplina: la foto si tiene `imagenUrl` y, si no (o si la
/// foto falla), un degradado por categoría con el icono del deporte en marca de agua.
class PortadaDeporte extends StatelessWidget {
  const PortadaDeporte(
      {super.key,
      required this.deporte,
      this.alto = 120,
      this.radio = const BorderRadius.vertical(top: Radius.circular(16)),
      this.hijo,
      this.heroe});

  final Deporte deporte;
  final double alto;
  final BorderRadius radio;

  /// Contenido superpuesto, por ejemplo una etiqueta de cupos.
  final Widget? hijo;

  /// Si se indica, la portada "viaja" entre dos pantallas que usen la misma etiqueta.
  final String? heroe;

  @override
  Widget build(BuildContext context) {
    final colores = AparienciaDeporte.colores(deporte);
    final fondo = Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colores)),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -26,
            child:
                Icon(AparienciaDeporte.icono(deporte), size: alto * 1.15, color: Colors.white.withValues(alpha: 0.18)),
          ),
          Positioned(
            left: 16,
            top: 14,
            child: Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
              child: Icon(AparienciaDeporte.icono(deporte), color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
    final portada = ClipRRect(
      borderRadius: radio,
      child: SizedBox(
        height: alto,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (deporte.imagenUrl.isEmpty)
              fondo
            else
              Image.network(
                deporte.imagenUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fondo,
                loadingBuilder: (_, hijo, progreso) => progreso == null ? hijo : fondo,
              ),
            if (deporte.imagenUrl.isNotEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
                  ),
                ),
              ),
            if (hijo != null) hijo!,
          ],
        ),
      ),
    );
    if (heroe == null) return portada;
    return Hero(tag: heroe!, child: Material(type: MaterialType.transparency, child: portada));
  }
}
