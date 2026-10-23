import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';

/// Pantalla provisional para las rutas cuyo módulo aún no está hecho.
///
/// Se reemplaza en el enrutador cuando el módulo correspondiente esté listo.
class EnConstruccionView extends StatelessWidget {
  const EnConstruccionView({super.key, required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthViewModel>().usuario;
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          if (usuario != null) ...[
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
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 56),
              const SizedBox(height: 16),
              if (usuario != null) Text('Hola, ${usuario.nombre}', style: textos.titleLarge),
              const SizedBox(height: 8),
              Text('Este módulo se construye en el Hito 3.', style: textos.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
