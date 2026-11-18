import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/core/validacion_admin.dart';
import 'package:saman_deportivo/models/deporte.dart';
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
  final canceladas = <String, (String, bool)>{};
  final cambios = <String, String>{};
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
  Future<void> cancelarReserva(String inscripcionId, {required String motivo, bool reembolsar = false}) async {
    canceladas[inscripcionId] = (motivo, reembolsar);
    _cambiar(inscripcionId, EstadoInscripcion.cancelada, motivo);
  }

  @override
  Future<void> cambiarReserva(String inscripcionId, String nuevoCodigo) async {
    cambios[inscripcionId] = nuevoCodigo;
    _cambiar(inscripcionId, EstadoInscripcion.cancelada, 'Cambiada a $nuevoCodigo');
  }

  @override
  Stream<List<Deporte>> observarDeportes() => Stream.value(const [
        Deporte(codigo: 'TEN-01', nombre: 'Tenis', cupoMaximo: 10, cuposOcupados: 3, entrenadorId: 'e'),
        Deporte(codigo: 'VOL-01', nombre: 'Voleibol', cupoMaximo: 12, cuposOcupados: 4, entrenadorId: 'e'),
        Deporte(codigo: 'NAT-01', nombre: 'Natación', cupoMaximo: 8, cuposOcupados: 8, entrenadorId: 'e'),
        Deporte(codigo: 'AJE-01', nombre: 'Ajedrez', cupoMaximo: 20, entrenadorId: 'e', activo: false),
      ]);

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

  group('Cancelar o cambiar una reserva a mano', () {
    final ausente = Inscripcion(
      id: 'FUT-01_b',
      estudianteId: 'b',
      deporteCodigo: 'FUT-01',
      fechaInscripcion: DateTime(2026, 11, 1),
      estado: EstadoInscripcion.confirmada,
      nombreDeporte: 'Fútbol',
      monto: 5,
      pagoId: 'FUT-01_b_1',
      sesiones: 3,
      sesionesAsistidas: 0,
    );

    test('reglas: solo reservas vigentes, y el destino debe tener cupo, entrenador y estar activo', () {
      const voleibol = Deporte(codigo: 'VOL-01', nombre: 'Voleibol', cupoMaximo: 12, entrenadorId: 'e');
      expect(ValidacionAdmin.cancelarReserva(ausente), isNull);
      expect(ValidacionAdmin.cancelarReserva(ausente.copiarCon(estado: EstadoInscripcion.cancelada)),
          'Esta reserva ya no está vigente (cancelada).');
      expect(ValidacionAdmin.cambiarReserva(ausente, voleibol, const []), isNull);
      expect(ValidacionAdmin.cambiarReserva(ausente, const Deporte(codigo: 'FUT-01', nombre: 'Fútbol', cupoMaximo: 9), []),
          'La reserva ya es de Fútbol.');
      expect(
          ValidacionAdmin.cambiarReserva(
              ausente, const Deporte(codigo: 'NAT-01', nombre: 'Natación', cupoMaximo: 8, cuposOcupados: 8, entrenadorId: 'e'), []),
          'Natación no tiene cupos disponibles.');
      expect(
          ValidacionAdmin.cambiarReserva(
              ausente.copiarCon(estado: EstadoInscripcion.pendientePago),
              const Deporte(codigo: 'NAT-01', nombre: 'Natación', cupoMaximo: 8, cuposOcupados: 8, entrenadorId: 'e'),
              []),
          isNull,
          reason: 'una reserva sin pagar no ocupa cupo');
      expect(ValidacionAdmin.cambiarReserva(ausente, const Deporte(codigo: 'X-1', nombre: 'Yoga', cupoMaximo: 5), []),
          'Yoga no tiene entrenador asignado.');
      final yaInscrito = Inscripcion(
          id: 'VOL-01_b',
          estudianteId: 'b',
          deporteCodigo: 'VOL-01',
          fechaInscripcion: DateTime(2026, 11, 1),
          estado: EstadoInscripcion.enRevision);
      expect(ValidacionAdmin.cambiarReserva(ausente, voleibol, [yaInscrito]),
          'El estudiante ya tiene una reserva vigente en Voleibol.');
      expect(ValidacionAdmin.noSePresenta(ausente), isTrue);
      expect(ValidacionAdmin.noSePresenta(ausente.copiarCon(estado: EstadoInscripcion.enRevision)), isFalse);
    });

    Future<_AdminFalso> abrirConAusente(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _AdminFalso([
        ausente,
        reserva('TEN-01', 'a', EstadoInscripcion.confirmada, nombre: 'Tenis'),
      ]);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: ReservasTab(repositorio: repo))),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No se presentan (1)'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('el filtro "No se presentan" muestra a quien faltó a todo y lo cancela sin reembolso', (tester) async {
      final repo = await abrirConAusente(tester);
      expect(find.text('Fútbol (FUT-01)'), findsOneWidget);
      expect(find.text('Tenis (TEN-01)'), findsNothing);
      expect(find.text('No se presenta'), findsOneWidget);
      expect(find.text('Asistencia: 0 de 3 sesiones'), findsOneWidget);

      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      final cancelar = find.widgetWithText(FilledButton, 'Cancelar reserva');
      expect(cancelar, findsOneWidget);
      expect(find.text('Marcar el pago de \$5.00 como reembolsado'), findsOneWidget);
      await tester.tap(cancelar);
      await tester.pumpAndSettle();
      expect(repo.canceladas['FUT-01_b'], ('No se presentó a los entrenamientos.', false),
          reason: 'el motivo sugerido es la ausencia');
      expect(find.text('Reserva cancelada; el cupo quedó libre.'), findsOneWidget);
    });

    testWidgets('con "Otro" hay que escribir el motivo, y se puede reembolsar', (tester) async {
      final repo = await abrirConAusente(tester);
      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otro'));
      await tester.pumpAndSettle();
      final cancelar = find.widgetWithText(FilledButton, 'Cancelar reserva');
      expect(tester.widget<FilledButton>(cancelar).onPressed, isNull, reason: 'sin motivo no se puede');
      await tester.enterText(find.byType(TextField).last, 'Cambio de horario de clases');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(cancelar);
      await tester.pumpAndSettle();
      expect(repo.canceladas['FUT-01_b'], ('Cambio de horario de clases', true));
    });

    testWidgets('cambia la reserva a otra disciplina; las que no se pueden salen con el motivo', (tester) async {
      final repo = await abrirConAusente(tester);
      await tester.tap(find.text('Cambiar disciplina'));
      await tester.pumpAndSettle();
      expect(find.text('Natación no tiene cupos disponibles.'), findsOneWidget);
      expect(find.text('Ajedrez está dada de baja.'), findsOneWidget);
      expect(find.text('8 de 12 cupos libres'), findsOneWidget);
      await tester.tap(find.text('Natación (NAT-01)'));
      await tester.pumpAndSettle();
      expect(find.text('Elige una disciplina'), findsOneWidget, reason: 'Natación está deshabilitada');
      await tester.tap(find.text('Voleibol (VOL-01)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar a Voleibol'));
      await tester.pumpAndSettle();
      expect(repo.cambios, {'FUT-01_b': 'VOL-01'});
      expect(find.text('Reserva cambiada a Voleibol. Se le avisó al estudiante.'), findsOneWidget);
    });

    testWidgets('las reservas que ya terminaron no tienen botones', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _AdminFalso([reserva('AJE-01', 'zz', EstadoInscripcion.cancelada, nombre: 'Ajedrez')]);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReservasTab(repositorio: repo))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar reserva'), findsNothing);
      expect(find.text('Cambiar disciplina'), findsNothing);
      expect(find.text('Usuario eliminado del sistema'), findsOneWidget, reason: 'antes salía el id interno');
    });
  });
}
