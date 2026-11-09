import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/validadores.dart';
import '../../models/persona.dart';
import '../../repositories/admin_repository_firebase.dart';
import '../../widgets/avatar_usuario.dart';

/// Gestión de usuarios para la Coordinación de Deportes (RF-03, edición de perfiles):
/// busca por nombre, apellido, cédula, correo o carnet, filtra por rol, marca la
/// solvencia de los estudiantes y edita los datos de cualquier perfil.
class UsuariosTab extends StatefulWidget {
  const UsuariosTab({super.key, required this.repositorio});

  final AdminRepository repositorio;

  @override
  State<UsuariosTab> createState() => _UsuariosTabState();
}

enum _Orden { apellido, cedula }

class _UsuariosTabState extends State<UsuariosTab> {
  late final Stream<List<Persona>> _usuarios = widget.repositorio.observarUsuarios();
  String _texto = '';
  Rol? _rol;
  bool _soloNoSolventes = false;
  _Orden _orden = _Orden.apellido;

  /// Quita acentos y pasa a minúsculas para que "jose" encuentre a "José".
  static String _plano(String texto) {
    const con = 'áéíóúüñÁÉÍÓÚÜÑ';
    const sin = 'aeiouunAEIOUUN';
    final b = StringBuffer();
    for (final c in texto.split('')) {
      final i = con.indexOf(c);
      b.write(i >= 0 ? sin[i] : c);
    }
    return b.toString().toLowerCase();
  }

  bool _coincide(Persona u) {
    if (_rol != null && u.rol != _rol) return false;
    if (_soloNoSolventes && !(u is Estudiante && !u.solvente)) return false;
    final q = _plano(_texto.trim());
    if (q.isEmpty) return true;
    final digitos = q.replaceAll(RegExp(r'[\s.]'), '');
    if (RegExp(r'^\d+$').hasMatch(digitos)) {
      return '${u.cedula}'.startsWith(digitos) || (u is Estudiante && u.carnet.startsWith(digitos));
    }
    return _plano('${u.nombre} ${u.apellido} ${u.correo}').contains(q);
  }

  Future<void> _cambiarSolvencia(Estudiante e, bool solvente) async {
    try {
      await widget.repositorio.actualizarUsuario(e.uid, {'solvente': solvente});
      if (mounted) {
        _mensaje(context, solvente ? '${e.nombreCompleto} quedó solvente.' : '${e.nombreCompleto} quedó no solvente.');
      }
    } on FirebaseException catch (error) {
      if (mounted) _mensaje(context, 'No se pudo guardar: ${error.message ?? error.code}');
    }
  }

  Future<void> _eliminar(Persona usuario) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Eliminar a ${usuario.nombreCompleto}'),
        content: const Text(
            'Se borrará su perfil y quedará sin acceso a la plataforma. Un estudiante solo se puede eliminar si no '
            'tiene inscripciones vigentes, y un entrenador si no tiene disciplinas asignadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar usuario'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await widget.repositorio.eliminarUsuario(usuario.uid);
      if (mounted) _mensaje(context, '${usuario.nombreCompleto} fue eliminado.');
    } on OperacionNoPermitidaException catch (e) {
      if (mounted) _mensaje(context, e.mensaje);
    } on FirebaseException catch (error) {
      if (mounted) _mensaje(context, 'No se pudo eliminar: ${error.message ?? error.code}');
    }
  }

  Future<void> _editar(Persona usuario) async {
    final cambios = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditarUsuarioDialog(usuario: usuario),
    );
    if (cambios != null && cambios['__eliminar'] == true) {
      await _eliminar(usuario);
      return;
    }
    if (cambios == null || cambios.isEmpty || !mounted) return;
    try {
      await widget.repositorio.actualizarUsuario(usuario.uid, cambios);
      if (mounted) _mensaje(context, 'Perfil de ${usuario.nombre} actualizado.');
    } on FirebaseException catch (error) {
      if (mounted) _mensaje(context, 'No se pudo guardar: ${error.message ?? error.code}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Persona>>(
      stream: _usuarios,
      builder: (context, foto) {
        if (foto.hasError) {
          return Center(child: Text('No se pudieron cargar los usuarios: ${foto.error}'));
        }
        if (!foto.hasData) return const Center(child: CircularProgressIndicator());
        final todos = foto.data!;
        final lista = todos.where(_coincide).toList();
        if (_orden == _Orden.cedula) lista.sort((a, b) => a.cedula.compareTo(b.cedula));
        final estudiantes = todos.whereType<Estudiante>().toList();
        final solventes = estudiantes.where((e) => e.solvente).length;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Resumen(icono: Icons.people_alt_outlined, valor: todos.length, texto: 'usuarios'),
                      _Resumen(icono: Icons.school_outlined, valor: estudiantes.length, texto: 'estudiantes'),
                      _Resumen(
                        icono: Icons.verified_outlined,
                        valor: solventes,
                        texto: 'solventes de ${estudiantes.length}',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    onChanged: (v) => setState(() => _texto = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, apellido, cédula, correo o carnet',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final (rol, texto) in [
                        (null, 'Todos'),
                        (Rol.estudiante, 'Estudiantes'),
                        (Rol.entrenador, 'Entrenadores'),
                        (Rol.administrador, 'Administradores'),
                      ])
                        ChoiceChip(
                          label: Text(texto),
                          selected: _rol == rol,
                          onSelected: (_) => setState(() => _rol = rol),
                        ),
                      FilterChip(
                        label: const Text('Solo no solventes'),
                        selected: _soloNoSolventes,
                        onSelected: (v) => setState(() => _soloNoSolventes = v),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<_Orden>(
                        value: _orden,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: _Orden.apellido, child: Text('Ordenar por apellido')),
                          DropdownMenuItem(value: _Orden.cedula, child: Text('Ordenar por cédula')),
                        ],
                        onChanged: (o) => setState(() => _orden = o ?? _Orden.apellido),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Text(
                    lista.length == 1 ? '1 usuario' : '${lista.length} usuarios',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.gris),
                  ),
                ),
                Expanded(
                  child: lista.isEmpty
                      ? const Center(child: Text('No hay usuarios con esos filtros.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: lista.length,
                          itemBuilder: (_, i) => _FilaUsuario(
                            usuario: lista[i],
                            alEditar: () => _editar(lista[i]),
                            alCambiarSolvencia: _cambiarSolvencia,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.icono, required this.valor, required this.texto});

  final IconData icono;
  final int valor;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.naranjaClaro, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 20, color: const Color(0xFFC2410C)),
            const SizedBox(width: 8),
            Text('$valor', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(width: 4),
            Text(texto),
          ],
        ),
      );
}

class _FilaUsuario extends StatelessWidget {
  const _FilaUsuario({required this.usuario, required this.alEditar, required this.alCambiarSolvencia});

  final Persona usuario;
  final VoidCallback alEditar;
  final void Function(Estudiante, bool) alCambiarSolvencia;

  static String _rol(Rol rol) => switch (rol) {
        Rol.estudiante => 'Estudiante',
        Rol.entrenador => 'Entrenador',
        Rol.administrador => 'Administrador',
      };

  @override
  Widget build(BuildContext context) {
    final u = usuario;
    final detalle = [
      u.cedulaTexto,
      u.correo,
      if (u is Estudiante && u.carnet.isNotEmpty) 'Carnet ${u.carnet}',
      if (u is Entrenador && u.especialidad.isNotEmpty) u.especialidad,
    ].join(' · ');
    return Card(
      child: ListTile(
        onTap: alEditar,
        leading: AvatarUsuario(nombre: u.nombreCompleto, fotoUrl: u.fotoUrl, radio: 22),
        title: Text(
          u.apellido.isEmpty ? u.nombre : '${u.apellido}, ${u.nombre}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${_rol(u.rol)} · $detalle', maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: u is Estudiante
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(u.solvente ? 'Solvente' : 'No solvente',
                      style: TextStyle(color: u.solvente ? AppColors.verdeSaman : AppColors.rojo)),
                  Switch(
                    value: u.solvente,
                    onChanged: (v) => alCambiarSolvencia(u, v),
                  ),
                ],
              )
            : const Icon(Icons.edit_outlined),
      ),
    );
  }
}

/// Edita los datos de un perfil. Devuelve solo los campos que cambiaron.
class _EditarUsuarioDialog extends StatefulWidget {
  const _EditarUsuarioDialog({required this.usuario});

  final Persona usuario;

  @override
  State<_EditarUsuarioDialog> createState() => _EditarUsuarioDialogState();
}

class _EditarUsuarioDialogState extends State<_EditarUsuarioDialog> {
  final _formulario = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.usuario.nombre);
  late final _apellido = TextEditingController(text: widget.usuario.apellido);
  late final _telefono = TextEditingController(text: widget.usuario.telefono);
  late final _carrera =
      TextEditingController(text: widget.usuario is Estudiante ? (widget.usuario as Estudiante).carrera : '');
  late final _especialidad =
      TextEditingController(text: widget.usuario is Entrenador ? (widget.usuario as Entrenador).especialidad : '');
  late bool _solvente = widget.usuario is Estudiante && (widget.usuario as Estudiante).solvente;
  late bool _activo = widget.usuario is! Estudiante || (widget.usuario as Estudiante).estaActivo();

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _telefono, _carrera, _especialidad]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    if (!_formulario.currentState!.validate()) return;
    final u = widget.usuario;
    final nuevos = <String, dynamic>{
      'nombre': Validadores.normalizarNombre(_nombre.text),
      'apellido': Validadores.normalizarNombre(_apellido.text),
      'telefono': _telefono.text.replaceAll(RegExp(r'[\s-]'), ''),
      if (u is Estudiante) ...{
        'carrera': _carrera.text.trim(),
        'solvente': _solvente,
        'estado': _activo ? EstadoEstudiante.activo.name : EstadoEstudiante.inactivo.name,
      },
      if (u is Entrenador) 'especialidad': _especialidad.text.trim(),
    };
    final actuales = u.aMapa();
    nuevos.removeWhere((campo, valor) => actuales[campo] == valor);
    Navigator.pop(context, nuevos);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.usuario;
    return AlertDialog(
      title: Text('Editar a ${u.nombreCompleto}'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formulario,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${u.cedulaTexto} · ${u.correo}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  textCapitalization: TextCapitalization.words,
                  validator: Validadores.nombre,
                ),
                TextFormField(
                  controller: _apellido,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                  textCapitalization: TextCapitalization.words,
                  validator: Validadores.apellido,
                ),
                TextFormField(
                  controller: _telefono,
                  decoration: const InputDecoration(labelText: 'Teléfono', hintText: '0414-1234567'),
                  keyboardType: TextInputType.phone,
                  validator: Validadores.telefono,
                ),
                if (u is Estudiante) ...[
                  TextFormField(
                    controller: _carrera,
                    decoration: const InputDecoration(labelText: 'Carrera'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solvente'),
                    subtitle: const Text('Sin solvencia no puede inscribirse.'),
                    value: _solvente,
                    onChanged: (v) => setState(() => _solvente = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Estudiante activo'),
                    value: _activo,
                    onChanged: (v) => setState(() => _activo = v),
                  ),
                ],
                if (u is Entrenador)
                  TextFormField(
                    controller: _especialidad,
                    decoration: const InputDecoration(labelText: 'Especialidad'),
                  ),
                if (u is! Administrador) ...[
                  const Divider(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppColors.rojo),
                      onPressed: () => Navigator.pop(context, {'__eliminar': true}),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Eliminar usuario'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

void _mensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
}
