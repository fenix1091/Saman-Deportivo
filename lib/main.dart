import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'repositories/auth_repository.dart';
import 'repositories/auth_repository_local.dart';
import 'viewmodels/auth_view_model.dart';

void main() {
  // Mientras no esté configurado Firebase se usa el repositorio en memoria;
  // al conectarlo basta con cambiar esta línea por la implementación de Firebase.
  final AuthRepository repositorio = AuthRepositoryLocal.conDatosDePrueba();
  runApp(SamanDeportivoApp(repositorio: repositorio));
}

/// Punto de entrada de Samán Deportivo.
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
