import 'package:go_router/go_router.dart';

import '../viewmodels/auth_view_model.dart';
import '../views/comun/en_construccion_view.dart';
import '../views/publico/inicio_view.dart';
import '../views/publico/registro_view.dart';

/// Rutas de la aplicación (ver el diagrama de rutas del Hito 1).
GoRouter crearRouter(AuthViewModel auth) {
  return GoRouter(
    refreshListenable: auth,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const InicioView()),
      GoRoute(path: '/registro', builder: (_, __) => const RegistroView()),
      GoRoute(path: '/catalogo', builder: (_, __) => const EnConstruccionView(titulo: 'Catálogo de deportes')),
    ],
  );
}
