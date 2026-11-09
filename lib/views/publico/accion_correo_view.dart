import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/validadores.dart';
import '../../viewmodels/accion_correo_view_model.dart';
import '../../widgets/formulario_centrado.dart';

/// Pantalla a la que llegan los enlaces de los correos: crear una contraseña
/// nueva o confirmar el correo, con la marca de Samán Deportivo.
class AccionCorreoView extends StatefulWidget {
  const AccionCorreoView({super.key});

  @override
  State<AccionCorreoView> createState() => _AccionCorreoViewState();
}

class _AccionCorreoViewState extends State<AccionCorreoView> {
  final _formulario = GlobalKey<FormState>();
  final _clave = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _oculta = true;

  @override
  void dispose() {
    _clave.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    await context.read<AccionCorreoViewModel>().guardarClave(_clave.text);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AccionCorreoViewModel>();
    return Scaffold(
      body: SafeArea(
        child: FormularioCentrado(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset('design/marca/logo_horizontal.png', height: 72, semanticLabel: 'Samán Deportivo'),
              ),
              const SizedBox(height: 28),
              ...switch (vm.estado) {
                EstadoAccion.comprobando => _comprobando(context),
                EstadoAccion.pidiendoClave => _formularioClave(context, vm),
                EstadoAccion.listo => _listo(context, vm),
                EstadoAccion.invalido => _invalido(context, vm),
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _comprobando(BuildContext context) => [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text('Comprobando el enlace…', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
      ];

  List<Widget> _formularioClave(BuildContext context, AccionCorreoViewModel vm) {
    final textos = Theme.of(context).textTheme;
    final ver = IconButton(
      tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
      icon: Icon(_oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _oculta = !_oculta),
    );
    return [
      Text('Crea tu contraseña nueva',
          textAlign: TextAlign.center, style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Cuenta: ${vm.correo}', textAlign: TextAlign.center, style: textos.bodyMedium),
      const SizedBox(height: 24),
      Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _clave,
              obscureText: _oculta,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Contraseña nueva',
                helperText: 'Mínimo 8 caracteres, con letras y números.',
                suffixIcon: ver,
              ),
              validator: Validadores.clave,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmacion,
              obscureText: _oculta,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Repite la contraseña'),
              onFieldSubmitted: (_) => _guardar(),
              validator: (v) => Validadores.confirmarClave(v, _clave.text),
            ),
          ],
        ),
      ),
      if (vm.error != null) ...[
        const SizedBox(height: 16),
        MensajeError(vm.error!),
      ],
      const SizedBox(height: 24),
      FilledButton(
        onPressed: vm.guardando ? null : _guardar,
        child: vm.guardando
            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : const Text('Guardar contraseña'),
      ),
    ];
  }

  List<Widget> _listo(BuildContext context, AccionCorreoViewModel vm) {
    final textos = Theme.of(context).textTheme;
    final clave = vm.modo == ModoAccion.restablecerClave;
    return [
      Icon(Icons.check_circle_outline, size: 64, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 16),
      Text(clave ? 'Contraseña cambiada' : 'Correo verificado',
          textAlign: TextAlign.center, style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(
        clave
            ? 'Ya puedes entrar a Samán Deportivo con tu contraseña nueva.'
            : 'Gracias por confirmar tu correo. Ya puedes seguir usando Samán Deportivo.',
        textAlign: TextAlign.center,
        style: textos.bodyLarge,
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => context.go(clave ? '/login' : '/'),
        child: Text(clave ? 'Iniciar sesión' : 'Ir a Samán Deportivo'),
      ),
    ];
  }

  List<Widget> _invalido(BuildContext context, AccionCorreoViewModel vm) {
    final textos = Theme.of(context).textTheme;
    return [
      Icon(Icons.link_off, size: 64, color: Theme.of(context).colorScheme.error),
      const SizedBox(height: 16),
      Text('El enlace ya no sirve',
          textAlign: TextAlign.center, style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(vm.error ?? 'Este enlace venció o ya se usó.', textAlign: TextAlign.center, style: textos.bodyLarge),
      const SizedBox(height: 24),
      if (vm.modo != ModoAccion.verificarCorreo)
        FilledButton(
          onPressed: () => context.go('/recuperar-clave'),
          child: const Text('Pedir un enlace nuevo'),
        ),
      const SizedBox(height: 8),
      TextButton(onPressed: () => context.go('/'), child: const Text('Ir al inicio')),
    ];
  }
}
