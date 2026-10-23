import 'package:flutter/material.dart';

import 'core/theme.dart';

void main() {
  runApp(const SamanDeportivoApp());
}

/// Punto de entrada de Samán Deportivo.
/// En el Hito 2 se agregan Firebase, las rutas (go_router) y los ViewModels (provider).
class SamanDeportivoApp extends StatelessWidget {
  const SamanDeportivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Samán Deportivo',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Bienvenida(),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  const _Bienvenida();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('design/marca/logo_horizontal.png', width: 320),
              const SizedBox(height: 16),
              Text(
                'Tu deporte en la UNIMET, a un toque',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.gris),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
