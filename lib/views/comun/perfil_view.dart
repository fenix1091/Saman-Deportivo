import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/validadores.dart';
import '../../models/persona.dart';
import '../../viewmodels/perfil_view_model.dart';
import '../dialogs/novedades_dialog.dart';
import '../../widgets/avatar_usuario.dart';
import '../../widgets/formulario_centrado.dart';
import '../../widgets/panel_con_menu.dart';

/// Perfil del usuario, común a los tres roles (CU-03, RF-03).
class PerfilView extends StatefulWidget {
  const PerfilView({super.key});

  @override
  State<PerfilView> createState() => _PerfilViewState();
}

class _PerfilViewState extends State<PerfilView> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _apellido;
  late final TextEditingController _telefono;

  @override
  void initState() {
    super.initState();
    final usuario = context.read<PerfilViewModel>().usuario;
    _nombre = TextEditingController(text: usuario?.nombre ?? '');
    _apellido = TextEditingController(text: usuario?.apellido ?? '');
    _telefono = TextEditingController(text: usuario?.telefono ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _cambiarFoto() async {
    final archivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80);
    if (archivo == null || !mounted) return;
    final bytes = await archivo.readAsBytes();
    if (!mounted) return;
    context.read<PerfilViewModel>().elegirFoto(bytes, archivo.name);
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    final ok =
        await context.read<PerfilViewModel>().guardar(
          nombre: _nombre.text,
          apellido: _apellido.text,
          telefono: _telefono.text,
        );
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PerfilViewModel>();
    final usuario = vm.usuario;
    if (usuario == null) return const Scaffold(body: SizedBox.shrink());
    final textos = Theme.of(context).textTheme;
    return PanelConMenu(
      titulo: const Text('Mi perfil'),
      body: FormularioCentrado(
        child: Form(
          key: _formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Center(
                    child: AvatarUsuario(
                        nombre: usuario.nombreCompleto,
                        fotoUrl: usuario.fotoUrl,
                        bytes: vm.fotoNueva),
                  ),
                  // Solo el administrador ve el registro de actualizaciones del sistema.
                  if (usuario.rol == Rol.administrador)
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton.filledTonal(
                        tooltip: 'Registro de actualizaciones',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.naranjaClaro,
                          foregroundColor: AppColors.naranjaProfundo,
                        ),
                        onPressed: () => NovedadesDialog.mostrar(context),
                        icon: const Icon(Icons.history),
                      ),
                    ),
                ],
              ),
              Center(
                child: TextButton.icon(
                  onPressed: vm.guardando ? null : _cambiarFoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Cambiar foto'),
                ),
              ),
              Text(usuario.nombreCompleto,
                  style: textos.titleLarge, textAlign: TextAlign.center),
              Text(_nombreRol(usuario.rol),
                  style: textos.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              _Dato(etiqueta: 'Cédula', valor: usuario.cedulaTexto),
              _Dato(etiqueta: 'Correo', valor: usuario.correo),
              ..._datosDelRol(usuario),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: Validadores.nombre,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apellido,
                decoration: const InputDecoration(labelText: 'Apellido'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: Validadores.apellido,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefono,
                decoration: const InputDecoration(
                    labelText: 'Teléfono', hintText: '0414-1234567'),
                keyboardType: TextInputType.phone,
                validator: Validadores.telefono,
              ),
              if (vm.error != null) ...[
                const SizedBox(height: 16),
                MensajeError(vm.error!),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: vm.guardando ? null : _guardar,
                child: vm.guardando
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Guardar'),
              ),
              const SizedBox(height: 8),
              Text(
                'La cédula, el correo y los datos de tu rol solo los puede cambiar la Coordinación de Deportes.',
                style: textos.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _nombreRol(Rol rol) => switch (rol) {
        Rol.estudiante => 'Estudiante',
        Rol.entrenador => 'Entrenador',
        Rol.administrador => 'Administrador',
      };

  static List<Widget> _datosDelRol(Persona usuario) => switch (usuario) {
        Estudiante e => [
            _Dato(etiqueta: 'Carnet', valor: e.carnet.isEmpty ? 'No registrado' : e.carnet),
            _Dato(
                etiqueta: 'Estado',
                valor: e.estaActivo() ? 'Activo' : 'Inactivo'),
            if (e.carrera.isNotEmpty)
              _Dato(etiqueta: 'Carrera', valor: e.carrera),
          ],
        Entrenador e => [
            _Dato(etiqueta: 'Especialidad', valor: e.especialidad),
            _Dato(
                etiqueta: 'Años de experiencia',
                valor: '${e.aniosExperiencia}'),
          ],
        Administrador a => [
            if (a.cargo.isNotEmpty) _Dato(etiqueta: 'Cargo', valor: a.cargo),
          ],
        _ => const [],
      };
}

/// Fila de solo lectura con un dato del perfil.
class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 150,
              child: Text(etiqueta,
                  style: textos.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(child: Text(valor, style: textos.bodyMedium)),
        ],
      ),
    );
  }
}
