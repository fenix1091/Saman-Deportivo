import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'repositories/admin_repository_firebase.dart';
import 'repositories/asistencia_repository.dart';
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
    this.deportes,
    this.inscripciones,
    this.pasarela,
    this.adminRepository,
    this.asistenciaRepository,
  });

  final AuthRepository repositorio;

  /// Los demás repositorios son opcionales: si no se pasan se usan los de Firebase.
  final DeporteRepository? deportes;
  final InscripcionRepository? inscripciones;
  final PasarelaPago? pasarela;
  final AdminRepository? adminRepository;
  final AsistenciaRepository? asistenciaRepository;

  @override
  State<SamanDeportivoApp> createState() => _SamanDeportivoAppState();
}

class _SamanDeportivoAppState extends State<SamanDeportivoApp> {
  late final AuthViewModel _auth = AuthViewModel(widget.repositorio);
  late final GoRouter _router = crearRouter(_auth,
      adminRepository: widget.adminRepository,
      asistenciaRepository: widget.asistenciaRepository);

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
        Provider<DeporteRepository>(create: (_) => widget.deportes ?? DeporteRepositoryFirebase()),
        Provider<InscripcionRepository>(create: (_) => widget.inscripciones ?? InscripcionRepositoryFirebase()),
        Provider<PasarelaPago>(create: (_) => widget.pasarela ?? PasarelaPayPalSimulada()),
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
