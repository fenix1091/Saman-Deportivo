import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/admin_repository_firebase.dart';
import 'package:saman_deportivo/views/admin/usuarios_tab.dart';

/// Repositorio del administrador en memoria: guarda los cambios hechos a los usuarios.
class _AdminFalso implements AdminRepository {
  _AdminFalso(this.usuarios);

  List<Persona> usuarios;
  final cambios = <String, Map<String, dynamic>>{};
  final _flujo = StreamController<List<Persona>>.broadcast();

  @override
  Stream<List<Persona>> observarUsuarios() async* {
    yield usuarios;
    yield* _flujo.stream;
  }

  @override
  Future<void> actualizarUsuario(String uid, Map<String, dynamic> cambiosNuevos) async {
    cambios[uid] = cambiosNuevos;
    usuarios = [
      for (final u in usuarios) u.uid == uid ? Persona.desdeMapa(uid, {...u.aMapa(), ...cambiosNuevos}) : u,
    ];
    _flujo.add(usuarios);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final usuarios = <Persona>[
    const Estudiante(
        uid: 'a', cedula: 31985476, nombre: 'Vincenzo', apellido: 'Gallo', correo: 'v@correo.unimet.edu.ve', carnet: ''),
    const Estudiante(
        uid: 'b', cedula: 28424728, nombre: 'Adriana', apellido: 'Julián', correo: 'a@correo.unimet.edu.ve', carnet: '1'),
    const Entrenador(
        uid: 'c', cedula: 20333444, nombre: 'Carlos', apellido: 'Ruiz', correo: 'c@unimet.edu.ve', especialidad: 'Fútbol'),
  ];

  Future<_AdminFalso> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _AdminFalso(usuarios);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: UsuariosTab(repositorio: repo))));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('lista a todos los usuarios y busca sin acentos por nombre o por cédula', (tester) async {
    await abrir(tester);
    expect(find.text('3 usuarios'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'julian');
    await tester.pumpAndSettle();
    expect(find.text('Julián, Adriana'), findsOneWidget);
    expect(find.text('1 usuario'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '3198');
    await tester.pumpAndSettle();
    expect(find.text('Gallo, Vincenzo'), findsOneWidget);
    expect(find.text('1 usuario'), findsOneWidget);
  });

  testWidgets('filtra por rol y marca la solvencia de un estudiante', (tester) async {
    final repo = await abrir(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Entrenadores'));
    await tester.pumpAndSettle();
    expect(find.text('Ruiz, Carlos'), findsOneWidget);
    expect(find.text('1 usuario'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Estudiantes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(repo.cambios['a'], {'solvente': true});
    expect(find.text('Solvente'), findsOneWidget);
  });
}
