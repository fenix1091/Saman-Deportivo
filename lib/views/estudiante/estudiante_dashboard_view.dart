import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/deporte.dart';
import '../../models/inscripcion.dart';
import '../../repositories/deporte_repository.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/mis_inscripciones_view_model.dart';
import '../../widgets/acciones_sesion.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/avatar_usuario.dart';
import '../../widgets/grafico_barras.dart';

/// Inicio del estudiante: sus reservas por estado, su asistencia, los
/// entrenamientos de la semana y los accesos al catálogo y al perfil. Todo en
/// tiempo real desde sus inscripciones.
class EstudianteDashboardView extends StatefulWidget {
  const EstudianteDashboardView({super.key});

  @override
  State<EstudianteDashboardView> createState() => _EstudianteDashboardViewState();
}

class _EstudianteDashboardViewState extends State<EstudianteDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usuario = context.read<AuthViewModel>().usuario;
      if (usuario != null) context.read<MisInscripcionesViewModel>().escucharInscripciones(usuario.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthViewModel>().usuario;
    final vm = context.watch<MisInscripcionesViewModel>();
    final textos = Theme.of(context).textTheme;
    if (usuario == null) return const SizedBox.shrink();

    final vigentes = vm.vigentes;
    final confirmadas = vigentes.where((i) => i.estado == EstadoInscripcion.confirmada).toList();
    final enRevision = vigentes.where((i) => i.estado == EstadoInscripcion.enRevision).length;
    final pendientes = vigentes.where((i) => i.estado == EstadoInscripcion.pendientePago).length;
    final sesiones = confirmadas.fold<int>(0, (s, i) => s + i.sesiones);
    final asistidas = confirmadas.fold<int>(0, (s, i) => s + i.sesionesAsistidas);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi panel'), actions: const [AccionesSesion()]),
      body: vm.cargando
          ? const Esqueleto(filas: 3, alto: 120)
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Revelar(
                      child: Row(
                        children: [
                          AvatarUsuario(nombre: usuario.nombreCompleto, fotoUrl: usuario.fotoUrl, radio: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hola, ${usuario.nombre}',
                                    style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  confirmadas.isEmpty
                                      ? 'Todavía no tienes una disciplina confirmada. Explora el catálogo y reserva tu cupo.'
                                      : 'Tienes ${confirmadas.length} ${confirmadas.length == 1 ? 'disciplina confirmada' : 'disciplinas confirmadas'}.',
                                  style: textos.bodyMedium?.copyWith(color: AppColors.gris),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Revelar(
                      orden: 1,
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final columnas = c.maxWidth >= 700 ? 4 : 2;
                          final ancho = (c.maxWidth - 12 * (columnas - 1)) / columnas;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                  width: ancho,
                                  child: TarjetaCifra(
                                      icono: Icons.how_to_reg_outlined,
                                      valor: '${confirmadas.length}',
                                      etiqueta: 'confirmadas',
                                      color: AppColors.verdeHoja)),
                              SizedBox(
                                  width: ancho,
                                  child: TarjetaCifra(
                                      icono: Icons.hourglass_top,
                                      valor: '$enRevision',
                                      etiqueta: 'en revisión',
                                      color: AppColors.naranja)),
                              SizedBox(
                                  width: ancho,
                                  child: TarjetaCifra(
                                      icono: Icons.lock_clock_outlined,
                                      valor: '$pendientes',
                                      etiqueta: 'por pagar',
                                      color: AppColors.azul)),
                              SizedBox(
                                width: ancho,
                                child: TarjetaCifra(
                                  icono: Icons.fact_check_outlined,
                                  valor: sesiones == 0 ? '—' : '${(asistidas * 100 / sesiones).round()} %',
                                  etiqueta: sesiones == 0
                                      ? 'asistencia (sin sesiones)'
                                      : 'asistencia · $asistidas de $sesiones',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    if (pendientes > 0 || enRevision > 0)
                      Revelar(
                        orden: 2,
                        child: Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(14),
                          decoration:
                              BoxDecoration(color: AppColors.naranjaClaro, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFC2410C)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  pendientes > 0
                                      ? 'Tienes $pendientes ${pendientes == 1 ? 'reserva' : 'reservas'} por pagar. El cupo se libera a los 15 minutos.'
                                      : 'Tu pago está en revisión. La Coordinación de Deportes confirmará tu cupo pronto.',
                                ),
                              ),
                              TextButton(onPressed: () => context.push('/mis-inscripciones'), child: const Text('Ver')),
                            ],
                          ),
                        ),
                      ),
                    if (confirmadas.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Revelar(
                          orden: 3,
                          child: Text('Mis entrenamientos',
                              style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                      const SizedBox(height: 8),
                      for (var i = 0; i < confirmadas.length; i++)
                        Revelar(
                          key: ValueKey(confirmadas[i].id),
                          orden: (i + 4).clamp(0, 6),
                          child: _TarjetaEntrenamiento(inscripcion: confirmadas[i]),
                        ),
                    ],
                    const SizedBox(height: 20),
                    Revelar(
                        orden: 4,
                        child: Text('Accesos', style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                    const SizedBox(height: 8),
                    Revelar(
                      orden: 5,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _Acceso(
                              icono: Icons.search,
                              titulo: 'Explorar deportes',
                              detalle: 'Catálogo con cupos en vivo',
                              ruta: '/catalogo'),
                          _Acceso(
                              icono: Icons.assignment_outlined,
                              titulo: 'Mis inscripciones',
                              detalle: 'Reservas, pagos y reseñas',
                              ruta: '/mis-inscripciones'),
                          _Acceso(
                              icono: Icons.account_circle_outlined,
                              titulo: 'Mi perfil',
                              detalle: 'Datos, teléfono y foto',
                              ruta: '/perfil'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TarjetaEntrenamiento extends StatelessWidget {
  const _TarjetaEntrenamiento({required this.inscripcion});

  final Inscripcion inscripcion;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final nombre = inscripcion.nombreDeporte.isEmpty ? inscripcion.deporteCodigo : inscripcion.nombreDeporte;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Elevable(
        radio: 16,
        alPulsar: () => context.push('/catalogo/${Uri.encodeComponent(inscripcion.deporteCodigo)}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.verdeClaro, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.sports_outlined, color: AppColors.verdeSaman),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    StreamBuilder<Deporte?>(
                      stream: context.read<DeporteRepository>().deporte(inscripcion.deporteCodigo),
                      builder: (context, snap) {
                        final entrenador = snap.data?.entrenador?.nombre;
                        return Text(
                          [
                            if (inscripcion.horarios.isNotEmpty)
                              inscripcion.horarios.replaceAll('\n', ' · ')
                            else
                              'Horario por definir',
                            if (entrenador != null && entrenador.isNotEmpty) 'Prof. $entrenador',
                          ].join('\n'),
                          style: textos.bodySmall?.copyWith(color: AppColors.gris),
                        );
                      },
                    ),
                    if (inscripcion.sesiones > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: inscripcion.porcentajeAsistencia / 100,
                          minHeight: 6,
                          color: inscripcion.porcentajeAsistencia >= 75 ? AppColors.verdeHoja : AppColors.naranja,
                          backgroundColor: const Color(0xFFEDF1EE),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Asistencia ${inscripcion.sesionesAsistidas} de ${inscripcion.sesiones} sesiones',
                        style: textos.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gris),
            ],
          ),
        ),
      ),
    );
  }
}

class _Acceso extends StatelessWidget {
  const _Acceso({required this.icono, required this.titulo, required this.detalle, required this.ruta});

  final IconData icono;
  final String titulo;
  final String detalle;
  final String ruta;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return SizedBox(
      width: 260,
      child: Elevable(
        radio: 16,
        alPulsar: () => context.push(ruta),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icono, color: AppColors.naranja),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: textos.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                    Text(detalle, style: textos.bodySmall?.copyWith(color: AppColors.gris)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
