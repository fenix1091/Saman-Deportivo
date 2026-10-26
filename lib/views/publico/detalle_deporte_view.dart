import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/deporte.dart';
import '../../models/persona.dart';
import '../../models/resena.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/detalle_deporte_view_model.dart';
import '../../widgets/acciones_sesion.dart';
import '../../widgets/barra_cupos.dart';

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
    return Scaffold(
      bottomNavigationBar: !puedeInscribirse
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 688),
                    child: FilledButton(
                      onPressed: deporte.hayCupo()
                          ? () => context.push('/estudiante/inscribir/${Uri.encodeComponent(deporte.codigo)}')
                          : null,
                      child: Text(deporte.hayCupo() ? 'Inscribirme' : 'Sin cupos'),
                    ),
                  ),
                ),
              ),
            ),
      appBar: AppBar(
        title: Text(deporte?.nombre ?? 'Deporte'),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/catalogo')),
        actions: const [AccionesSesion()],
      ),
      body: () {
        if (vm.cargando) return const Center(child: CircularProgressIndicator());
        if (vm.error != null) return _Mensaje(vm.error!);
        if (vm.noDisponible || deporte == null) return const _Mensaje('Esta disciplina no está disponible.');
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _Encabezado(deporte: deporte),
                _Seccion(
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
                ),
                _Seccion(titulo: 'Entrenador', child: _Entrenador(entrenador: deporte.entrenador)),
                _Seccion(
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
                ),
                _Seccion(titulo: 'Reseñas', child: _Resenas(vm: vm)),
              ],
            ),
          ),
        );
      }(),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.deporte});

  final Deporte deporte;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(deporte.nombre, style: textos.headlineMedium),
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
  const _Entrenador({required this.entrenador});

  final EntrenadorAsignado? entrenador;

  @override
  Widget build(BuildContext context) {
    final e = entrenador;
    if (e == null || e.nombre.isEmpty) return const Text('Aún no tiene entrenador asignado.');
    final experiencia = e.aniosExperiencia == 1 ? '1 año de experiencia' : '${e.aniosExperiencia} años de experiencia';
    return _Dato(
      icono: Icons.sports,
      texto: e.nombre,
      detalle: [if (e.especialidad.isNotEmpty) e.especialidad, if (e.aniosExperiencia > 0) experiencia].join(' · '),
    );
  }
}

class _Resenas extends StatelessWidget {
  const _Resenas({required this.vm});

  final DetalleDeporteViewModel vm;

  @override
  Widget build(BuildContext context) {
    final promedio = vm.calificacionPromedio;
    if (promedio == null) return const Text('Todavía no hay reseñas de esta disciplina.');
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        for (final r in vm.resenasRecientes) _ResenaItem(resena: r),
      ],
    );
  }
}

class _ResenaItem extends StatelessWidget {
  const _ResenaItem({required this.resena});

  final Resena resena;

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
              _Estrellas(valor: resena.calificacion.toDouble(), tamano: 16),
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
          if (resena.comentario.isNotEmpty) Text(resena.comentario, style: textos.bodyMedium),
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
