import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/validadores.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/formulario_centrado.dart';

/// Envío del enlace para restablecer la contraseña (CU-02, flujo alternativo A3).
class RecuperarClaveView extends StatefulWidget {
  const RecuperarClaveView({super.key});

  @override
  State<RecuperarClaveView> createState() => _RecuperarClaveViewState();
}

class _RecuperarClaveViewState extends State<RecuperarClaveView> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  bool _enviado = false;

  @override
  void initState() {
    super.initState();
    context.read<AuthViewModel>().limpiarError();
  }

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    final ok = await context.read<AuthViewModel>().recuperarClave(_correo.text);
    if (ok && mounted) setState(() => _enviado = true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: FormularioCentrado(
        child: _enviado
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 56),
                  const SizedBox(height: 16),
                  // No se confirma si el correo existe, para no revelar qué cuentas hay.
                  Text(
                    'Si ${_correo.text.trim()} tiene una cuenta, te enviamos un enlace para '
                    'crear una contraseña nueva. Revisa también la carpeta de spam.',
                    style: textos.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: () => context.go('/login'), child: const Text('Volver a iniciar sesión')),
                ],
              )
            : Form(
                key: _formulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Escribe el correo de tu cuenta y te enviaremos un enlace para restablecer la contraseña.',
                        style: textos.bodyLarge),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _correo,
                      decoration: const InputDecoration(labelText: 'Correo'),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onFieldSubmitted: (_) => _enviar(),
                      validator: Validadores.correo,
                    ),
                    if (vm.error != null) ...[
                      const SizedBox(height: 16),
                      MensajeError(vm.error!.mensaje),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: vm.cargando ? null : _enviar,
                      child: vm.cargando
                          ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Enviar enlace'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
