import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/admin_repository_firebase.dart';
import 'package:saman_deportivo/viewmodels/auth_view_model.dart';
import 'package:saman_deportivo/views/admin/admin_dashboard_view.dart';

import 'falsos/auth_repository_falso.dart';

class _AdminRepositoryFalso extends Fake implements AdminRepository {
  String? especialidadRegistrada;

  @override
  Stream<List<Deporte>> observarDeportes() => Stream.value(const [
        Deporte(codigo: 'FUT-01', nombre: 'Fútbol', cupoMaximo: 20),
        Deporte(codigo: 'NAT-01', nombre: 'Natación', cupoMaximo: 12),
      ]);

  @override
  Stream<List<Entrenador>> observarEntrenadores() => Stream.value(const []);

  @override
  Future<void> registrarEntrenador({
    required String nacionalidad,
    required int cedula,
    required String nombre,
    required String apellido,
    required String correo,
    required String telefono,
    required String especialidad,
    required int aniosExperiencia,
  }) async {
    especialidadRegistrada = especialidad;
  }
}

void main() {
  testWidgets(
      'el formulario de entrenador permite elegir una disciplina existente',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final repositorio = _AdminRepositoryFalso();
    final auth = AuthViewModel(AuthRepositoryFalso());
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => AdminDashboardView(
            repositorio: repositorio,
            seccion: SeccionAdmin.entrenadores,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo entrenador'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Especialidad *'));
    await tester.pumpAndSettle();
    expect(find.text('Fútbol'), findsOneWidget);
    expect(find.text('Natación'), findsOneWidget);

    await tester.tap(find.text('Natación').last);
    await tester.pumpAndSettle();

    expect(find.text('Natación'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre *'), 'Lucía');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Apellido *'), 'Pérez');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Cédula *'), '12345678');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo de la UNIMET *'),
        'lucia@unimet.edu.ve');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(repositorio.especialidadRegistrada, 'Natación');
  });
}
