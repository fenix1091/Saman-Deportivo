import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/progreso.dart';
import '../../core/theme.dart';
import '../../models/asistencia.dart';
import '../../repositories/asistencia_repository.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/mis_inscripciones_view_model.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/encabezado_panel.dart';
import '../../widgets/panel_con_menu.dart';

/// "Mi progreso" del estudiante: asistencia, racha, nivel e insignias, en tiempo
/// real a partir de la asistencia que registran sus entrenadores.
class MiProgresoView extends StatefulWidget {
  const MiProgresoView({super.key});

  @override
  State<MiProgresoView> createState() => _MiProgresoViewState();
}

class _MiProgresoViewState extends State<MiProgresoView> {
  Stream<List<Asistencia>>? _asistencias;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthViewModel>().usuario?.uid;
    if (_asistencias == null && uid != null) {
      _asistencias = context.read<AsistenciaRepository>().asistenciasDelEstudiante(uid);
      final inscripciones = context.read<MisInscripcionesViewModel>();
      WidgetsBinding.instance.addPostFrameCallback((_) => inscripciones.escucharInscripciones(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombres = {
      for (final i in context.watch<MisInscripcionesViewModel>().inscripciones)
        i.deporteCodigo: i.nombreDeporte.isEmpty ? i.deporteCodigo : i.nombreDeporte,
    };
    return PanelConMenu(
      titulo: const Text('Mi progreso'),
      body: _asistencias == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<Asistencia>>(
              stream: _asistencias,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const EstadoVacio(
                      icono: Icons.cloud_off_outlined, mensaje: 'No se pudo cargar tu progreso. Revisa tu conexión.');
                }
                if (!snap.hasData) return const Esqueleto(filas: 3, alto: 140);
                final p = ProgresoEstudiante.calcular(snap.data!, nombres: nombres);
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                      children: [
                        Revelar(child: _Cabecera(progreso: p)),
                        if (p.sesiones > 0) ...[
                          const TituloSeccion(antetitulo: 'Tus entrenamientos', titulo: 'Últimas sesiones'),
                          Revelar(orden: 1, child: _UltimasSesiones(progreso: p, nombres: nombres)),
                        ],
                        TituloSeccion(
                            antetitulo: '${p.insigniasLogradas} de ${p.insignias.length} conseguidas',
                            titulo: 'Insignias'),
                        Revelar(orden: 2, child: _Insignias(insignias: p.insignias)),
                        if (p.porDisciplina.isNotEmpty) ...[
                          const TituloSeccion(antetitulo: 'Asistencia', titulo: 'Por disciplina'),
                          for (var i = 0; i < p.porDisciplina.length; i++)
                            Revelar(orden: (i + 3).clamp(0, 6), child: _FilaDisciplina(d: p.porDisciplina[i])),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

Duration _duracion(BuildContext context, int ms) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : Duration(milliseconds: ms);

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.progreso});

  final ProgresoEstudiante progreso;

  @override
  Widget build(BuildContext context) {
    final p = progreso;
    final textos = Theme.of(context).textTheme;
    final siguiente = p.siguienteNivel;
    final anillo = SizedBox.square(
      dimension: 132,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: p.porcentaje / 100),
        duration: _duracion(context, 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 11,
              strokeCap: StrokeCap.round,
              color: AppColors.naranja,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              semanticsLabel: 'Asistencia general',
              semanticsValue: '${p.porcentaje.round()} %',
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.sesiones == 0 ? '—' : '${(v * 100).round()} %',
                      style: textos.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  Text('asistencia', style: textos.bodySmall?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final detalle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NIVEL', style: textos.labelMedium?.copyWith(color: Colors.white70, letterSpacing: 1.4)),
        Text(p.nivel.nombre, style: textos.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: p.avanceNivel),
            duration: _duracion(context, 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 10,
              color: AppColors.naranja,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          siguiente == null
              ? '¡Llegaste al nivel máximo!'
              : 'Te ${siguiente.desde - p.presentes == 1 ? 'falta 1 asistencia' : 'faltan ${siguiente.desde - p.presentes} asistencias'} '
                  'para ${siguiente.nombre}',
          style: textos.bodySmall?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pastilla(icono: Icons.local_fire_department, texto: 'Racha de ${p.rachaActual}'),
            _Pastilla(icono: Icons.emoji_events_outlined, texto: 'Mejor racha: ${p.mejorRacha}'),
            _Pastilla(icono: Icons.check_circle_outline, texto: '${p.presentes} de ${p.sesiones} asistencias'),
          ],
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.verdeSaman, Color(0xFF2E7D4F)],
        ),
        boxShadow: [BoxShadow(color: AppColors.verdeSaman.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final contenido = p.sesiones == 0
              ? [
                  anillo,
                  const SizedBox(width: 22, height: 18),
                  Flexible(
                    child: Text(
                      'Aún no hay asistencias registradas. Cuando tu entrenador pase lista, aquí verás tu racha, '
                      'tu nivel y las insignias que vas ganando.',
                      style: textos.bodyLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ]
              : [anillo, const SizedBox(width: 26, height: 18), Flexible(child: detalle)];
          if (c.maxWidth < 520) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido);
          }
          return Row(children: contenido);
        },
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(texto,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _UltimasSesiones extends StatelessWidget {
  const _UltimasSesiones({required this.progreso, required this.nombres});

  final ProgresoEstudiante progreso;
  final Map<String, String> nombres;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    String fecha(DateTime f) => '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E8EE)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 12,
        children: [
          for (final a in progreso.recientes)
            Tooltip(
              message: '${nombres[a.deporteCodigo] ?? a.deporteCodigo} · ${fecha(a.fecha)}',
              child: SizedBox(
                width: 58,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: a.estado == EstadoAsistencia.presente ? AppColors.verdeHoja : const Color(0xFFEDF1EE),
                      ),
                      child: Icon(
                        a.estado == EstadoAsistencia.presente ? Icons.check : Icons.close,
                        color: a.estado == EstadoAsistencia.presente ? Colors.white : AppColors.gris,
                        size: 22,
                        semanticLabel: a.estado == EstadoAsistencia.presente ? 'Presente' : 'Ausente',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(fecha(a.fecha), style: textos.labelSmall?.copyWith(color: AppColors.gris)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Icono y color de cada insignia.
(IconData, Color) _aspecto(String id) => switch (id) {
      'primer-paso' => (Icons.flag_outlined, AppColors.verdeHoja),
      'en-racha' => (Icons.local_fire_department, AppColors.naranja),
      'constante' => (Icons.repeat, AppColors.azul),
      'perfecta' => (Icons.star_rounded, const Color(0xFFE0A100)),
      'multideporte' => (Icons.sports_handball, const Color(0xFF7C4DDB)),
      'fin-de-semana' => (Icons.wb_sunny_outlined, const Color(0xFFE5533D)),
      'sin-fallar' => (Icons.bolt, const Color(0xFF0E8A9A)),
      'imparable' => (Icons.military_tech, AppColors.verdeSaman),
      _ => (Icons.emoji_events_outlined, AppColors.naranja),
    };

class _Insignias extends StatelessWidget {
  const _Insignias({required this.insignias});

  final List<Insignia> insignias;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columnas = c.maxWidth >= 900
          ? 4
          : c.maxWidth >= 560
              ? 3
              : 2;
      final ancho = (c.maxWidth - 12 * (columnas - 1)) / columnas;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final i in insignias) SizedBox(width: ancho, child: _TarjetaInsignia(insignia: i))],
      );
    });
  }
}

class _TarjetaInsignia extends StatelessWidget {
  const _TarjetaInsignia({required this.insignia});

  final Insignia insignia;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final (icono, color) = _aspecto(insignia.id);
    final lograda = insignia.lograda;
    return Semantics(
      label: '${insignia.titulo}: ${lograda ? 'conseguida' : '${insignia.actual} de ${insignia.meta}'}',
      excludeSemantics: true,
      child: Elevable(
        radio: 18,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: lograda ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: lograda ? color.withValues(alpha: 0.45) : const Color(0xFFE3E8EE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: lograda ? 0.6 : 1, end: 1),
                    duration: _duracion(context, 600),
                    curve: Curves.elasticOut,
                    builder: (_, escala, hijo) => Transform.scale(scale: escala, child: hijo),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lograda ? color : const Color(0xFFEDF1EE),
                        boxShadow: lograda
                            ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]
                            : null,
                      ),
                      child: Icon(lograda ? icono : Icons.lock_outline,
                          color: lograda ? Colors.white : AppColors.gris, size: 24),
                    ),
                  ),
                  const Spacer(),
                  if (lograda) Icon(Icons.verified, color: color, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              Text(insignia.titulo,
                  style: textos.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, color: lograda ? AppColors.texto : AppColors.gris)),
              const SizedBox(height: 2),
              Text(insignia.descripcion,
                  style: textos.bodySmall?.copyWith(color: AppColors.gris), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (!lograda) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: insignia.avance,
                    minHeight: 6,
                    color: color,
                    backgroundColor: const Color(0xFFEDF1EE),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${insignia.actual.clamp(0, insignia.meta)} de ${insignia.meta}',
                    style: textos.labelSmall?.copyWith(color: AppColors.gris)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaDisciplina extends StatelessWidget {
  const _FilaDisciplina({required this.d});

  final ProgresoDisciplina d;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final color = d.porcentaje >= 75
        ? AppColors.verdeHoja
        : d.porcentaje >= 50
            ? AppColors.naranja
            : AppColors.rojo;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(d.nombre, style: textos.bodyLarge?.copyWith(fontWeight: FontWeight.w700))),
              Text('${d.asistidas} de ${d.sesiones} · ${d.porcentaje.round()} %',
                  style: textos.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: d.porcentaje / 100),
              duration: _duracion(context, 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: color,
                backgroundColor: const Color(0xFFEDF1EE),
                semanticsLabel: 'Asistencia en ${d.nombre}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
