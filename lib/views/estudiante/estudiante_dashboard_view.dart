import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/deporte.dart';
import '../../models/inscripcion.dart';
import '../../models/persona.dart';
import '../../repositories/deporte_repository.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/mis_inscripciones_view_model.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/calendario_semanal.dart';
import '../../widgets/encabezado_panel.dart';
import '../../widgets/grafico_barras.dart';
import '../../widgets/panel_con_menu.dart';

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
    if (usuario == null) return const SizedBox.shrink();

    final vigentes = vm.vigentes;
    final confirmadas = vigentes.where((i) => i.estado == EstadoInscripcion.confirmada).toList();
    final enRevision = vigentes.where((i) => i.estado == EstadoInscripcion.enRevision).length;
    final pendientes = vigentes.where((i) => i.estado == EstadoInscripcion.pendientePago).length;
    final sesiones = confirmadas.fold<int>(0, (s, i) => s + i.sesiones);
    final asistidas = confirmadas.fold<int>(0, (s, i) => s + i.sesionesAsistidas);

    return PanelConMenu(
      titulo: const Text('Mi panel'),
      body: vm.cargando
          ? const Esqueleto(filas: 3, alto: 160)
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                  children: [
                    EncabezadoPanel(
                      nombre: usuario.nombreCompleto,
                      fotoUrl: usuario.fotoUrl,
                      saludo: 'HOLA,',
                      mensaje: confirmadas.isEmpty
                          ? 'Todavía no tienes una disciplina confirmada. Explora el catálogo, reserva tu cupo y paga en línea: la Coordinación valida el pago y listo.'
                          : 'Tienes ${confirmadas.length} ${confirmadas.length == 1 ? 'disciplina confirmada' : 'disciplinas confirmadas'}. Aquí ves tus entrenamientos, tu asistencia y el estado de tus reservas.',
                      acciones: [
                        BotonClaro(
                            texto: 'Explorar deportes', icono: Icons.search, alPulsar: () => context.push('/catalogo')),
                        BotonClaro(
                          texto: 'Mis inscripciones',
                          icono: Icons.assignment_outlined,
                          relleno: false,
                          alPulsar: () => context.push('/mis-inscripciones'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Revelar(
                      orden: 1,
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final columnas = c.maxWidth >= 760 ? 4 : 2;
                          final ancho = (c.maxWidth - 14 * (columnas - 1)) / columnas;
                          return Wrap(
                            spacing: 14,
                            runSpacing: 14,
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
                    if (usuario is Estudiante && !usuario.correoVerificado)
                      Revelar(
                        orden: 2,
                        child: Container(
                          margin: const EdgeInsets.only(top: 18),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.naranja.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mark_email_unread_outlined, color: naranjaProfundo, size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Verifica tu correo para poder reservar un cupo. Te enviamos un enlace al registrarte.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                                onPressed: () => context.push('/verificar-correo'),
                                child: const Text('Verificar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (pendientes > 0 || enRevision > 0)
                      Revelar(
                        orden: 2,
                        child: Container(
                          margin: const EdgeInsets.only(top: 18),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.naranjaClaro,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.naranja.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: naranjaProfundo, size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  pendientes > 0
                                      ? 'Tienes $pendientes ${pendientes == 1 ? 'reserva' : 'reservas'} por pagar. El cupo se libera a los 15 minutos.'
                                      : 'Tu pago está en revisión. La Coordinación de Deportes confirmará tu cupo pronto.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                                onPressed: () => context.push('/mis-inscripciones'),
                                child: const Text('Ver'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (confirmadas.isNotEmpty) ...[
                      const TituloSeccion(antetitulo: 'Esta semana', titulo: 'Calendario'),
                      Revelar(
                        orden: 2,
                        child: CalendarioDeDisciplinas(
                          deportes: [
                            for (final i in confirmadas)
                              Deporte(
                                  codigo: i.deporteCodigo,
                                  nombre: i.nombreDeporte.isEmpty ? i.deporteCodigo : i.nombreDeporte,
                                  cupoMaximo: i.cupoMaximo),
                          ],
                        ),
                      ),
                    ],
                    const TituloSeccion(antetitulo: 'Mis disciplinas', titulo: 'Mis entrenamientos'),
                    if (confirmadas.isEmpty)
                      Revelar(
                        orden: 3,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE3E8EE)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration:
                                    BoxDecoration(color: AppColors.verdeClaro, borderRadius: BorderRadius.circular(20)),
                                child: const Icon(Icons.sports_soccer_outlined, color: AppColors.verdeSaman, size: 36),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Aún no tienes entrenamientos',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Cuando tu reserva quede confirmada verás aquí los días, las horas, el lugar y tu asistencia.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.gris),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < confirmadas.length; i++)
                        Revelar(
                          key: ValueKey(confirmadas[i].id),
                          orden: (i + 3).clamp(0, 6),
                          child: _TarjetaEntrenamiento(inscripcion: confirmadas[i]),
                        ),
                    const TituloSeccion(antetitulo: 'Atajos', titulo: 'Accesos'),
                    Revelar(
                      orden: 4,
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final columnas = c.maxWidth >= 900
                              ? 3
                              : c.maxWidth >= 560
                                  ? 2
                                  : 1;
                          final ancho = (c.maxWidth - 14 * (columnas - 1)) / columnas;
                          return Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              SizedBox(
                                  width: ancho,
                                  child: TarjetaAcceso(
                                      icono: Icons.search,
                                      titulo: 'Catálogo de deportes',
                                      detalle: 'Cupos en vivo, filtros y detalle',
                                      alPulsar: () => context.push('/catalogo'))),
                              SizedBox(
                                  width: ancho,
                                  child: TarjetaAcceso(
                                      icono: Icons.assignment_outlined,
                                      titulo: 'Mis inscripciones',
                                      detalle: 'Reservas, pagos y reseñas',
                                      color: AppColors.verdeHoja,
                                      alPulsar: () => context.push('/mis-inscripciones'))),
                              SizedBox(
                                  width: ancho,
                                  child: TarjetaAcceso(
                                      icono: Icons.account_circle_outlined,
                                      titulo: 'Mi perfil',
                                      detalle: 'Datos, teléfono y foto',
                                      color: AppColors.azul,
                                      alPulsar: () => context.push('/perfil'))),
                            ],
                          );
                        },
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Elevable(
        radio: 20,
        alPulsar: () => context.push('/catalogo/${Uri.encodeComponent(inscripcion.deporteCodigo)}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: AppColors.verdeClaro, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.sports_outlined, color: AppColors.verdeSaman, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
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
                          style: textos.bodyMedium?.copyWith(color: AppColors.gris, height: 1.5),
                        );
                      },
                    ),
                    if (inscripcion.sesiones > 0) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: inscripcion.porcentajeAsistencia / 100,
                          minHeight: 8,
                          color: inscripcion.porcentajeAsistencia >= 75 ? AppColors.verdeHoja : AppColors.naranja,
                          backgroundColor: const Color(0xFFEDF1EE),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Asistencia ${inscripcion.sesionesAsistidas} de ${inscripcion.sesiones} sesiones',
                        style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.gris),
            ],
          ),
        ),
      ),
    );
  }
}
