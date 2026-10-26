import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/persona.dart';
import '../viewmodels/auth_view_model.dart';

/// Botones de la barra superior en las pantallas que también ven los visitantes.
///
/// Con sesión muestra el perfil y cerrar sesión; sin sesión, "Iniciar sesión" con
/// la ruta actual como destino, para volver aquí después del login.
class AccionesSesion extends StatelessWidget {
  const AccionesSesion({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (auth.usuario == null) {
      final aqui = GoRouterState.of(context).uri.toString();
      return TextButton(
        onPressed: () => context.go(Uri(path: '/login', queryParameters: {'destino': aqui}).toString()),
        child: const Text('Iniciar sesión'),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (auth.usuario!.rol == Rol.estudiante)
          IconButton(
            tooltip: 'Mis inscripciones',
            icon: const Icon(Icons.assignment_outlined),
            onPressed: () => context.push('/mis-inscripciones'),
          ),
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
    );
  }
}
