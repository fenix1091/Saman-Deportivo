import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/apariencia_deporte.dart';
import '../../core/theme.dart';
import '../../models/deporte.dart';
import '../../models/inscripcion.dart';
import '../../models/persona.dart';
import '../../models/resena.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/detalle_deporte_view_model.dart';
import '../../viewmodels/mis_inscripciones_view_model.dart';
import '../dialogs/publicar_resena_dialog.dart';
import '../../widgets/barra_cupos.dart';
import '../../widgets/panel_con_menu.dart';

/// Detalle público de un deporte (CU-06, RF-06): entrenador, horarios, cupos en
/// tiempo real, costo de la reserva y reseñas.
class DetalleDeporteView extends StatelessWidget {
  const DetalleDeporteView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DetalleDeporteViewModel>();
    final deporte = vm.deporte;
    final usuario = context.watch<AuthViewModel>().usuario;
    // Los visitantes también ven el botón: la guardia los manda al login y vuelven aquí (CU-06, A1).
    final puedeInscribirse = deporte != null && !vm.noDisponible && (usuario == null || usuario.rol == Rol.estudiante);
    // En pantallas anchas la ficha va en dos columnas y el botón queda en la
    // tarjeta de reserva de la derecha; en el teléfono, fijo abajo.
    final ancha = MediaQuery.sizeOf(context).width >= anchoDosColumnas;
    // RN-07: un borrador (sin entrenador u horarios) no recibe inscripciones.
    final borrador = deporte != null && vm.horariosCargados && deporte.esBorrador(vm.horarios);
    Widget? boton() => !puedeInscribirse
        ? null
        : FilledButton(
            onPressed: deporte.hayCupo() && !borrador
                ? () => context.push('/estudiante/inscribir/${Uri.encodeComponent(deporte.codigo)}')
                : null,
            child: Text(borrador ? 'Próximamente' : (deporte.hayCupo() ? 'Inscribirme' : 'Sin cupos')),
          );
    return PanelConMenu(
      bottomNavigationBar: !puedeInscribirse || ancha
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  heightFactor: 1,
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 688), child: boton()),
                ),
              ),
            ),
      titulo: Text(deporte?.nombre ?? 'Deporte'),
      leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/catalogo')),
      body: () {
        if (vm.cargando) return const Center(child: CircularProgressIndicator());
        if (vm.error != null) return _Mensaje(vm.error!);
        if (vm.noDisponible || deporte == null) return const _Mensaje('Esta disciplina no está disponible.');
        final cupos = _Seccion(
          titulo: 'Cupos y costo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BarraCupos(deporte: deporte),
              const SizedBox(height: 12),
              _Dato(
                icono: Icons.payments_outlined,
                texto: deporte.costoReserva == 0
                    ? 'Reserva gratuita'
                    : 'Reserva del cupo: \$${deporte.costoReserva.toStringAsFixed(2)}',
              ),
            ],
          ),
        );
        final entrenador = _Seccion(titulo: 'Entrenador', child: _Entrenador(entrenador: deporte.entrenador, vm: vm));
        final horarios = _Seccion(
          titulo: 'Horarios',
          child: vm.horarios.isEmpty
              ? const Text('Los horarios aún no se han publicado.')
              : Column(
                  children: [
                    for (final h in vm.horarios)
                      _Dato(
                        icono: Icons.schedule,
                        texto: h.etiqueta,
                        detalle: h.lugar.isEmpty ? null : h.lugar,
                      ),
                  ],
                ),
        );
        final resenas = _Seccion(titulo: 'Reseñas', child: _Resenas(vm: vm));
        if (!ancha) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [_Encabezado(deporte: deporte), cupos, entrenador, horarios, resenas],
              ),
            ),
          );
        }
        final b = boton();
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 24),
                    children: [_Encabezado(deporte: deporte), horarios, resenas],
                  ),
                ),
                SizedBox(
                  width: 380,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cupos,
                        entrenador,
                        if (b != null) ...[const SizedBox(height: 16), b],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }(),
    );
  }
}

/// Ancho de ventana desde el que la ficha se reparte en dos columnas.
const anchoDosColumnas = 1100.0;

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.deporte});

  final Deporte deporte;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortadaDeporte(
            heroe: 'portada-${deporte.codigo}', deporte: deporte, alto: 220, radio: BorderRadius.circular(22)),
        const SizedBox(height: 18),
        Text(deporte.nombre, style: textos.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Chip(label: Text(deporte.codigo), visualDensity: VisualDensity.compact),
            if (deporte.categoria.isNotEmpty)
              Chip(label: Text(deporte.categoria), visualDensity: VisualDensity.compact),
          ],
        ),
        if (deporte.descripcion.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(deporte.descripcion, style: textos.bodyLarge),
        ],
      ],
    );
  }
}

class _Entrenador extends StatelessWidget {
  const _Entrenador({required this.entrenador, required this.vm});

  final EntrenadorAsignado? entrenador;
  final DetalleDeporteViewModel vm;

  @override
  Widget build(BuildContext context) {
    final e = entrenador;
    if (e == null || e.nombre.isEmpty) return const Text('Aún no tiene entrenador asignado.');
    final experiencia = e.aniosExperiencia == 1 ? '1 año de experiencia' : '${e.aniosExperiencia} años de experiencia';
    final textos = Theme.of(context).textTheme;
    final promedio = vm.calificacionProfesor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Dato(
          icono: Icons.sports,
          texto: e.nombre,
          detalle: [if (e.especialidad.isNotEmpty) e.especialidad, if (e.aniosExperiencia > 0) experiencia].join(' · '),
        ),
        if (promedio == null)
          Text('Todavía nadie ha calificado a este profesor.', style: textos.bodySmall?.copyWith(color: AppColors.gris))
        else ...[
          Row(
            children: [
              Text(promedio.toStringAsFixed(1), style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              _Estrellas(valor: promedio),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  vm.totalResenasProfesor == 1
                      ? '(1 opinión de sus alumnos)'
                      : '(${vm.totalResenasProfesor} opiniones de sus alumnos)',
                  style: textos.bodySmall?.copyWith(color: AppColors.gris),
                ),
              ),
            ],
          ),
          for (final r in vm.resenasProfesorRecientes)
            _ResenaItem(resena: r, estrellas: r.calificacionEntrenador!, comentario: r.comentarioEntrenador),
        ],
      ],
    );
  }
}

class _Resenas extends StatelessWidget {
  const _Resenas({required this.vm});

  final DetalleDeporteViewModel vm;

  @override
  Widget build(BuildContext context) {
    final promedio = vm.calificacionPromedio;
    final apartado = _TuResena(codigo: vm.codigo, nombre: vm.deporte?.nombre ?? '');
    if (promedio == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [apartado, const SizedBox(height: 12), const Text('Todavía no hay reseñas de esta disciplina.')],
      );
    }
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        apartado,
        const SizedBox(height: 16),
        Row(
          children: [
            Text(promedio.toStringAsFixed(1), style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            _Estrellas(valor: promedio),
            const SizedBox(width: 8),
            Text(
              vm.totalResenas == 1 ? '(1 reseña)' : '(${vm.totalResenas} reseñas)',
              style: textos.bodySmall?.copyWith(color: AppColors.gris),
            ),
          ],
        ),
        for (final r in vm.resenasRecientes) _ResenaItem(resena: r, estrellas: r.calificacion, comentario: r.comentario),
      ],
    );
  }
}

/// Requisito para reseñar, igual al que exigen las reglas de Firestore.
const requisitoResena =
    'Para dejar una reseña necesitas una inscripción confirmada en esta disciplina y al menos una asistencia '
    'registrada por el entrenador.';

/// Apartado para dejar la reseña de la disciplina y del profesor; si aún no se
/// puede, explica qué falta.
class _TuResena extends StatefulWidget {
  const _TuResena({required this.codigo, required this.nombre});

  final String codigo;
  final String nombre;

  @override
  State<_TuResena> createState() => _TuResenaState();
}

class _TuResenaState extends State<_TuResena> {
  @override
  void initState() {
    super.initState();
    final usuario = context.read<AuthViewModel>().usuario;
    if (usuario != null && usuario.rol == Rol.estudiante) {
      final vm = context.read<MisInscripcionesViewModel>();
      // Si se llega directo al detalle, todavía nadie escucha sus inscripciones.
      if (vm.inscripciones.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) vm.escucharInscripciones(usuario.uid);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final usuario = context.watch<AuthViewModel>().usuario;
    final esEstudiante = usuario != null && usuario.rol == Rol.estudiante;
    Inscripcion? inscripcion;
    if (esEstudiante) {
      for (final i in context.watch<MisInscripcionesViewModel>().inscripciones) {
        if (i.deporteCodigo == widget.codigo) inscripcion = i;
      }
    }
    final puede = inscripcion != null &&
        inscripcion.estado == EstadoInscripcion.confirmada &&
        inscripcion.sesionesAsistidas > 0;

    final String detalle;
    if (puede) {
      detalle = 'Cuéntales a otros estudiantes qué te pareció la disciplina y el profesor.';
    } else if (!esEstudiante) {
      detalle = usuario == null
          ? '$requisitoResena Inicia sesión como estudiante para reseñar.'
          : 'Solo los estudiantes inscritos pueden dejar reseñas.';
    } else if (inscripcion == null || !inscripcion.estaVigente()) {
      detalle = '$requisitoResena Aún no tienes una inscripción vigente aquí.';
    } else if (inscripcion.estado != EstadoInscripcion.confirmada) {
      detalle = '$requisitoResena Tu inscripción está: ${inscripcion.estado.etiqueta.toLowerCase()}.';
    } else {
      detalle = '$requisitoResena Tu inscripción ya está confirmada: falta que el entrenador registre tu asistencia.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: puede ? AppColors.naranja.withValues(alpha: 0.08) : const Color(0xFFF3F5F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(puede ? Icons.rate_review_outlined : Icons.lock_outline, size: 20,
                  color: puede ? AppColors.naranjaProfundo : AppColors.gris),
              const SizedBox(width: 8),
              Text('Deja tu reseña', style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(detalle, style: textos.bodyMedium),
          if (puede) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              icon: const Icon(Icons.star_outline_rounded),
              label: const Text('Dejar reseña'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => PublicarResenaDialog(deporteCodigo: widget.codigo, nombreDeporte: widget.nombre),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResenaItem extends StatelessWidget {
  const _ResenaItem({required this.resena, required this.estrellas, required this.comentario});

  final Resena resena;
  final int estrellas;
  final String comentario;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final f = resena.fecha;
    final fecha = '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Estrellas(valor: estrellas.toDouble(), tamano: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${resena.autor.isEmpty ? 'Estudiante' : resena.autor} · $fecha',
                  style: textos.bodySmall?.copyWith(color: AppColors.gris),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (comentario.isNotEmpty) Text(comentario, style: textos.bodyMedium),
        ],
      ),
    );
  }
}

class _Estrellas extends StatelessWidget {
  const _Estrellas({required this.valor, this.tamano = 20});

  final double valor;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${valor.toStringAsFixed(1)} de 5 estrellas',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                valor >= i
                    ? Icons.star
                    : valor >= i - 0.5
                        ? Icons.star_half
                        : Icons.star_border,
                size: tamano,
                color: AppColors.naranja,
              ),
          ],
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto, this.detalle});

  final IconData icono;
  final String texto;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: AppColors.naranja),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texto, style: textos.bodyLarge),
                if (detalle != null && detalle!.isNotEmpty)
                  Text(detalle!, style: textos.bodySmall?.copyWith(color: AppColors.gris)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => context.go('/catalogo'), child: const Text('Volver al catálogo')),
          ],
        ),
      ),
    );
  }
}
