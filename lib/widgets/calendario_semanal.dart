import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/apariencia_deporte.dart';
import '../core/theme.dart';
import '../models/deporte.dart';
import '../repositories/deporte_repository.dart';
import 'animaciones.dart';

/// Un bloque de entrenamiento en la semana.
class BloqueSemana {
  const BloqueSemana({required this.deporte, required this.horario});

  final Deporte deporte;
  final Horario horario;

  int get minutosInicio {
    final p = horario.horaInicio.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }
}

/// Calendario de lunes a domingo con los entrenamientos de varias disciplinas.
///
/// Resalta el día de hoy y anuncia el próximo entrenamiento. En pantallas
/// angostas se vuelve una lista por día.
class CalendarioSemanal extends StatelessWidget {
  const CalendarioSemanal({super.key, required this.bloques, this.ahora});

  final List<BloqueSemana> bloques;
  final DateTime? ahora;

  static const _dias = DiaSemana.values;

  /// Próximo bloque a partir de [ahora], y en cuántos días cae (0 = hoy).
  static (BloqueSemana, int)? proximo(List<BloqueSemana> bloques, DateTime ahora) {
    if (bloques.isEmpty) return null;
    final hoy = ahora.weekday - 1; // lunes = 0
    final minutos = ahora.hour * 60 + ahora.minute;
    (BloqueSemana, int)? mejor;
    var mejorClave = 1 << 30;
    for (final b in bloques) {
      var dias = (b.horario.dia.index - hoy) % 7;
      if (dias < 0) dias += 7;
      if (dias == 0 && b.minutosInicio < minutos) dias = 7;
      final clave = dias * 24 * 60 + b.minutosInicio;
      if (clave < mejorClave) {
        mejorClave = clave;
        mejor = (b, dias);
      }
    }
    return mejor;
  }

  static String textoProximo((BloqueSemana, int) p) {
    final (b, dias) = p;
    final cuando = switch (dias) {
      0 => 'hoy',
      1 => 'mañana',
      7 => 'el próximo ${b.horario.dia.etiqueta.toLowerCase()}',
      _ => 'en $dias días (${b.horario.dia.etiqueta.toLowerCase()})',
    };
    return 'Próximo entrenamiento: ${b.deporte.nombre} $cuando a las ${b.horario.horaInicio}'
        '${b.horario.lugar.isEmpty ? '' : ' · ${b.horario.lugar}'}';
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final hoy = (ahora ?? DateTime.now());
    final diaHoy = hoy.weekday - 1;
    final p = proximo(bloques, hoy);
    final porDia = <DiaSemana, List<BloqueSemana>>{};
    for (final b in bloques) {
      porDia.putIfAbsent(b.horario.dia, () => []).add(b);
    }
    for (final l in porDia.values) {
      l.sort((a, b) => a.minutosInicio.compareTo(b.minutosInicio));
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.verdeClaro, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.alarm_on_outlined, color: AppColors.verdeSaman),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(textoProximo(p), style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          LayoutBuilder(
            builder: (context, c) {
              final columnas = c.maxWidth >= 760;
              if (!columnas) {
                return Column(
                  children: [
                    for (final d in _dias)
                      if (porDia[d] != null) _DiaLista(dia: d, bloques: porDia[d]!, esHoy: d.index == diaHoy),
                    if (porDia.isEmpty)
                      Text('Sin horarios publicados.', style: textos.bodySmall?.copyWith(color: AppColors.gris)),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final d in _dias) ...[
                    Expanded(child: _DiaColumna(dia: d, bloques: porDia[d] ?? const [], esHoy: d.index == diaHoy)),
                    if (d != _dias.last) const SizedBox(width: 6),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DiaColumna extends StatelessWidget {
  const _DiaColumna({required this.dia, required this.bloques, required this.esHoy});

  final DiaSemana dia;
  final List<BloqueSemana> bloques;
  final bool esHoy;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: esHoy ? AppColors.naranja : const Color(0xFFF4F6F4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            dia.etiqueta.substring(0, 3),
            textAlign: TextAlign.center,
            style:
                textos.labelLarge?.copyWith(color: esHoy ? Colors.white : AppColors.texto, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        if (bloques.isEmpty)
          Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEDF1EE)),
            ),
          )
        else
          for (final b in bloques) _Bloque(bloque: b),
      ],
    );
  }
}

class _DiaLista extends StatelessWidget {
  const _DiaLista({required this.dia, required this.bloques, required this.esHoy});

  final DiaSemana dia;
  final List<BloqueSemana> bloques;
  final bool esHoy;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(dia.etiqueta,
                  style: textos.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, color: esHoy ? AppColors.naranja : null)),
              if (esHoy) ...[const SizedBox(width: 8), const EtiquetaEstado('Hoy', color: AppColors.naranja)],
            ],
          ),
          const SizedBox(height: 6),
          for (final b in bloques) _Bloque(bloque: b, ancho: true),
        ],
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.bloque, this.ancho = false});

  final BloqueSemana bloque;
  final bool ancho;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final color = AparienciaDeporte.colorPrincipal(bloque.deporte);
    final h = bloque.horario;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${h.horaInicio} – ${h.horaFin}',
              style: textos.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800)),
          Text(bloque.deporte.nombre,
              style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: ancho ? 1 : 2,
              overflow: TextOverflow.ellipsis),
          if (h.lugar.isNotEmpty)
            Text(h.lugar,
                style: textos.bodySmall?.copyWith(color: AppColors.gris), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Carga los horarios de varias disciplinas desde el [DeporteRepository] y los
/// pinta en el [CalendarioSemanal]. Mientras carga, reserva el espacio.
class CalendarioDeDisciplinas extends StatelessWidget {
  const CalendarioDeDisciplinas({super.key, required this.deportes});

  final List<Deporte> deportes;

  Future<List<BloqueSemana>> _cargar(DeporteRepository repo) async {
    final bloques = <BloqueSemana>[];
    for (final d in deportes) {
      try {
        for (final h in await repo.horarios(d.codigo)) {
          bloques.add(BloqueSemana(deporte: d, horario: h));
        }
      } catch (_) {
        // Sin horarios de esa disciplina; se muestran las demás.
      }
    }
    return bloques;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BloqueSemana>>(
      key: ValueKey(deportes.map((d) => d.codigo).join(',')),
      future: _cargar(context.read<DeporteRepository>()),
      builder: (context, snap) {
        // Dentro de otra lista: altura fija para que el esqueleto no pida espacio infinito.
        if (!snap.hasData) return const SizedBox(height: 212, child: Esqueleto(filas: 1, alto: 180));
        return CalendarioSemanal(bloques: snap.data!);
      },
    );
  }
}
