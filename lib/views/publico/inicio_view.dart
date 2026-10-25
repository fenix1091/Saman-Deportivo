import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

/// Pantalla de bienvenida pública.
class InicioView extends StatelessWidget {
  const InicioView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('design/marca/logo_horizontal.png', width: 320),
                const SizedBox(height: 16),
                Text(
                  'Tu deporte en la UNIMET, a un toque',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.gris),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/registro'),
                  child: const Text('Crear cuenta'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/catalogo'),
                  child: const Text('Ver deportes sin iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
