import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/validadores.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/formulario_centrado.dart';

/// Pantalla de inicio de sesión para los tres roles (CU-02, RF-02).
///
/// Al entrar, el enrutador lleva al usuario a la pantalla de su rol; si venía de
/// una ruta protegida, vuelve a ella ([destino]).
class LoginView extends StatefulWidget {
  const LoginView({super.key, this.destino});

  final String? destino;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _verClave = false;

  @override
  void initState() {
    super.initState();
    context.read<AuthViewModel>().limpiarError();
  }

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formulario.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    final ok = await vm.iniciarSesion(_correo.text, _clave.text);
    if (!ok || !mounted) return;
    context.go(widget.destino ?? AuthViewModel.rutaInicio(vm.usuario!.rol));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      body: FormularioCentrado(
        child: Form(
          key: _formulario,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('design/marca/logo_horizontal.png', height: 72),
                const SizedBox(height: 24),
                Text('Inicia sesión', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _correo,
                  decoration: const InputDecoration(labelText: 'Correo'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validadores.correo,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _clave,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    suffixIcon: IconButton(
                      tooltip: _verClave ? 'Ocultar contraseña' : 'Mostrar contraseña',
                      icon: Icon(_verClave ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _verClave = !_verClave),
                    ),
                  ),
                  obscureText: !_verClave,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _entrar(),
                  validator: (v) => Validadores.requerido(v, 'contraseña'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/recuperar-clave'),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                if (vm.error != null) ...[
                  MensajeError(vm.error!.mensaje),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: vm.cargando ? null : _entrar,
                  child: vm.cargando
                      ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/registro'),
                  child: const Text('¿No tienes cuenta? Regístrate con tu carnet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
