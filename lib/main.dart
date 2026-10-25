import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'repositories/auth_repository.dart';
import 'repositories/auth_repository_firebase.dart';
import 'repositories/deporte_repository.dart';
import 'repositories/deporte_repository_firebase.dart';
import 'repositories/inscripcion_repository.dart';
import 'repositories/inscripcion_repository_firebase.dart';
import 'repositories/pasarela_pago.dart';
import 'viewmodels/auth_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(SamanDeportivoApp(
    repositorio: AuthRepositoryFirebase(),
    deportes: DeporteRepositoryFirebase(),
    inscripciones: InscripcionRepositoryFirebase(),
    pasarela: PasarelaPayPalSimulada(),
  ));
}

/// Punto de entrada de Samán Deportivo.
///
/// Recibe los repositorios para que las pruebas puedan usar unos falsos.
class SamanDeportivoApp extends StatefulWidget {
  const SamanDeportivoApp({
    super.key,
    required this.repositorio,
    required this.deportes,
    required this.inscripciones,
    required this.pasarela,
  });

  final AuthRepository repositorio;
  final DeporteRepository deportes;
  final InscripcionRepository inscripciones;
  final PasarelaPago pasarela;

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
        Provider<DeporteRepository>.value(value: widget.deportes),
        Provider<InscripcionRepository>.value(value: widget.inscripciones),
        Provider<PasarelaPago>.value(value: widget.pasarela),
        ChangeNotifierProvider<AuthViewModel>.value(value: _auth),
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
