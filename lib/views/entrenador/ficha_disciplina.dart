part of 'asistencia_view.dart';

/// Ficha de la disciplina: portada, cifras, horarios con su lugar, datos, cupos,
/// lista de estudiantes inscritos con su asistencia y reseñas.
class _Ficha extends StatelessWidget {
  const _Ficha(
      {required this.vm, required this.deporte, required this.cargandoDeporte});

  final AsistenciaViewModel vm;
  final Deporte? deporte;
  final bool cargandoDeporte;

  @override
  Widget build(BuildContext context) {
    final d = deporte;
    if (d == null) {
      if (cargandoDeporte) return const Esqueleto(filas: 3, alto: 120);
      return const EstadoVacio(
          icono: Icons.search_off_outlined,
          mensaje: 'No se encontró esta disciplina.');
    }
    final textos = Theme.of(context).textTheme;
    final pestanas = DefaultTabController.of(context);
    final sesiones = vm.sesiones.length;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Revelar(
              child: PortadaDeporte(
                deporte: d,
                alto: 150,
                radio: BorderRadius.circular(20),
                hijo: Positioned(
                  left: 18,
                  right: 18,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.nombre,
                          style: textos.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      Text(
                        [
                          d.codigo,
                          if (d.categoria.isNotEmpty) d.categoria,
                          if (!d.activo) 'Inactiva'
                        ].join(' · '),
                        style: textos.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Revelar(
              orden: 1,
              child: Row(
                children: [
                  _Cifra(
                      valor: '${vm.nomina.length}',
                      etiqueta:
                          vm.nomina.length == 1 ? 'inscrito' : 'inscritos'),
                  const SizedBox(width: 12),
                  _Cifra(
                      valor: '$sesiones',
                      etiqueta: sesiones == 1 ? 'sesión' : 'sesiones'),
                  const SizedBox(width: 12),
                  _Cifra(
                      valor: sesiones == 0 ? '—' : '${vm.promedio.round()} %',
                      etiqueta: 'asistencia promedio'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Revelar(
              orden: 2,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () =>
                        pestanas.animateTo(PestanaDisciplina.asistencia.index),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Pasar asistencia'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44)),
                    onPressed: () =>
                        pestanas.animateTo(PestanaDisciplina.historial.index),
                    icon: const Icon(Icons.insights_outlined),
                    label: const Text('Ver historial'),
                  ),
                  BotonExportar(
                    etiqueta: 'Exportar lista',
                    reporte: () => ReportesSaman.asistenciaDisciplina(
                        d, vm.nomina, vm.asistencias),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Revelar(
              orden: 3,
              child: LayoutBuilder(builder: (context, c) {
                final horarios = _Tarjeta(
                  icono: Icons.place_outlined,
                  titulo: 'Horarios y lugar',
                  child: _Horarios(codigo: d.codigo),
                );
                final datos = _Tarjeta(
                    icono: Icons.info_outline,
                    titulo: 'Sobre la disciplina',
                    child: _Datos(deporte: d));
                if (c.maxWidth < 640) {
                  return Column(
                      children: [horarios, const SizedBox(height: 12), datos]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: horarios),
                    const SizedBox(width: 12),
                    Expanded(child: datos)
                  ],
                );
              }),
            ),
            const SizedBox(height: 12),
            Revelar(
              orden: 4,
              child: _Tarjeta(
                icono: Icons.groups_outlined,
                titulo: 'Estudiantes inscritos (${vm.nomina.length})',
                child: vm.nomina.isEmpty
                    ? Text(
                        vm.error ??
                            'Todavía no hay estudiantes con inscripción confirmada.',
                        style:
                            textos.bodyMedium?.copyWith(color: AppColors.gris))
                    : Column(
                        children: [
                          for (var i = 0; i < vm.nomina.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                  height: 1, color: Color(0xFFEDF1EE)),
                            _FilaInscrito(vm: vm, estudiante: vm.nomina[i]),
                          ],
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Revelar(
              orden: 5,
              child: _Tarjeta(
                icono: Icons.star_outline_rounded,
                titulo: 'Reseñas',
                child: _Resenas(codigo: d.codigo),
              ),
            ),
            if (d.entrenadorId.isNotEmpty) ...[
              const SizedBox(height: 12),
              Revelar(
                orden: 6,
                child: _Tarjeta(
                  icono: Icons.workspace_premium_outlined,
                  titulo: 'Tu calificación como profesor',
                  child: _ResenasProfesor(entrenadorId: d.entrenadorId),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta(
      {required this.icono, required this.titulo, required this.child});

  final IconData icono;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Icon(icono, color: AppColors.verdeSaman, size: 22),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(titulo,
                      style: textos.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Horarios de la disciplina con el lugar de cada entrenamiento.
class _Horarios extends StatefulWidget {
  const _Horarios({required this.codigo});

  final String codigo;

  @override
  State<_Horarios> createState() => _HorariosState();
}

class _HorariosState extends State<_Horarios> {
  late final Future<List<Horario>> _horarios =
      context.read<DeporteRepository>().horarios(widget.codigo);

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return FutureBuilder<List<Horario>>(
      future: _horarios,
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('No se pudieron cargar los horarios.',
              style: textos.bodyMedium?.copyWith(color: AppColors.gris));
        }
        if (!snap.hasData) {
          return const SizedBox(
              height: 60, child: Esqueleto(filas: 1, alto: 48));
        }
        final horarios = snap.data!;
        if (horarios.isEmpty) {
          return Text('Sin horarios publicados.',
              style: textos.bodyMedium?.copyWith(color: AppColors.gris));
        }
        return Column(
          children: [
            for (final h in horarios)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                          color: AppColors.verdeClaro,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(h.dia.etiqueta.substring(0, 3),
                          textAlign: TextAlign.center,
                          style: textos.labelMedium?.copyWith(
                              color: AppColors.verdeSaman,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${h.horaInicio} – ${h.horaFin}',
                              style: textos.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                              h.lugar.isEmpty ? 'Lugar por confirmar' : h.lugar,
                              style: textos.bodySmall
                                  ?.copyWith(color: AppColors.gris)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Datos extends StatelessWidget {
  const _Datos({required this.deporte});

  final Deporte deporte;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    Widget fila(String etiqueta, String valor) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 96,
                  child: Text(etiqueta,
                      style:
                          textos.bodyMedium?.copyWith(color: AppColors.gris))),
              Expanded(
                  child: Text(valor,
                      style: textos.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (deporte.descripcion.isNotEmpty) ...[
          Text(deporte.descripcion, style: textos.bodyMedium),
          const SizedBox(height: 12),
        ],
        if (deporte.categoria.isNotEmpty) fila('Categoría', deporte.categoria),
        if (deporte.duracion.isNotEmpty) fila('Duración', deporte.duracion),
        fila('Estado', deporte.activo ? 'Activa' : 'Inactiva'),
        fila('Cupos',
            '${deporte.cuposOcupados} de ${deporte.cupoMaximo} ocupados'),
        const SizedBox(height: 4),
        BarraCupos(deporte: deporte),
      ],
    );
  }
}

/// Un estudiante inscrito con su porcentaje de asistencia.
class _FilaInscrito extends StatelessWidget {
  const _FilaInscrito({required this.vm, required this.estudiante});

  final AsistenciaViewModel vm;
  final EstudianteInscrito estudiante;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final sesiones = vm.sesionesDe(estudiante.uid);
    final porcentaje = vm.porcentaje(estudiante.uid);
    final color = sesiones == 0
        ? AppColors.gris
        : porcentaje >= 75
            ? AppColors.verdeHoja
            : porcentaje >= 50
                ? AppColors.naranja
                : AppColors.rojo;
    final iniciales = estudiante.nombreCompleto
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final datos = [
      if (estudiante.cedulaTexto.isNotEmpty) estudiante.cedulaTexto,
      if (estudiante.carnet.isNotEmpty) 'carnet ${estudiante.carnet}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.verdeClaro,
            child: Text(iniciales,
                style: textos.labelLarge?.copyWith(
                    color: AppColors.verdeSaman, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(estudiante.nombreCompleto,
                    style: textos.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (datos.isNotEmpty)
                  Text(datos,
                      style: textos.bodySmall?.copyWith(color: AppColors.gris)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          EtiquetaEstado(
              sesiones == 0 ? 'Sin sesiones' : '${porcentaje.round()} %',
              color: color),
        ],
      ),
    );
  }
}

/// Reseñas de la disciplina: promedio de estrellas y comentarios (igual al detalle del estudiante).
class _Resenas extends StatelessWidget {
  const _Resenas({required this.codigo});

  final String codigo;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return StreamBuilder<List<Resena>>(
      stream: context.read<DeporteRepository>().resenas(codigo),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('No se pudieron cargar las reseñas.',
              style: textos.bodyMedium?.copyWith(color: AppColors.gris));
        }
        if (!snap.hasData) {
          return const SizedBox(
              height: 60, child: Esqueleto(filas: 1, alto: 48));
        }
        final resenas = snap.data!;
        if (resenas.isEmpty) {
          return Text('Todavía no hay reseñas de esta disciplina.',
              style: textos.bodyMedium?.copyWith(color: AppColors.gris));
        }
        final suma = resenas.fold<int>(0, (total, r) => total + r.calificacion);
        final promedio = suma / resenas.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(promedio.toStringAsFixed(1),
                    style: textos.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                _Estrellas(valor: promedio),
                const SizedBox(width: 8),
                Text(
                  resenas.length == 1
                      ? '(1 reseña)'
                      : '(${resenas.length} reseñas)',
                  style: textos.bodySmall?.copyWith(color: AppColors.gris),
                ),
              ],
            ),
            for (final r in resenas) _ResenaItem(resena: r),
          ],
        );
      },
    );
  }
}

/// Lo que opinan del profesor sus alumnos de todas sus disciplinas.
class _ResenasProfesor extends StatelessWidget {
  const _ResenasProfesor({required this.entrenadorId});

  final String entrenadorId;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return StreamBuilder<List<Resena>>(
      stream: context.read<DeporteRepository>().resenasDeEntrenador(entrenadorId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('No se pudieron cargar las opiniones.', style: textos.bodyMedium?.copyWith(color: AppColors.gris));
        }
        if (!snap.hasData) return const SizedBox(height: 60, child: Esqueleto(filas: 1, alto: 48));
        final resenas = snap.data!;
        final promedio = DetalleDeporteViewModel.promedioProfesor(resenas);
        if (promedio == null) {
          return Text('Tus alumnos todavía no te han calificado.',
              style: textos.bodyMedium?.copyWith(color: AppColors.gris));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(promedio.toStringAsFixed(1), style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                _Estrellas(valor: promedio),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    resenas.length == 1 ? '(1 opinión)' : '(${resenas.length} opiniones)',
                    style: textos.bodySmall?.copyWith(color: AppColors.gris),
                  ),
                ),
              ],
            ),
            for (final r in resenas)
              _ResenaItem(resena: r, estrellas: r.calificacionEntrenador, comentario: r.comentarioEntrenador),
          ],
        );
      },
    );
  }
}

class _ResenaItem extends StatelessWidget {
  const _ResenaItem({required this.resena, this.estrellas, this.comentario});

  final Resena resena;

  /// Si se dan, se muestran en lugar de la nota y el comentario de la disciplina.
  final int? estrellas;
  final String? comentario;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final fecha = _fecha(resena.fecha);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Estrellas(valor: (estrellas ?? resena.calificacion).toDouble(), tamano: 16),
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
          if ((comentario ?? resena.comentario).isNotEmpty)
            Text(comentario ?? resena.comentario, style: textos.bodyMedium),
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
