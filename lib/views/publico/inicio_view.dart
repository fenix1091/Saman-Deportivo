import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/deporte.dart';
import '../../repositories/deporte_repository.dart';
import '../../viewmodels/auth_view_model.dart';

/// Naranja profundo: lleva texto blanco con 5,2:1 de contraste (sobre el naranja
/// de la marca el blanco solo llega a 2,6:1). Se usa en botones, degradados y textos.
const _naranjaProfundo = Color(0xFFC2410C);

/// Naranja muy oscuro para el pie.
const _naranjaNoche = Color(0xFF7C2D12);

/// Fondo crema para alternar secciones.
const _crema = Color(0xFFFFF4EA);

/// Página de aterrizaje pública (landing): presenta Samán Deportivo, muestra las
/// disciplinas abiertas y sus cupos en vivo y lleva al catálogo, al registro o al login.
class InicioView extends StatefulWidget {
  const InicioView({super.key});

  /// Ancho máximo del contenido en pantallas grandes.
  static const anchoMaximo = 1240.0;

  @override
  State<InicioView> createState() => _InicioViewState();
}

class _InicioViewState extends State<InicioView> {
  final _desplazamiento = ScrollController();
  late final Stream<List<Deporte>> _deportes;

  /// La barra superior se vuelve de vidrio esmerilado al bajar.
  bool _barraSolida = false;

  @override
  void initState() {
    super.initState();
    _deportes = context.read<DeporteRepository>().deportesActivos();
    _desplazamiento.addListener(() {
      final solida = _desplazamiento.offset > 24;
      if (solida != _barraSolida) setState(() => _barraSolida = solida);
    });
  }

  @override
  void dispose() {
    _desplazamiento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<List<Deporte>>(
        stream: _deportes,
        builder: (context, foto) {
          final deportes = foto.data ?? const <Deporte>[];
          return Stack(
            children: [
              SingleChildScrollView(
                controller: _desplazamiento,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Portada(deportes: deportes),
                    const _ComoFunciona(),
                    if (deportes.isNotEmpty) _Disciplinas(deportes: deportes),
                    const _Llamado(),
                    const _Pie(),
                  ],
                ),
              ),
              Positioned(top: 0, left: 0, right: 0, child: _BarraSuperior(solida: _barraSolida)),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Utilidades de diseño
// ---------------------------------------------------------------------------

/// Centra el contenido y limita su ancho.
class _Centrado extends StatelessWidget {
  const _Centrado({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: InicioView.anchoMaximo),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child),
        ),
      );
}

/// Tamaño de letra fluido: crece con el ancho de la pantalla entre [min] y [max].
double _fluido(BuildContext context, double min, double max) {
  final ancho = MediaQuery.sizeOf(context).width;
  return (min + (max - min) * ((ancho - 360) / (1280 - 360))).clamp(min, max);
}

/// Muestra a su hijo con un fundido y un leve desplazamiento hacia arriba la
/// primera vez que entra en pantalla. [orden] escalona varios elementos seguidos.
/// Si el sistema pide reducir las animaciones, aparece de inmediato.
class _Revelar extends StatefulWidget {
  const _Revelar({required this.child, this.orden = 0});

  final Widget child;
  final int orden;

  @override
  State<_Revelar> createState() => _RevelarState();
}

class _RevelarState extends State<_Revelar> with SingleTickerProviderStateMixin {
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

/// Tarjeta que se eleva un poco y gana sombra al pasar el ratón (micro-interacción).
class _Elevable extends StatefulWidget {
  const _Elevable({required this.child, this.radio = 20, this.alPulsar});

  final Widget child;
  final double radio;
  final VoidCallback? alPulsar;

  @override
  State<_Elevable> createState() => _ElevableState();
}

class _ElevableState extends State<_Elevable> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(widget.radio);
    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
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

/// Etiqueta pequeña en naranja que va encima de cada título de sección.
class _Antetitulo extends StatelessWidget {
  const _Antetitulo(this.texto) : color = _naranjaProfundo;

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        texto.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2, color: color),
        textAlign: TextAlign.center,
      );
}

/// Encabezado de sección: antetítulo, título y subtítulo, todo centrado.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.antetitulo, required this.titulo, required this.subtitulo});

  final String antetitulo;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return _Revelar(
      child: Column(
        children: [
          _Antetitulo(antetitulo),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: GoogleFonts.poppins(
              fontSize: _fluido(context, 26, 38),
              fontWeight: FontWeight.w700,
              color: AppColors.texto,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              subtitulo,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.gris, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Coloca los elementos en 3 columnas en pantallas anchas y uno debajo de otro en el teléfono.
class _Rejilla extends StatelessWidget {
  const _Rejilla({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, medidas) {
      if (medidas.maxWidth < 720) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, hijo) in children.indexed) ...[
              if (i > 0) const SizedBox(height: 16),
              _Revelar(orden: i, child: hijo),
            ],
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, hijo) in children.indexed) ...[
              if (i > 0) const SizedBox(width: 20),
              Expanded(child: _Revelar(orden: i, child: hijo)),
            ],
          ],
        ),
      );
    });
  }
}

ButtonStyle _botonNaranja() => FilledButton.styleFrom(
      backgroundColor: _naranjaProfundo,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 54),
      padding: const EdgeInsets.symmetric(horizontal: 26),
      textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

/// Botón blanco con texto naranja, para usar sobre los fondos naranjas.
ButtonStyle _botonBlanco() => _botonNaranja().copyWith(
      backgroundColor: const WidgetStatePropertyAll(Colors.white),
      foregroundColor: const WidgetStatePropertyAll(_naranjaProfundo),
    );

// ---------------------------------------------------------------------------
// Secciones
// ---------------------------------------------------------------------------

/// Barra fija arriba: transparente sobre la portada y de vidrio esmerilado al bajar.
class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({required this.solida});

  final bool solida;

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthViewModel>().usuario;
    final colorTexto = solida ? AppColors.texto : Colors.white;
    final angosta = MediaQuery.sizeOf(context).width < 480;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: solida ? 14 : 0, sigmaY: solida ? 14 : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: solida ? Colors.white.withValues(alpha: 0.82) : Colors.transparent,
            border: Border(
              bottom: BorderSide(color: solida ? const Color(0xFFE3E8EE) : Colors.transparent),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: _Centrado(
              child: SizedBox(
                height: 68,
                child: Row(
                  children: [
                    Semantics(
                      label: 'Samán Deportivo, inicio',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset('design/marca/logo_icono.png', width: 40, height: 40),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: colorTexto),
                        child: const Text('Samán Deportivo', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    if (usuario == null) ...[
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: colorTexto,
                          minimumSize: const Size(48, 48),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => context.go('/login'),
                        child: const Text('Iniciar sesión'),
                      ),
                      if (!angosta) ...[
                        const SizedBox(width: 6),
                        FilledButton(
                          style: (solida ? _botonNaranja() : _botonBlanco()).copyWith(
                            minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
                            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18)),
                            textStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontWeight: FontWeight.w700)),
                          ),
                          onPressed: () => context.go('/registro'),
                          child: const Text('Registrarme'),
                        ),
                      ],
                    ] else
                      FilledButton(
                        style: (solida ? _botonNaranja() : _botonBlanco()).copyWith(
                          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
                          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18)),
                        ),
                        onPressed: () => context.go(AuthViewModel.rutaInicio(usuario.rol)),
                        child: const Text('Ir a mi panel'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Portada: casi toda la pantalla, título grande, botones y cifras en vivo.
class _Portada extends StatelessWidget {
  const _Portada({required this.deportes});

  final List<Deporte> deportes;

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthViewModel>().usuario;
    final tamano = MediaQuery.sizeOf(context);
    final ancha = tamano.width >= 900;
    final alineacion = ancha ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final alineacionTexto = ancha ? TextAlign.start : TextAlign.center;
    final cupos = deportes.fold<int>(0, (suma, d) => suma + d.cuposDisponibles());

    final mensaje = Column(
      crossAxisAlignment: alineacion,
      children: [
        _Revelar(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Universidad Metropolitana · Coordinación de Deportes',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _Revelar(
          orden: 1,
          child: Text.rich(
            const TextSpan(children: [
              TextSpan(text: 'Tu deporte en la UNIMET, '),
              TextSpan(text: 'a un toque', style: TextStyle(color: Color(0xFFFFE2C4))),
            ]),
            semanticsLabel: 'Tu deporte en la UNIMET, a un toque',
            style: GoogleFonts.poppins(
              fontSize: _fluido(context, 34, 60),
              height: 1.08,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            textAlign: alineacionTexto,
          ),
        ),
        const SizedBox(height: 18),
        _Revelar(
          orden: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Encuentra la disciplina que te gusta, mira horarios y cupos en tiempo real '
              'e inscríbete desde el teléfono, sin colas ni planillas.',
              style: GoogleFonts.inter(
                fontSize: _fluido(context, 16, 19),
                color: Colors.white.withValues(alpha: 0.86),
                height: 1.6,
              ),
              textAlign: alineacionTexto,
            ),
          ),
        ),
        const SizedBox(height: 30),
        _Revelar(
          orden: 3,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: ancha ? WrapAlignment.start : WrapAlignment.center,
            children: [
              FilledButton.icon(
                style: _botonBlanco(),
                onPressed: () => context.go('/catalogo'),
                icon: const Icon(Icons.sports_soccer),
                label: const Text('Explorar deportes'),
              ),
              if (usuario == null)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                    minimumSize: const Size(0, 54),
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => context.go('/registro'),
                  child: const Text('Crear cuenta'),
                ),
            ],
          ),
        ),
        if (deportes.isNotEmpty) ...[
          const SizedBox(height: 40),
          _Revelar(
            orden: 4,
            child: Wrap(
              spacing: 36,
              runSpacing: 16,
              alignment: ancha ? WrapAlignment.start : WrapAlignment.center,
              children: [
                _Cifra(valor: deportes.length, etiqueta: 'disciplinas abiertas'),
                _Cifra(valor: cupos, etiqueta: 'cupos disponibles'),
              ],
            ),
          ),
        ],
      ],
    );

    final barra = 68 + MediaQuery.paddingOf(context).top;
    Widget logo({required double ancho}) => _Revelar(
          orden: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ancho),
            child: Container(
              padding: EdgeInsets.all(ancho > 500 ? 32 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: _naranjaNoche.withValues(alpha: 0.30), blurRadius: 48, offset: const Offset(0, 24)),
                ],
              ),
              child: Image.asset(
                'design/marca/logo_horizontal.png',
                fit: BoxFit.contain,
                semanticLabel: 'Logo de Samán Deportivo',
              ),
            ),
          ),
        );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.naranja, Color(0xFFE5640F), _naranjaProfundo],
        ),
      ),
      child: Stack(
        children: [
          // Halos de color difuminados al fondo (profundidad sin imágenes pesadas).
          const Positioned(top: -120, right: -80, child: _Halo(color: Colors.white, tamano: 420, alfa: 0.22)),
          const Positioned(bottom: -160, left: -120, child: _Halo(color: Color(0xFFFFB547), tamano: 460, alfa: 0.35)),
          // Alto contenido: el bloque queda centrado en vertical sin dejar un hueco grande abajo.
          Container(
            constraints: BoxConstraints(
              minHeight: ancha ? (tamano.height * 0.78).clamp(560.0, 820.0) : 0,
            ),
            alignment: Alignment.center,
            padding: EdgeInsets.fromLTRB(0, barra + (ancha ? 24 : 20), 0, ancha ? 56 : 48),
            child: _Centrado(
              child: ancha
                  ? Row(
                      children: [
                        Expanded(flex: 5, child: mensaje),
                        const SizedBox(width: 48),
                        Expanded(flex: 6, child: logo(ancho: 660)),
                      ],
                    )
                  : Column(
                      children: [
                        logo(ancho: 420),
                        const SizedBox(height: 28),
                        mensaje,
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.color, required this.tamano, required this.alfa});

  final Color color;
  final double tamano;
  final double alfa;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: tamano,
          height: tamano,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color.withValues(alpha: alfa), color.withValues(alpha: 0)]),
          ),
        ),
      );
}

/// Cifra que cuenta desde 0 hasta su valor cuando aparece.
class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.etiqueta});

  final int valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final sinAnimacion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: '$valor $etiqueta',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: sinAnimacion ? valor.toDouble() : 0, end: valor.toDouble()),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(
              '${v.round()}',
              style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
            ),
          ),
          const SizedBox(height: 6),
          Text(etiqueta, style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.78))),
        ],
      ),
    );
  }
}

class _ComoFunciona extends StatelessWidget {
  const _ComoFunciona();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 88),
      child: _Centrado(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Encabezado(
              antetitulo: 'Paso a paso',
              titulo: 'Cómo funciona',
              subtitulo: 'De la búsqueda al entrenamiento en tres pasos, todo desde tu teléfono.',
            ),
            SizedBox(height: 48),
            _Rejilla(children: [
              _Paso(
                numero: '01',
                icono: Icons.search_rounded,
                titulo: 'Explora',
                texto: 'Revisa las disciplinas, sus horarios, el entrenador y los cupos que quedan, sin crear cuenta.',
              ),
              _Paso(
                numero: '02',
                icono: Icons.how_to_reg_outlined,
                titulo: 'Inscríbete',
                texto: 'Regístrate con tu correo UNIMET. El sistema valida tu solvencia y aparta tu cupo al pagar la reserva.',
              ),
              _Paso(
                numero: '03',
                icono: Icons.sports_handball_outlined,
                titulo: 'Entrena',
                texto: 'Consulta tus inscripciones, deja reseñas y tu entrenador lleva la asistencia de cada práctica.',
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.numero, required this.icono, required this.titulo, required this.texto});

  final String numero;
  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return _Elevable(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.naranjaClaro, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icono, color: _naranjaProfundo, size: 28),
                ),
                const Spacer(),
                Text(
                  numero,
                  style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w800, color: const Color(0xFFFDE3CC)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(titulo, style: GoogleFonts.poppins(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.texto)),
            const SizedBox(height: 8),
            Text(texto, style: textos.bodyMedium?.copyWith(color: AppColors.gris, height: 1.6)),
          ],
        ),
      ),
    );
  }
}

/// Disciplinas abiertas, leídas en vivo del catálogo.
class _Disciplinas extends StatelessWidget {
  const _Disciplinas({required this.deportes});

  final List<Deporte> deportes;

  static const maximo = 6;

  @override
  Widget build(BuildContext context) {
    final visibles = deportes.take(maximo).toList();
    return Container(
      color: _crema,
      padding: const EdgeInsets.symmetric(vertical: 88),
      child: _Centrado(
        child: Column(
          children: [
            const _Encabezado(
              antetitulo: 'En vivo',
              titulo: 'Disciplinas abiertas este trimestre',
              subtitulo: 'Los cupos se actualizan al instante: lo que ves es lo que queda.',
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 18,
              runSpacing: 18,
              alignment: WrapAlignment.center,
              children: [
                for (final (i, d) in visibles.indexed)
                  _Revelar(orden: i % 3, child: _FichaDeporte(deporte: d)),
              ],
            ),
            const SizedBox(height: 36),
            _Revelar(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _naranjaProfundo,
                  side: const BorderSide(color: _naranjaProfundo),
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => context.go('/catalogo'),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  deportes.length > maximo ? 'Ver las ${deportes.length} disciplinas' : 'Ver horarios y detalles',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FichaDeporte extends StatelessWidget {
  const _FichaDeporte({required this.deporte});

  final Deporte deporte;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final libres = deporte.cuposDisponibles();
    final proporcion = deporte.cupoMaximo == 0 ? 0.0 : deporte.cuposOcupados / deporte.cupoMaximo;
    final color = libres == 0
        ? AppColors.rojo
        : libres <= 3
            ? const Color(0xFFB45309)
            : _naranjaProfundo;
    return SizedBox(
      width: 260,
      child: _Elevable(
        radio: 18,
        alPulsar: () => context.go('/catalogo/${Uri.encodeComponent(deporte.codigo)}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deporte.nombre,
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.texto),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_outward_rounded, size: 18, color: AppColors.gris),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                deporte.categoria.isEmpty ? 'Disciplina' : deporte.categoria,
                style: textos.bodySmall?.copyWith(color: AppColors.gris),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: proporcion.clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFFDE3CC),
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                libres > 0 ? '$libres cupos disponibles' : 'Cupos agotados',
                style: textos.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banda final con la invitación a registrarse.
class _Llamado extends StatelessWidget {
  const _Llamado();

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthViewModel>().usuario;
    return Padding(
      padding: const EdgeInsets.only(bottom: 88),
      child: _Centrado(
        child: _Revelar(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.naranja, _naranjaProfundo],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                const Positioned(top: -140, right: -100, child: _Halo(color: Colors.white, tamano: 360, alfa: 0.22)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          usuario == null ? '¿Listo para entrenar?' : '¡Hola, ${usuario.nombre}!',
                          style: GoogleFonts.poppins(
                            fontSize: _fluido(context, 26, 40),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          usuario == null
                              ? 'Crea tu cuenta con el correo de la UNIMET y aparta tu cupo hoy.'
                              : 'Tus disciplinas y tu perfil te esperan en tu panel.',
                          style: GoogleFonts.inter(fontSize: 17, color: Colors.white.withValues(alpha: 0.82)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        FilledButton(
                          style: _botonBlanco(),
                          onPressed: () =>
                              context.go(usuario == null ? '/registro' : AuthViewModel.rutaInicio(usuario.rol)),
                          child: Text(usuario == null ? 'Crear mi cuenta' : 'Ir a mi panel'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie();

  @override
  Widget build(BuildContext context) {
    final estilo = GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.72));
    return Container(
      color: _naranjaNoche,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: _Centrado(
        child: Column(
          children: [
            Text('Samán Deportivo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              'Universidad Metropolitana · Coordinación de Deportes · Caracas, Venezuela',
              style: estilo,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
