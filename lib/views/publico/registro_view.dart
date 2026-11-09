import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/validadores.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/campo_correo.dart';
import '../../widgets/casilla_robot.dart';
import '../../widgets/formulario_centrado.dart';
import '../../widgets/marco_acceso.dart';

/// Pantalla de registro de estudiantes (CU-01, RF-01).
class RegistroView extends StatefulWidget {
  const RegistroView({super.key});

  @override
  State<RegistroView> createState() => _RegistroViewState();
}

class _RegistroViewState extends State<RegistroView> {
  final _formulario = GlobalKey<FormState>();
  final _cedula = TextEditingController();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _correo = TextEditingController();
  final _carnet = TextEditingController();
  final _clave = TextEditingController();
  final _confirmacion = TextEditingController();
  String _nacionalidad = 'V';
  bool _verClave = false;
  bool _humano = false;
  bool _faltaCasilla = false;

  @override
  void initState() {
    super.initState();
    context.read<AuthViewModel>().limpiarError();
  }

  @override
  void dispose() {
    for (final c in [_cedula, _nombre, _apellido, _correo, _carnet, _clave, _confirmacion]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _crearCuenta() async {
    final valido = _formulario.currentState!.validate();
    setState(() => _faltaCasilla = !_humano);
    if (!valido || !_humano) return;
    final vm = context.read<AuthViewModel>();
    final ok = await vm.registrar(
      nacionalidad: _nacionalidad,
      cedula: _cedula.text,
      nombre: _nombre.text,
      apellido: _apellido.text,
      correo: _correo.text,
      carnet: _carnet.text,
      clave: _clave.text,
    );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('¡Bienvenido! Te enviamos un correo de verificación a ${_correo.text.trim()}.')),
    );
    context.go('/catalogo');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final textos = Theme.of(context).textTheme;
    return MarcoAcceso(
      lema: 'Únete a los clubes de la UNIMET',
      child: Form(
        key: _formulario,
        // Sin AutofillGroup ni autofillHints: en Flutter web el gestor de contraseñas
        // del navegador (la sugerencia de clave segura) se queda con el foco del campo
        // y deja de aceptar teclas, incluido borrar, hasta recargar la página.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Crea tu cuenta', style: textos.headlineMedium),
            const SizedBox(height: 4),
            Text('Solo necesitas tu correo de la UNIMET y tu cédula.', style: textos.bodyMedium),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 88,
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
                    decoration: const InputDecoration(labelText: 'Cédula', hintText: '31985476'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    textInputAction: TextInputAction.next,
                    validator: Validadores.cedula,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nombre,
                    decoration: const InputDecoration(labelText: 'Nombre', hintText: 'María José'),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: Validadores.nombre,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _apellido,
                    decoration: const InputDecoration(labelText: 'Apellido', hintText: 'Pérez López'),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: Validadores.apellido,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CampoCorreo(
              controller: _correo,
              etiqueta: 'Correo de la UNIMET',
              ayuda: 'Escribe tu usuario y elige cómo termina: @correo.unimet.edu.ve o @unimet.edu.ve.',
              sugerencia: 'usuario${Validadores.dominioEstudiantes}',
              accion: TextInputAction.next,
              // Sin autocompletado del navegador: en el registro congela los campos (ver más arriba).
              autocompletarNavegador: false,
              validator: Validadores.correoEstudiante,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _carnet,
              decoration: const InputDecoration(labelText: 'Carnet (opcional)', hintText: '11 dígitos'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              textInputAction: TextInputAction.next,
              validator: Validadores.carnet,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clave,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                helperText: 'Mínimo 8 caracteres, con al menos una letra y un número.',
                suffixIcon: IconButton(
                  tooltip: _verClave ? 'Ocultar contraseña' : 'Mostrar contraseña',
                  icon: Icon(_verClave ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _verClave = !_verClave),
                ),
              ),
              obscureText: !_verClave,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              validator: Validadores.clave,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmacion,
              decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
              obscureText: !_verClave,
              autocorrect: false,
              enableSuggestions: false,
              onFieldSubmitted: (_) => _crearCuenta(),
              validator: (v) => Validadores.confirmarClave(v, _clave.text),
            ),
            const SizedBox(height: 16),
            CasillaRobot(
              alCambiar: (marcada) => setState(() {
                _humano = marcada;
                if (marcada) _faltaCasilla = false;
              }),
            ),
            if (_faltaCasilla)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text('Marca la casilla "No soy un robot".',
                    style: textos.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
              ),
            if (vm.error != null) ...[
              const SizedBox(height: 16),
              MensajeError(
                vm.error!.mensaje,
                acciones: vm.error!.esCuentaExistente
                    ? [
                        TextButton(onPressed: () => context.go('/login'), child: const Text('Iniciar sesión')),
                        TextButton(
                          onPressed: () => context.go('/recuperar-clave'),
                          child: const Text('Recuperar contraseña'),
                        ),
                      ]
                    : const [],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: vm.cargando ? null : _crearCuenta,
              child: vm.cargando
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Crear cuenta'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('¿Ya tienes cuenta? Inicia sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
