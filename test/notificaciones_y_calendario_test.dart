import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/notificacion.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/viewmodels/notificaciones_view_model.dart';
import 'package:saman_deportivo/widgets/calendario_semanal.dart';
import 'package:saman_deportivo/widgets/campana_notificaciones.dart';

import 'falsos/notificacion_repository_falso.dart';

Future<void> esperar() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Notificaciones dentro de la app (RF-22)', () {
    const ana = Estudiante(uid: 'a', cedula: 1, nombre: 'Ana', correo: 'a@x', carnet: '1');
    const admin = Administrador(uid: 'adm', cedula: 2, nombre: 'Coordinación', correo: 'c@x');

    Notificacion aviso(String id, {String paraUid = '', String paraRol = '', bool leida = false, int min = 0}) =>
        Notificacion(
          id: id,
          paraUid: paraUid,
          paraRol: paraRol,
          tipo: paraRol.isEmpty ? TipoNotificacion.reservaConfirmada : TipoNotificacion.reservaRecibida,
          titulo: 'Aviso $id',
          mensaje: 'Mensaje $id',
          fecha: DateTime(2026, 11, 8, 10, min),
          leida: leida,
        );

    test('cada persona ve los suyos y los de su rol, de más reciente a más antiguo; cuenta los no leídos', () async {
      final repo = NotificacionRepositoryFalso()
        ..agregar(aviso('1', paraUid: 'a'))
        ..agregar(aviso('2', paraUid: 'a', leida: true, min: 5))
        ..agregar(aviso('3', paraRol: 'administrador', min: 9))
        ..agregar(aviso('4', paraUid: 'otro'));
      final vm = NotificacionesViewModel(repo)..seguir(ana);
      await esperar();
      expect(vm.notificaciones.map((n) => n.id), ['2', '1']);
      expect(vm.noLeidas, 1);

      vm.seguir(admin);
      await esperar();
      expect(vm.notificaciones.map((n) => n.id), ['3']);

      await vm.marcarLeida(vm.notificaciones.first);
      await esperar();
      expect(vm.noLeidas, 0);

      vm.seguir(null);
      expect(vm.notificaciones, isEmpty);
      vm.dispose();
    });

    testWidgets('la campana muestra el contador y abre la lista; tocar un aviso lo marca leído', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = NotificacionRepositoryFalso()
        ..agregar(aviso('1', paraUid: 'a'))
        ..agregar(aviso('2', paraUid: 'a', min: 3));
      final vm = NotificacionesViewModel(repo)..seguir(ana);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: vm,
        child: const MaterialApp(
            home: Scaffold(
                appBar: PreferredSize(preferredSize: Size.fromHeight(56), child: SizedBox()),
                body: CampanaNotificaciones())),
      ));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget, reason: 'dos sin leer');

      await tester.tap(find.byType(CampanaNotificaciones));
      await tester.pumpAndSettle();
      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('Aviso 2'), findsOneWidget);
      await tester.tap(find.text('Aviso 2'));
      await tester.pumpAndSettle();
      expect(repo.guardadas['2']!.leida, isTrue);
      expect(find.text('1'), findsOneWidget, reason: 'queda uno sin leer');
      vm.dispose();
    });
  });

  group('Calendario semanal', () {
    const futbol = Deporte(codigo: 'FUT-01', nombre: 'Fútbol', categoria: 'Colectivo', cupoMaximo: 25);
    const natacion = Deporte(codigo: 'NAT-01', nombre: 'Natación', categoria: 'Acuático', cupoMaximo: 12);
    final bloques = [
      const BloqueSemana(
          deporte: futbol,
          horario: Horario(id: '1', dia: DiaSemana.martes, horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha 1')),
      const BloqueSemana(
          deporte: futbol,
          horario: Horario(id: '2', dia: DiaSemana.jueves, horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha 1')),
      const BloqueSemana(
          deporte: natacion,
          horario: Horario(id: '3', dia: DiaSemana.lunes, horaInicio: '07:00', horaFin: '08:00', lugar: 'Piscina')),
    ];

    test('calcula el próximo entrenamiento según el día y la hora actuales', () {
      // Domingo 8/11/2026 a las 15:00 → el lunes a las 7:00 (mañana).
      var p = CalendarioSemanal.proximo(bloques, DateTime(2026, 11, 8, 15))!;
      expect(p.$1.deporte.nombre, 'Natación');
      expect(p.$2, 1);
      expect(CalendarioSemanal.textoProximo(p), contains('mañana a las 07:00'));
      // Martes a las 17:00 ya empezó el fútbol → el jueves (en 2 días).
      p = CalendarioSemanal.proximo(bloques, DateTime(2026, 11, 10, 17))!;
      expect(p.$1.horario.dia, DiaSemana.jueves);
      expect(p.$2, 2);
      // Martes a las 15:00 → hoy.
      p = CalendarioSemanal.proximo(bloques, DateTime(2026, 11, 10, 15))!;
      expect(p.$2, 0);
      expect(CalendarioSemanal.textoProximo(p), contains('hoy'));
      expect(CalendarioSemanal.proximo(const [], DateTime.now()), isNull);
    });

    testWidgets('pinta los siete días con los bloques en su columna y resalta hoy', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(child: CalendarioSemanal(bloques: bloques, ahora: DateTime(2026, 11, 10, 9)))),
      ));
      await tester.pumpAndSettle();
      for (final d in ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']) {
        expect(find.text(d), findsOneWidget);
      }
      expect(find.text('Fútbol'), findsNWidgets(2));
      expect(find.text('Natación'), findsOneWidget);
      expect(find.text('Piscina'), findsOneWidget);
      expect(find.textContaining('Próximo entrenamiento: Fútbol hoy a las 16:00'), findsOneWidget);
    });
  });
}
