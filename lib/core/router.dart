import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/persona.dart';
import '../repositories/auth_repository.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/perfil_view_model.dart';
import '../views/comun/en_construccion_view.dart';
import '../views/comun/perfil_view.dart';
import '../views/publico/inicio_view.dart';
import '../views/publico/login_view.dart';
import '../views/publico/recuperar_clave_view.dart';
import '../views/publico/registro_view.dart';

/// Rutas que se pueden abrir sin iniciar sesión.
const _rutasPublicas = {'/', '/login', '/registro', '/recuperar-clave', '/catalogo'};

/// Rutas de la aplicación (ver el diagrama de rutas del Hito 1).
///
/// El guardia de autenticación manda al login a quien abre una ruta protegida sin
/// sesión, y a su pantalla de inicio a quien intenta entrar en la sección de otro rol.
GoRouter crearRouter(AuthViewModel auth) {
  return GoRouter(
    refreshListenable: auth,
    redirect: (context, state) => redirigir(auth.usuario, state.uri),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const InicioView()),
      GoRoute(
        path: '/login',
        builder: (_, state) => LoginView(destino: state.uri.queryParameters['destino']),
      ),
      GoRoute(path: '/registro', builder: (_, __) => const RegistroView()),
      GoRoute(path: '/recuperar-clave', builder: (_, __) => const RecuperarClaveView()),
      GoRoute(path: '/catalogo', builder: (_, __) => const EnConstruccionView(titulo: 'Catálogo de deportes')),
      GoRoute(
        path: '/perfil',
        builder: (context, __) => ChangeNotifierProvider(
          create: (_) => PerfilViewModel(context.read<AuthRepository>()),
          child: const PerfilView(),
        ),
      ),
      GoRoute(
        path: '/entrenador/mis-deportes',
        builder: (_, __) => const EnConstruccionView(titulo: 'Mis deportes'),
      ),
      GoRoute(
          path: '/admin/dashboard', builder: (_, __) => const EnConstruccionView(titulo: 'Panel de administración')),
    ],
  );
}

/// Decide a dónde redirigir según la sesión y el rol; `null` deja pasar.
String? redirigir(Persona? usuario, Uri uri) {
  final ruta = uri.path;
  if (usuario == null) {
    if (_rutasPublicas.contains(ruta)) return null;
    return Uri(path: '/login', queryParameters: {'destino': uri.toString()}).toString();
  }
  final inicio = AuthViewModel.rutaInicio(usuario.rol);
  if (ruta == '/login' || ruta == '/registro') {
    return uri.queryParameters['destino'] ?? inicio;
  }
  if (ruta.startsWith('/entrenador') && usuario.rol != Rol.entrenador) return inicio;
  if (ruta.startsWith('/admin') && usuario.rol != Rol.administrador) return inicio;
  return null;
}
