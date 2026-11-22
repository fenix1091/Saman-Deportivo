import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/validacion_admin.dart';
import '../../core/validadores.dart';
import '../../models/deporte.dart';
import '../../models/persona.dart';
import '../../repositories/admin_repository_firebase.dart';
import 'inscritos_dialog.dart';
import 'reservas_tab.dart';
import 'resumen_tab.dart';
import 'usuarios_tab.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/cuadricula_adaptable.dart';
import '../../widgets/panel_con_menu.dart';

/// Secciones del panel de administración; cada una tiene su ruta (/admin/{seccion})
/// y aparece en el menú lateral.
enum SeccionAdmin { resumen, clases, reservas, entrenadores, usuarios }

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key, required this.repositorio, this.seccion = SeccionAdmin.resumen});

  final AdminRepository repositorio;
  final SeccionAdmin seccion;

  static SeccionAdmin seccionDesde(String? nombre) =>
      SeccionAdmin.values.firstWhere((s) => s.name == nombre, orElse: () => SeccionAdmin.resumen);

  @override
  Widget build(BuildContext context) {
    final titulo = switch (seccion) {
      SeccionAdmin.resumen => 'Administración deportiva',
      SeccionAdmin.clases => 'Clases y horarios',
      SeccionAdmin.reservas => 'Revisión de reservas',
      SeccionAdmin.entrenadores => 'Equipo de entrenadores',
      SeccionAdmin.usuarios => 'Usuarios',
    };
    return PanelConMenu(
      titulo: Text(titulo),
      body: switch (seccion) {
        SeccionAdmin.resumen => ResumenTab(repositorio: repositorio),
        SeccionAdmin.clases => _ClasesTab(repositorio: repositorio),
        SeccionAdmin.reservas => ReservasTab(repositorio: repositorio),
        SeccionAdmin.entrenadores => _EntrenadoresTab(repositorio: repositorio),
        SeccionAdmin.usuarios => UsuariosTab(repositorio: repositorio),
      },
    );
  }
}

class _ClasesTab extends StatelessWidget {
  const _ClasesTab({required this.repositorio});

  final AdminRepository repositorio;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Entrenador>>(
      stream: repositorio.observarEntrenadores(),
      builder: (context, entrenadoresSnapshot) {
        if (entrenadoresSnapshot.hasError) {
          return _ErrorCarga(error: entrenadoresSnapshot.error!);
        }
        if (!entrenadoresSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        final entrenadores = entrenadoresSnapshot.data!;
        return StreamBuilder<List<Deporte>>(
          stream: repositorio.observarDeportes(),
          builder: (context, deportesSnapshot) {
            if (deportesSnapshot.hasError) return _ErrorCarga(error: deportesSnapshot.error!);
            if (!deportesSnapshot.hasData) return const Center(child: CircularProgressIndicator());
            final deportes = deportesSnapshot.data!;
            return Column(
              children: [
                _Encabezado(
                  titulo: 'Oferta deportiva',
                  detalle: '${deportes.length} ${deportes.length == 1 ? 'disciplina' : 'disciplinas'} · '
                      '${deportes.where((d) => d.activo).length} activas',
                  accion: FilledButton.icon(
                    onPressed: () => _editarDeporte(context, repositorio, null, deportes),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva clase'),
                  ),
                ),
                Expanded(
                  child: deportes.isEmpty
                      ? const _Vacio(icono: Icons.sports, mensaje: 'Aún no hay clases. Crea la primera.')
                      : _Contenido(
                          child: CuadriculaAdaptable(
                            anchoMinimo: 460,
                            maxColumnas: 2,
                            hijos: [
                              for (final d in deportes)
                                _TarjetaDeporte(deporte: d, entrenadores: entrenadores, repositorio: repositorio),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TarjetaDeporte extends StatelessWidget {
  const _TarjetaDeporte({
    required this.deporte,
    required this.entrenadores,
    required this.repositorio,
  });

  final Deporte deporte;
  final List<Entrenador> entrenadores;
  final AdminRepository repositorio;

  @override
  Widget build(BuildContext context) {
    final entrenadorIds = entrenadores.map((entrenador) => entrenador.uid).toSet();
    final entrenadorActual = entrenadorIds.contains(deporte.entrenadorId) ? deporte.entrenadorId : '';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deporte.nombre,
                          style: Theme.of(context).textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (deporte.categoria.isNotEmpty) Text(deporte.categoria),
                      // RN-07: sin entrenador u horarios no sale en el catálogo.
                      StreamBuilder<List<Horario>>(
                        stream: repositorio.observarHorarios(deporte.codigo),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || !deporte.esBorrador(snapshot.data!)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Tooltip(
                              message: 'No sale en el catálogo ni recibe inscripciones hasta tener entrenador y horarios.',
                              child: EtiquetaEstado(
                                'Borrador · ${deporte.faltaParaPublicar(snapshot.data!).toLowerCase()}',
                                color: AppColors.naranjaProfundo,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar clase',
                  onPressed: () => _editarDeporte(context, repositorio, deporte),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Configurar horarios',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _HorariosDialog(deporte: deporte, repositorio: repositorio),
                  ),
                  icon: const Icon(Icons.schedule),
                ),
                IconButton(
                  tooltip: 'Inscritos',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => InscritosDialog(deporte: deporte, repositorio: repositorio),
                  ),
                  icon: const Icon(Icons.groups_2_outlined),
                ),
                IconButton(
                  tooltip: 'Eliminar clase',
                  onPressed: () => _eliminarDeporte(context, repositorio, deporte),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (deporte.descripcion.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(deporte.descripcion),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.people_outline, size: 20),
                const SizedBox(width: 8),
                Text('${deporte.cuposOcupados}/${deporte.cupoMaximo} cupos ocupados'),
                const Spacer(),
                Text(deporte.activo ? 'Activa' : 'Inactiva'),
                Switch(
                  value: deporte.activo,
                  onChanged: (activo) =>
                      repositorio.actualizarActivoDeporte(deporte.codigo, activo).catchError((Object error) {
                    if (context.mounted) _mensaje(context, 'No se pudo actualizar la clase: $error');
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: entrenadorActual,
              decoration: const InputDecoration(
                labelText: 'Entrenador asignado',
                prefixIcon: Icon(Icons.sports_handball_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Sin asignar')),
                ...entrenadores.map(
                  (entrenador) => DropdownMenuItem(value: entrenador.uid, child: Text(entrenador.nombreCompleto)),
                ),
              ],
              onChanged: (uid) {
                if (uid == null) return;
                repositorio.asignarEntrenador(deporte.codigo, uid).catchError((Object error) {
                  if (context.mounted) _mensaje(context, 'No se pudo asignar el entrenador: $error');
                });
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Horario>>(
              stream: repositorio.observarHorarios(deporte.codigo),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('No se pudieron cargar los horarios: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.data!.isEmpty) {
                  return const Text('Sin horarios configurados.');
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: snapshot.data!
                      .map(
                        (horario) => Chip(
                          avatar: const Icon(Icons.access_time, size: 18),
                          label: Text(
                            '${_nombreDia(horario.dia)} · ${horario.horaInicio}-${horario.horaFin} · ${horario.lugar}',
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EntrenadoresTab extends StatelessWidget {
  const _EntrenadoresTab({required this.repositorio});

  final AdminRepository repositorio;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Entrenador>>(
      stream: repositorio.observarEntrenadores(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorCarga(error: snapshot.error!);
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final entrenadores = snapshot.data!;
        return Column(
          children: [
            _Encabezado(
              titulo: 'Equipo de entrenadores',
              detalle: '${entrenadores.length} ${entrenadores.length == 1 ? 'entrenador' : 'entrenadores'}',
              accion: FilledButton.icon(
                onPressed: () => _crearEntrenador(context, repositorio),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Nuevo entrenador'),
              ),
            ),
            Expanded(
              child: entrenadores.isEmpty
                  ? const _Vacio(icono: Icons.groups_outlined, mensaje: 'Aún no hay entrenadores registrados.')
                  : _Contenido(
                      child: CuadriculaAdaptable(
                        anchoMinimo: 320,
                        maxColumnas: 3,
                        hijos: [
                          for (final entrenador in entrenadores)
                            Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                                leading: const CircleAvatar(child: Icon(Icons.sports_handball_outlined)),
                                title: Text(entrenador.nombreCompleto, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  '${entrenador.especialidad.isEmpty ? 'Sin especialidad' : entrenador.especialidad}'
                                  '${entrenador.aniosExperiencia > 0 ? ' · ${entrenador.aniosExperiencia} años' : ''}'
                                  '\n${entrenador.correo}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  tooltip: 'Reenviar enlace para configurar contraseña',
                                  icon: const Icon(Icons.mark_email_unread_outlined),
                                  onPressed: () async {
                                    try {
                                      await repositorio.reenviarEnlace(entrenador.correo);
                                      if (context.mounted) _mensaje(context, 'Enlace enviado a ${entrenador.correo}.');
                                    } on FirebaseAuthException catch (error) {
                                      if (context.mounted) {
                                        _mensaje(
                                            context, 'No se pudo enviar el enlace: ${error.message ?? error.code}');
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Encabezado de una sección del panel: título y resumen a la izquierda, la
/// acción principal a la derecha, en la misma fila (en el teléfono se apilan).
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.titulo, required this.detalle, required this.accion});

  final String titulo;
  final String detalle;
  final Widget accion;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(titulo, style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        Text(detalle, style: textos.bodySmall?.copyWith(color: AppColors.gris)),
      ],
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _anchoPanel),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: LayoutBuilder(
            builder: (context, c) => c.maxWidth < 480
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [texto, const SizedBox(height: 10), accion],
                  )
                : Row(
                    children: [Expanded(child: texto), const SizedBox(width: 12), SizedBox(width: 230, child: accion)]),
          ),
        ),
      ),
    );
  }
}

/// Ancho máximo del contenido del panel: aprovecha pantallas grandes sin que
/// las líneas queden larguísimas.
const _anchoPanel = 1320.0;

/// Contenido desplazable y centrado de una sección del panel.
class _Contenido extends StatelessWidget {
  const _Contenido({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _anchoPanel), child: child),
      ),
    );
  }
}

class _DeporteDialog extends StatefulWidget {
  const _DeporteDialog({required this.repositorio, this.deporte, this.existentes = const []});

  final AdminRepository repositorio;
  final Deporte? deporte;

  /// Disciplinas ya creadas, para no repetir su código al crear una nueva.
  final List<Deporte> existentes;

  @override
  State<_DeporteDialog> createState() => _DeporteDialogState();
}

class _DeporteDialogState extends State<_DeporteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _codigo = TextEditingController(text: widget.deporte?.codigo);
  late final _costo =
      TextEditingController(text: widget.deporte == null ? '0' : widget.deporte!.costoReserva.toStringAsFixed(2));
  late final _imagen = TextEditingController(text: widget.deporte?.imagenUrl);
  late final _nombre = TextEditingController(text: widget.deporte?.nombre);
  late final _categoria = TextEditingController(text: widget.deporte?.categoria);
  late final _descripcion = TextEditingController(text: widget.deporte?.descripcion);
  late final _cupos = TextEditingController(text: '${widget.deporte?.cupoMaximo ?? 20}');
  bool _guardando = false;

  /// Error del servidor: otra persona creó ese código mientras se llenaba el formulario.
  String? _repetidoEnServidor;

  @override
  void dispose() {
    _codigo.dispose();
    _costo.dispose();
    _imagen.dispose();
    _nombre.dispose();
    _categoria.dispose();
    _descripcion.dispose();
    _cupos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.deporte == null ? 'Nueva clase' : 'Editar clase'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codigo,
                enabled: widget.deporte == null,
                decoration: const InputDecoration(labelText: 'Código único *', hintText: 'Ej. BAS-01'),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                  LengthLimitingTextInputFormatter(12),
                ],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: (_) {
                  if (_repetidoEnServidor != null) setState(() => _repetidoEnServidor = null);
                },
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Escribe un código, por ejemplo BAS-01.';
                  if (v.length < 3) return 'El código debe tener al menos 3 caracteres.';
                  if (widget.deporte == null) {
                    final repetido = ValidacionAdmin.codigoRepetido(v, widget.existentes);
                    if (repetido != null) return repetido;
                  }
                  return _repetidoEnServidor;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (value) => Validadores.requerido(value, 'el nombre'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcion,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cupos,
                decoration: const InputDecoration(labelText: 'Cupo máximo *'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final cupos = int.tryParse(value ?? '');
                  if (cupos == null || cupos < 1) return 'Ingresa un cupo mayor que cero.';
                  if (widget.deporte != null && cupos < widget.deporte!.cuposOcupados) {
                    return 'No puede ser menor que los ${widget.deporte!.cuposOcupados} inscritos.';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costo,
                decoration: const InputDecoration(
                    labelText: 'Costo de la reserva (USD) *', helperText: '0 para una disciplina gratuita'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final costo = double.tryParse((value ?? '').replaceAll(',', '.'));
                  if (costo == null || costo < 0) return 'Ingresa un monto válido.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imagen,
                decoration: const InputDecoration(
                    labelText: 'Foto (enlace https)',
                    helperText: 'Sin foto se muestra un fondo de color con el icono del deporte'),
                keyboardType: TextInputType.url,
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return null;
                  final uri = Uri.tryParse(v);
                  if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
                    return 'Pega un enlace completo que empiece por https://';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }

  /// Guarda sin cerrar la ventana hasta que el servidor confirma: si el código
  /// resultó repetido, se marca en el campo y no se pierde lo escrito.
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final anterior = widget.deporte;
    final cupos = int.parse(_cupos.text);
    final deporte = Deporte(
      codigo: anterior?.codigo ?? _codigo.text.trim().toUpperCase(),
      nombre: _nombre.text.trim(),
      categoria: _categoria.text.trim(),
      descripcion: _descripcion.text.trim(),
      cupoMaximo: cupos,
      cuposOcupados: anterior?.cuposOcupados ?? 0,
      costoReserva: double.parse(_costo.text.replaceAll(',', '.')),
      imagenUrl: _imagen.text.trim(),
      entrenadorId: anterior?.entrenadorId ?? '',
      activo: anterior?.activo ?? true,
      vecesBuscado: anterior?.vecesBuscado ?? 0,
    );
    setState(() => _guardando = true);
    try {
      await widget.repositorio.guardarDeporte(deporte, nueva: anterior == null);
      if (mounted) Navigator.pop(context, deporte);
    } on CodigoRepetidoException {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _repetidoEnServidor = 'Ya existe una disciplina con el código ${deporte.codigo}. Usa otro código.';
      });
      _formKey.currentState!.validate();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _mensaje(context, 'No se pudo guardar la clase: ${error.message ?? error.code}');
    }
  }
}

Future<void> _editarDeporte(BuildContext context, AdminRepository repositorio,
    [Deporte? deporte, List<Deporte> existentes = const []]) async {
  await showDialog<Deporte>(
    context: context,
    builder: (_) => _DeporteDialog(repositorio: repositorio, deporte: deporte, existentes: existentes),
  );
}

/// Elimina una disciplina por completo, con confirmación. Si tiene inscripciones
/// vigentes el repositorio lo impide y aquí se explica el motivo y la alternativa.
Future<void> _eliminarDeporte(BuildContext context, AdminRepository repositorio, Deporte deporte) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Eliminar ${deporte.nombre}'),
      content: const Text('Se borrarán la disciplina y sus horarios de forma definitiva. Solo es '
          'posible si no tiene inscripciones vigentes; si las tiene, puedes darla '
          'de baja con el interruptor "Activa" para conservar el historial.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Eliminar definitivamente'),
        ),
      ],
    ),
  );
  if (confirmado != true || !context.mounted) return;
  try {
    await repositorio.eliminarDeporte(deporte.codigo);
    if (context.mounted) _mensaje(context, '${deporte.nombre} fue eliminada.');
  } on OperacionNoPermitidaException catch (e) {
    if (context.mounted) _mensaje(context, e.mensaje);
  } on FirebaseException catch (error) {
    if (context.mounted) {
      _mensaje(context, 'No se pudo eliminar la clase: ${error.message ?? error.code}');
    }
  }
}

class _HorariosDialog extends StatelessWidget {
  const _HorariosDialog({required this.deporte, required this.repositorio});

  final Deporte deporte;
  final AdminRepository repositorio;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Horarios de ${deporte.nombre}'),
      content: SizedBox(
        width: 460,
        child: StreamBuilder<List<Horario>>(
          stream: repositorio.observarHorarios(deporte.codigo),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('No se pudieron cargar los horarios: ${snapshot.error}');
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final horarios = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (horarios.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Agrega los días, horas y lugares de esta clase.'),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: horarios.length,
                      itemBuilder: (context, index) {
                        final horario = horarios[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${_nombreDia(horario.dia)} · ${horario.horaInicio}-${horario.horaFin}'),
                          subtitle: Text(horario.lugar),
                          onTap: () => _editarHorario(context, repositorio, deporte, horarios, horario),
                          trailing: IconButton(
                            tooltip: 'Eliminar horario',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              try {
                                await repositorio.eliminarHorario(deporte.codigo, horario.id);
                              } on FirebaseException catch (error) {
                                if (context.mounted) {
                                  _mensaje(context, 'No se pudo eliminar el horario: ${error.message ?? error.code}');
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _editarHorario(context, repositorio, deporte, horarios),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar horario'),
                ),
              ],
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Listo'))],
    );
  }
}

class _HorarioDialog extends StatefulWidget {
  const _HorarioDialog({this.horario});

  final Horario? horario;

  @override
  State<_HorarioDialog> createState() => _HorarioDialogState();
}

class _HorarioDialogState extends State<_HorarioDialog> {
  final _formKey = GlobalKey<FormState>();
  late DiaSemana _dia = widget.horario?.dia ?? DiaSemana.lunes;
  late TimeOfDay _inicio = _horaDesdeTexto(widget.horario?.horaInicio ?? '16:00');
  late TimeOfDay _fin = _horaDesdeTexto(widget.horario?.horaFin ?? '18:00');
  late final _lugar = TextEditingController(text: widget.horario?.lugar);

  @override
  void dispose() {
    _lugar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.horario == null ? 'Agregar horario' : 'Editar horario'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<DiaSemana>(
              initialValue: _dia,
              decoration: const InputDecoration(labelText: 'Día'),
              items: DiaSemana.values.map((dia) => DropdownMenuItem(value: dia, child: Text(_nombreDia(dia)))).toList(),
              onChanged: (dia) {
                if (dia != null) setState(() => _dia = dia);
              },
            ),
            Row(
              children: [
                Expanded(
                    child: _SelectorHora(
                        label: 'Desde', hora: _inicio, onChange: (hora) => setState(() => _inicio = hora))),
                const SizedBox(width: 12),
                Expanded(
                    child: _SelectorHora(label: 'Hasta', hora: _fin, onChange: (hora) => setState(() => _fin = hora))),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lugar,
              decoration: const InputDecoration(labelText: 'Lugar *'),
              validator: (value) => Validadores.requerido(value, 'el lugar'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_minutos(_inicio) >= _minutos(_fin)) {
              _mensaje(context, 'La hora de fin debe ser posterior a la hora de inicio.');
              return;
            }
            Navigator.pop(
              context,
              Horario(
                id: widget.horario?.id ?? '',
                dia: _dia,
                horaInicio: _horaATexto(_inicio),
                horaFin: _horaATexto(_fin),
                lugar: _lugar.text.trim(),
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _SelectorHora extends StatelessWidget {
  const _SelectorHora({required this.label, required this.hora, required this.onChange});

  final String label;
  final TimeOfDay hora;
  final ValueChanged<TimeOfDay> onChange;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        final seleccion = await showTimePicker(context: context, initialTime: hora);
        if (seleccion != null) onChange(seleccion);
      },
      icon: const Icon(Icons.access_time),
      label: Text('$label\n${_horaATexto(hora)}', textAlign: TextAlign.center),
    );
  }
}

Future<void> _editarHorario(
  BuildContext context,
  AdminRepository repositorio,
  Deporte deporte,
  List<Horario> horarios, [
  Horario? horario,
]) async {
  final resultado = await showDialog<Horario>(
    context: context,
    builder: (_) => _HorarioDialog(horario: horario),
  );
  if (resultado == null || !context.mounted) return;
  if (horarios.any((existente) => existente.id != resultado.id && existente.seSolapaCon(resultado))) {
    _mensaje(context, 'Este horario se cruza con otro en el mismo lugar.');
    return;
  }
  try {
    // El repositorio revisa además los horarios de las demás disciplinas.
    await repositorio.guardarHorario(deporte.codigo, resultado);
  } on OperacionNoPermitidaException catch (error) {
    if (context.mounted) _mensaje(context, error.mensaje);
  } on FirebaseException catch (error) {
    if (context.mounted) _mensaje(context, 'No se pudo guardar el horario: ${error.message ?? error.code}');
  }
}

class _EntrenadorDialog extends StatefulWidget {
  const _EntrenadorDialog({required this.repositorio});

  final AdminRepository repositorio;

  @override
  State<_EntrenadorDialog> createState() => _EntrenadorDialogState();
}

class _EntrenadorDialogState extends State<_EntrenadorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Stream<List<Deporte>> _deportesStream;
  final _cedula = TextEditingController();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _experiencia = TextEditingController(text: '0');
  String _nacionalidad = 'V';
  String? _deporteCodigo;

  @override
  void initState() {
    super.initState();
    _deportesStream = widget.repositorio.observarDeportes();
  }

  @override
  void dispose() {
    _cedula.dispose();
    _nombre.dispose();
    _apellido.dispose();
    _correo.dispose();
    _telefono.dispose();
    _experiencia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Deporte>>(
      stream: _deportesStream,
      builder: (context, deportesSnapshot) {
        final deportes = deportesSnapshot.data ?? const <Deporte>[];
        final deporteSeleccionado = deportes.where((deporte) => deporte.codigo == _deporteCodigo);
        final especialidad = deporteSeleccionado.isEmpty ? null : deporteSeleccionado.first.nombre;
        return AlertDialog(
      title: const Text('Registrar entrenador'),
      content: SizedBox(
        width: 440,
        child: deportesSnapshot.hasError
            ? Text('No se pudieron cargar las disciplinas: ${deportesSnapshot.error}')
            : !deportesSnapshot.hasData
                ? const Center(child: CircularProgressIndicator())
                : deportes.isEmpty
                    ? const Text('Crea una disciplina antes de registrar un entrenador.')
                    : Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombre,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                  textCapitalization: TextCapitalization.words,
                  validator: Validadores.nombre,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _apellido,
                  decoration: const InputDecoration(labelText: 'Apellido *'),
                  textCapitalization: TextCapitalization.words,
                  validator: Validadores.apellido,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: DropdownButtonFormField<String>(
                        initialValue: _nacionalidad,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: [
                          for (final letra in Validadores.nacionalidades)
                            DropdownMenuItem(value: letra, child: Text(letra)),
                        ],
                        onChanged: (letra) => setState(() => _nacionalidad = letra ?? 'V'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cedula,
                        decoration: const InputDecoration(labelText: 'Cédula *'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(9),
                        ],
                        validator: Validadores.cedula,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _correo,
                  decoration:
                      const InputDecoration(labelText: 'Correo de la UNIMET *', hintText: 'nombre@unimet.edu.ve'),
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: Validadores.correoEntrenador,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefono,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  validator: Validadores.telefono,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: deportes.any((deporte) => deporte.codigo == _deporteCodigo) ? _deporteCodigo : null,
                  decoration: const InputDecoration(labelText: 'Especialidad *'),
                  items: [
                    for (final deporte in deportes)
                      DropdownMenuItem(value: deporte.codigo, child: Text(deporte.nombre)),
                  ],
                  onChanged: (codigo) => setState(() => _deporteCodigo = codigo),
                  validator: (codigo) => codigo == null ? 'Selecciona una disciplina.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _experiencia,
                  decoration: const InputDecoration(labelText: 'Años de experiencia'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                  validator: Validadores.aniosExperiencia,
                ),
                const SizedBox(height: 8),
                const Text('Se enviará un enlace al correo para que configure su contraseña.'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: !deportesSnapshot.hasData || especialidad == null
              ? null
              : () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    _DatosEntrenador(
                      nacionalidad: _nacionalidad,
                      cedula: Validadores.numeroCedula(_cedula.text),
                      nombre: Validadores.normalizarNombre(_nombre.text),
                      apellido: Validadores.normalizarNombre(_apellido.text),
                      correo: _correo.text.trim().toLowerCase(),
                      telefono: _telefono.text.trim(),
                      especialidad: especialidad,
                      aniosExperiencia: int.parse(_experiencia.text),
                    ),
                  );
                },
          child: const Text('Crear cuenta'),
        ),
      ],
        );
      },
    );
  }
}

class _DatosEntrenador {
  const _DatosEntrenador({
    required this.nacionalidad,
    required this.cedula,
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.telefono,
    required this.especialidad,
    required this.aniosExperiencia,
  });

  final String nacionalidad;
  final int cedula;
  final String nombre;
  final String apellido;
  final String correo;
  final String telefono;
  final String especialidad;
  final int aniosExperiencia;
}

Future<void> _crearEntrenador(BuildContext context, AdminRepository repositorio) async {
  final datos = await showDialog<_DatosEntrenador>(
    context: context,
    builder: (_) => _EntrenadorDialog(repositorio: repositorio),
  );
  if (datos == null || !context.mounted) return;
  try {
    await repositorio.registrarEntrenador(
      nacionalidad: datos.nacionalidad,
      cedula: datos.cedula,
      nombre: datos.nombre,
      apellido: datos.apellido,
      correo: datos.correo,
      telefono: datos.telefono,
      especialidad: datos.especialidad,
      aniosExperiencia: datos.aniosExperiencia,
    );
    if (context.mounted) _mensaje(context, 'Entrenador creado. Enviamos el enlace de contraseña a ${datos.correo}.');
  } on EntrenadorCreadoException {
    if (context.mounted) {
      _mensaje(
          context, 'La cuenta se creó, pero no se pudo enviar el enlace. Reenvíalo desde la lista de entrenadores.');
    }
  } on FirebaseAuthException catch (error) {
    if (context.mounted) _mensaje(context, 'No se pudo crear la cuenta: ${error.message ?? error.code}');
  } on FirebaseException catch (error) {
    if (context.mounted) _mensaje(context, 'No se pudo guardar el entrenador: ${error.message ?? error.code}');
  } on StateError catch (error) {
    if (context.mounted) _mensaje(context, error.message);
  } on OperacionNoPermitidaException catch (error) {
    if (context.mounted) _mensaje(context, error.mensaje);
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.icono, required this.mensaje});

  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 48),
              const SizedBox(height: 12),
              Text(mensaje, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No se pudieron cargar los datos: $error', textAlign: TextAlign.center),
        ),
      );
}

void _mensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
}

String _nombreDia(DiaSemana dia) => switch (dia) {
      DiaSemana.lunes => 'Lunes',
      DiaSemana.martes => 'Martes',
      DiaSemana.miercoles => 'Miércoles',
      DiaSemana.jueves => 'Jueves',
      DiaSemana.viernes => 'Viernes',
      DiaSemana.sabado => 'Sábado',
      DiaSemana.domingo => 'Domingo',
    };

TimeOfDay _horaDesdeTexto(String hora) {
  final partes = hora.split(':');
  return TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
}

String _horaATexto(TimeOfDay hora) =>
    '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

int _minutos(TimeOfDay hora) => hora.hour * 60 + hora.minute;
