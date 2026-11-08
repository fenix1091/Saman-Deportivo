import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/admin_repository_firebase.dart';
import 'package:saman_deportivo/views/admin/reservas_tab.dart';

/// Repositorio del administrador en memoria con reservas en distintos estados.
class _AdminFalso implements AdminRepository {
  _AdminFalso(this.reservas);

  List<Inscripcion> reservas;
  final confirmadas = <String>[];
  final rechazadas = <String, String>{};
  final _flujo = StreamController<List<Inscripcion>>.broadcast();

  @override
  Stream<List<Inscripcion>> observarInscripciones() async* {
    yield reservas;
    yield* _flujo.stream;
  }

  @override
  Stream<List<Persona>> observarUsuarios() => Stream.value(const [
        Estudiante(uid: 'a', cedula: 31985476, nombre: 'Vincenzo', apellido: 'Gallo', correo: 'v@correo.unimet.edu.ve', carnet: ''),
        Estudiante(uid: 'b', cedula: 28424728, nombre: 'Adriana', apellido: 'Julián', correo: 'a@correo.unimet.edu.ve', carnet: ''),
      ]);

  void _cambiar(String id, EstadoInscripcion estado, [String motivo = '']) {
    reservas = [for (final r in reservas) r.id == id ? r.copiarCon(estado: estado, motivo: motivo) : r];
    _flujo.add(reservas);
  }

  @override
  Future<void> confirmarReserva(String id) async {
    confirmadas.add(id);
    _cambiar(id, EstadoInscripcion.confirmada);
  }

  @override
  Future<void> rechazarReserva(String id, String motivo) async {
    rechazadas[id] = motivo;
    _cambiar(id, EstadoInscripcion.rechazada, motivo);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Inscripcion reserva(String codigo, String uid, EstadoInscripcion estado, {String nombre = ''}) => Inscripcion(
        id: Inscripcion.idPara(codigo, uid),
        estudianteId: uid,
        deporteCodigo: codigo,
        fechaInscripcion: DateTime(2026, 11, 8, 10),
        estado: estado,
        nombreDeporte: nombre,
        monto: 5,
        pagoId: estado == EstadoInscripcion.enRevision ? '${codigo}_${uid}_1' : '',
      );

  Future<_AdminFalso> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _AdminFalso([
      reserva('FUT-01', 'a', EstadoInscripcion.enRevision, nombre: 'Fútbol'),
      reserva('BAS-01', 'b', EstadoInscripcion.enRevision, nombre: 'Baloncesto'),
      reserva('TEN-01', 'a', EstadoInscripcion.confirmada, nombre: 'Tenis'),
    ]);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: Scaffold(body: ReservasTab(repositorio: repo))),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('muestra primero las reservas en revisión, con el estudiante y el monto', (tester) async {
    await abrir(tester);
    expect(find.text('En revisión (2)'), findsOneWidget);
    expect(find.text('Fútbol (FUT-01)'), findsOneWidget);
    expect(find.text('Baloncesto (BAS-01)'), findsOneWidget);
    expect(find.text('Tenis (TEN-01)'), findsNothing, reason: 'las confirmadas no salen en el filtro inicial');
    expect(find.textContaining('Vincenzo Gallo · V-31985476'), findsOneWidget);
    expect(find.textContaining('\$5.00'), findsNWidgets(2));
  });

  testWidgets('confirma una reserva y la saca de la lista de revisión', (tester) async {
    final repo = await abrir(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar').first);
    await tester.pumpAndSettle();
    expect(repo.confirmadas, ['FUT-01_a']);
    expect(find.text('Reserva confirmada.'), findsOneWidget);
    expect(find.text('Fútbol (FUT-01)'), findsNothing);
    expect(find.text('En revisión (1)'), findsOneWidget);
  });

  testWidgets('rechaza una reserva pidiendo el motivo', (tester) async {
    final repo = await abrir(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Rechazar').first);
    await tester.pumpAndSettle();
    expect(find.text('Rechazar reserva'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'El comprobante no coincide');
    await tester.tap(find.text('Rechazar y liberar cupo'));
    await tester.pumpAndSettle();
    expect(repo.rechazadas, {'FUT-01_a': 'El comprobante no coincide'});
    expect(find.text('Reserva rechazada; el cupo quedó libre.'), findsOneWidget);
  });

  testWidgets('filtra por estado y busca por estudiante', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Confirmada (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Tenis (TEN-01)'), findsOneWidget);
    await tester.tap(find.text('Todas (3)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'adriana');
    await tester.pumpAndSettle();
    expect(find.text('Baloncesto (BAS-01)'), findsOneWidget);
    expect(find.text('Fútbol (FUT-01)'), findsNothing);
  });
}
