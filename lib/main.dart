import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'repositories/auth_repository.dart';
import 'repositories/auth_repository_firebase.dart';
import 'viewmodels/auth_view_model.dart';
import 'viewmodels/mis_inscripciones_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(SamanDeportivoApp(repositorio: AuthRepositoryFirebase()));
}

/// Punto de entrada de Samán Deportivo.
///
/// Recibe el repositorio de autenticación para que las pruebas puedan usar uno falso.
class SamanDeportivoApp extends StatefulWidget {
  const SamanDeportivoApp({super.key, required this.repositorio});

  final AuthRepository repositorio;

  @override
  State<SamanDeportivoApp> createState() => _SamanDeportivoAppState();
}

class _SamanDeportivoAppState extends State<SamanDeportivoApp> {
  late final AuthViewModel _auth = AuthViewModel(widget.repositorio);
  late final GoRouter _router = crearRouter(_auth);

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: widget.repositorio),
        ChangeNotifierProvider<AuthViewModel>.value(value: _auth),
        ChangeNotifierProvider(create: (_) => MisInscripcionesViewModel()),
      ],
      child: MaterialApp.router(
        title: 'Samán Deportivo',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: _router,
      ),
    );
  }
}
