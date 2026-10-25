import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/validadores.dart';
import '../../models/deporte.dart';
import '../../models/persona.dart';
import '../../repositories/admin_repository_firebase.dart';
import '../../viewmodels/auth_view_model.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key, required this.repositorio});

  final AdminRepository repositorio;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración deportiva'),
          actions: [
            IconButton(
              tooltip: 'Mi perfil',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => context.push('/perfil'),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthViewModel>().cerrarSesion(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                  icon: Icon(Icons.event_available_outlined),
                  text: 'Clases y horarios'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Entrenadores'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ClasesTab(repositorio: repositorio),
            _EntrenadoresTab(repositorio: repositorio),
          ],
        ),
      ),
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
        if (!entrenadoresSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final entrenadores = entrenadoresSnapshot.data!;
        return StreamBuilder<List<Deporte>>(
          stream: repositorio.observarDeportes(),
          builder: (context, deportesSnapshot) {
            if (deportesSnapshot.hasError)
              return _ErrorCarga(error: deportesSnapshot.error!);
            if (!deportesSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final deportes = deportesSnapshot.data!;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Oferta deportiva',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 160,
                          child: FilledButton.icon(
                            onPressed: () =>
                                _editarDeporte(context, repositorio),
                            icon: const Icon(Icons.add),
                            label: const Text('Nueva clase'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: deportes.isEmpty
                      ? const _Vacio(
                          icono: Icons.sports,
                          mensaje: 'Aún no hay clases. Crea la primera.')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: deportes.length,
                          itemBuilder: (context, index) => _TarjetaDeporte(
                            deporte: deportes[index],
                            entrenadores: entrenadores,
                            repositorio: repositorio,
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
    final entrenadorIds =
        entrenadores.map((entrenador) => entrenador.uid).toSet();
    final entrenadorActual = entrenadorIds.contains(deporte.entrenadorId)
        ? deporte.entrenadorId
        : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                          style: Theme.of(context).textTheme.titleLarge),
                      if (deporte.categoria.isNotEmpty) Text(deporte.categoria),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar clase',
                  onPressed: () =>
                      _editarDeporte(context, repositorio, deporte),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Configurar horarios',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _HorariosDialog(
                        deporte: deporte, repositorio: repositorio),
                  ),
                  icon: const Icon(Icons.schedule),
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
                Text(
                    '${deporte.cuposOcupados}/${deporte.cupoMaximo} cupos ocupados'),
                const Spacer(),
                Text(deporte.activo ? 'Activa' : 'Inactiva'),
                Switch(
                  value: deporte.activo,
                  onChanged: (activo) => repositorio
                      .actualizarActivoDeporte(deporte.codigo, activo)
                      .catchError((Object error) {
                    if (context.mounted)
                      _mensaje(
                          context, 'No se pudo actualizar la clase: $error');
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
                  (entrenador) => DropdownMenuItem(
                      value: entrenador.uid, child: Text(entrenador.nombre)),
                ),
              ],
              onChanged: (uid) {
                if (uid == null) return;
                repositorio
                    .asignarEntrenador(deporte.codigo, uid)
                    .catchError((Object error) {
                  if (context.mounted)
                    _mensaje(
                        context, 'No se pudo asignar el entrenador: $error');
                });
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Horario>>(
              stream: repositorio.observarHorarios(deporte.codigo),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                      'No se pudieron cargar los horarios: ${snapshot.error}');
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
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final entrenadores = snapshot.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Equipo de entrenadores',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 220,
                      child: FilledButton.icon(
                        onPressed: () => _crearEntrenador(context, repositorio),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Nuevo entrenador'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entrenadores.isEmpty
                  ? const _Vacio(
                      icono: Icons.groups_outlined,
                      mensaje: 'Aún no hay entrenadores registrados.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: entrenadores.length,
                      itemBuilder: (context, index) {
                        final entrenador = entrenadores[index];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                                child: Icon(Icons.sports_handball_outlined)),
                            title: Text(entrenador.nombre),
                            subtitle: Text(
                              '${entrenador.especialidad}\n${entrenador.correo}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip:
                                  'Reenviar enlace para configurar contraseña',
                              icon:
                                  const Icon(Icons.mark_email_unread_outlined),
                              onPressed: () async {
                                try {
                                  await repositorio
                                      .reenviarEnlace(entrenador.correo);
                                  if (context.mounted)
                                    _mensaje(context,
                                        'Enlace enviado a ${entrenador.correo}.');
                                } on FirebaseAuthException catch (error) {
                                  if (context.mounted) {
                                    _mensaje(context,
                                        'No se pudo enviar el enlace: ${error.message ?? error.code}');
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DeporteDialog extends StatefulWidget {
  const _DeporteDialog({this.deporte});

  final Deporte? deporte;

  @override
  State<_DeporteDialog> createState() => _DeporteDialogState();
}

class _DeporteDialogState extends State<_DeporteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.deporte?.nombre);
  late final _categoria =
      TextEditingController(text: widget.deporte?.categoria);
  late final _descripcion =
      TextEditingController(text: widget.deporte?.descripcion);
  late final _cupos =
      TextEditingController(text: '${widget.deporte?.cupoMaximo ?? 20}');

  @override
  void dispose() {
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
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (value) => Validadores.requerido(value, 'el nombre'),
                textCapitalization: TextCapitalization.words,
              ),
              TextFormField(
                controller: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
              ),
              TextFormField(
                controller: _descripcion,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
              TextFormField(
                controller: _cupos,
                decoration: const InputDecoration(labelText: 'Cupo máximo *'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final cupos = int.tryParse(value ?? '');
                  if (cupos == null || cupos < 1)
                    return 'Ingresa un cupo mayor que cero.';
                  if (widget.deporte != null &&
                      cupos < widget.deporte!.cuposOcupados) {
                    return 'No puede ser menor que los ${widget.deporte!.cuposOcupados} inscritos.';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final anterior = widget.deporte;
            final cupos = int.parse(_cupos.text);
            Navigator.pop(
              context,
              Deporte(
                codigo: anterior?.codigo ?? '',
                nombre: _nombre.text.trim(),
                categoria: _categoria.text.trim(),
                descripcion: _descripcion.text.trim(),
                cupoMaximo: cupos,
                cuposOcupados: anterior?.cuposOcupados ?? 0,
                costoReserva: anterior?.costoReserva ?? 0,
                imagenUrl: anterior?.imagenUrl ?? '',
                entrenadorId: anterior?.entrenadorId ?? '',
                activo: anterior?.activo ?? true,
                vecesBuscado: anterior?.vecesBuscado ?? 0,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

Future<void> _editarDeporte(BuildContext context, AdminRepository repositorio,
    [Deporte? deporte]) async {
  final resultado = await showDialog<Deporte>(
    context: context,
    builder: (_) => _DeporteDialog(deporte: deporte),
  );
  if (resultado == null || !context.mounted) return;
  try {
    await repositorio.guardarDeporte(resultado);
  } on FirebaseException catch (error) {
    if (context.mounted)
      _mensaje(context,
          'No se pudo guardar la clase: ${error.message ?? error.code}');
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
            if (snapshot.hasError)
              return Text(
                  'No se pudieron cargar los horarios: ${snapshot.error}');
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final horarios = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (horarios.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child:
                        Text('Agrega los días, horas y lugares de esta clase.'),
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
                          title: Text(
                              '${_nombreDia(horario.dia)} · ${horario.horaInicio}-${horario.horaFin}'),
                          subtitle: Text(horario.lugar),
                          onTap: () => _editarHorario(
                              context, repositorio, deporte, horarios, horario),
                          trailing: IconButton(
                            tooltip: 'Eliminar horario',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              try {
                                await repositorio.eliminarHorario(
                                    deporte.codigo, horario.id);
                              } on FirebaseException catch (error) {
                                if (context.mounted) {
                                  _mensaje(context,
                                      'No se pudo eliminar el horario: ${error.message ?? error.code}');
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
                  onPressed: () =>
                      _editarHorario(context, repositorio, deporte, horarios),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar horario'),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Listo'))
      ],
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
  late TimeOfDay _inicio =
      _horaDesdeTexto(widget.horario?.horaInicio ?? '16:00');
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
      title:
          Text(widget.horario == null ? 'Agregar horario' : 'Editar horario'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<DiaSemana>(
              initialValue: _dia,
              decoration: const InputDecoration(labelText: 'Día'),
              items: DiaSemana.values
                  .map((dia) => DropdownMenuItem(
                      value: dia, child: Text(_nombreDia(dia))))
                  .toList(),
              onChanged: (dia) {
                if (dia != null) setState(() => _dia = dia);
              },
            ),
            Row(
              children: [
                Expanded(
                    child: _SelectorHora(
                        label: 'Desde',
                        hora: _inicio,
                        onChange: (hora) => setState(() => _inicio = hora))),
                const SizedBox(width: 12),
                Expanded(
                    child: _SelectorHora(
                        label: 'Hasta',
                        hora: _fin,
                        onChange: (hora) => setState(() => _fin = hora))),
              ],
            ),
            TextFormField(
              controller: _lugar,
              decoration: const InputDecoration(labelText: 'Lugar *'),
              validator: (value) => Validadores.requerido(value, 'el lugar'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_minutos(_inicio) >= _minutos(_fin)) {
              _mensaje(context,
                  'La hora de fin debe ser posterior a la hora de inicio.');
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
  const _SelectorHora(
      {required this.label, required this.hora, required this.onChange});

  final String label;
  final TimeOfDay hora;
  final ValueChanged<TimeOfDay> onChange;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        final seleccion =
            await showTimePicker(context: context, initialTime: hora);
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
  if (horarios.any((existente) =>
      existente.id != resultado.id && existente.seSolapaCon(resultado))) {
    _mensaje(context, 'Este horario se cruza con otro en el mismo lugar.');
    return;
  }
  try {
    await repositorio.guardarHorario(deporte.codigo, resultado);
  } on FirebaseException catch (error) {
    if (context.mounted)
      _mensaje(context,
          'No se pudo guardar el horario: ${error.message ?? error.code}');
  }
}

class _EntrenadorDialog extends StatefulWidget {
  const _EntrenadorDialog();

  @override
  State<_EntrenadorDialog> createState() => _EntrenadorDialogState();
}

class _EntrenadorDialogState extends State<_EntrenadorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cedula = TextEditingController();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _especialidad = TextEditingController();
  final _experiencia = TextEditingController(text: '0');

  @override
  void dispose() {
    _cedula.dispose();
    _nombre.dispose();
    _correo.dispose();
    _telefono.dispose();
    _especialidad.dispose();
    _experiencia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar entrenador'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombre,
                  decoration:
                      const InputDecoration(labelText: 'Nombre y apellido *'),
                  textCapitalization: TextCapitalization.words,
                  validator: Validadores.nombre,
                ),
                TextFormField(
                  controller: _cedula,
                  decoration: const InputDecoration(labelText: 'Cédula *'),
                  validator: Validadores.cedula,
                ),
                TextFormField(
                  controller: _correo,
                  decoration:
                      const InputDecoration(labelText: 'Correo electrónico *'),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validadores.correo,
                ),
                TextFormField(
                  controller: _telefono,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  validator: Validadores.telefono,
                ),
                TextFormField(
                  controller: _especialidad,
                  decoration:
                      const InputDecoration(labelText: 'Especialidad *'),
                  validator: (value) =>
                      Validadores.requerido(value, 'la especialidad'),
                ),
                TextFormField(
                  controller: _experiencia,
                  decoration:
                      const InputDecoration(labelText: 'Años de experiencia'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final anios = int.tryParse(value ?? '');
                    return anios == null || anios < 0
                        ? 'Ingresa un número igual o mayor que cero.'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                    'Se enviará un enlace al correo para que configure su contraseña.'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _DatosEntrenador(
                cedula: Validadores.normalizarCedula(_cedula.text),
                nombre: _nombre.text.trim(),
                correo: _correo.text.trim().toLowerCase(),
                telefono: _telefono.text.trim(),
                especialidad: _especialidad.text.trim(),
                aniosExperiencia: int.parse(_experiencia.text),
              ),
            );
          },
          child: const Text('Crear cuenta'),
        ),
      ],
    );
  }
}

class _DatosEntrenador {
  const _DatosEntrenador({
    required this.cedula,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.especialidad,
    required this.aniosExperiencia,
  });

  final String cedula;
  final String nombre;
  final String correo;
  final String telefono;
  final String especialidad;
  final int aniosExperiencia;
}

Future<void> _crearEntrenador(
    BuildContext context, AdminRepository repositorio) async {
  final datos = await showDialog<_DatosEntrenador>(
    context: context,
    builder: (_) => const _EntrenadorDialog(),
  );
  if (datos == null || !context.mounted) return;
  try {
    await repositorio.registrarEntrenador(
      cedula: datos.cedula,
      nombre: datos.nombre,
      correo: datos.correo,
      telefono: datos.telefono,
      especialidad: datos.especialidad,
      aniosExperiencia: datos.aniosExperiencia,
    );
    if (context.mounted)
      _mensaje(context,
          'Entrenador creado. Enviamos el enlace de contraseña a ${datos.correo}.');
  } on EntrenadorCreadoException {
    if (context.mounted) {
      _mensaje(context,
          'La cuenta se creó, pero no se pudo enviar el enlace. Reenvíalo desde la lista de entrenadores.');
    }
  } on FirebaseAuthException catch (error) {
    if (context.mounted)
      _mensaje(context,
          'No se pudo crear la cuenta: ${error.message ?? error.code}');
  } on FirebaseException catch (error) {
    if (context.mounted)
      _mensaje(context,
          'No se pudo guardar el entrenador: ${error.message ?? error.code}');
  } on StateError catch (error) {
    if (context.mounted) _mensaje(context, error.message);
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
          child: Text('No se pudieron cargar los datos: $error',
              textAlign: TextAlign.center),
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
