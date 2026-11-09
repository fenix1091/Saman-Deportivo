import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/main.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/admin_repository_firebase.dart';
import 'package:saman_deportivo/views/admin/resumen_tab.dart';
import 'package:saman_deportivo/widgets/grafico_barras.dart';

import 'falsos/auth_repository_falso.dart';
import 'falsos/notificacion_repository_falso.dart';
import 'falsos/deporte_repository_falso.dart';
import 'falsos/inscripcion_repository_falso.dart';

class _AdminFalso implements AdminRepository {
  @override
  Stream<List<Deporte>> observarDeportes() => Stream.value(const [
        Deporte(
            codigo: 'FUT-01', nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 20, vecesBuscado: 41, entrenadorId: 'e'),
        Deporte(
            codigo: 'BAS-01',
            nombre: 'Baloncesto',
            cupoMaximo: 15,
            cuposOcupados: 15,
            vecesBuscado: 12,
            entrenadorId: 'e'),
        Deporte(codigo: 'NAT-01', nombre: 'Natación', cupoMaximo: 10, cuposOcupados: 2, vecesBuscado: 3, activo: false),
      ]);

  @override
  Stream<List<Inscripcion>> observarInscripciones() => Stream.value([
        Inscripcion(
            id: 'FUT-01_a',
            estudianteId: 'a',
            deporteCodigo: 'FUT-01',
            fechaInscripcion: DateTime(2026, 11, 1),
            estado: EstadoInscripcion.confirmada,
            monto: 5,
            sesiones: 4,
            sesionesAsistidas: 3),
        Inscripcion(
            id: 'FUT-01_b',
            estudianteId: 'b',
            deporteCodigo: 'FUT-01',
            fechaInscripcion: DateTime(2026, 11, 2),
            estado: EstadoInscripcion.enRevision,
            monto: 5),
        Inscripcion(
            id: 'BAS-01_a',
            estudianteId: 'a',
            deporteCodigo: 'BAS-01',
            fechaInscripcion: DateTime(2026, 11, 3),
            estado: EstadoInscripcion.cancelada,
            monto: 5),
      ]);

  @override
  Stream<List<Persona>> observarUsuarios() => Stream.value(const [
        Estudiante(uid: 'a', cedula: 1, nombre: 'Ana', correo: 'a@x', carnet: '1', solvente: true),
        Estudiante(uid: 'b', cedula: 2, nombre: 'Luis', correo: 'b@x', carnet: '2'),
        Entrenador(uid: 'e', cedula: 3, nombre: 'Carlos', correo: 'c@x', especialidad: 'Fútbol'),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Resumen del administrador (RF-21)', () {
    testWidgets('muestra cifras reales y los gráficos de más buscados, ocupación y estados', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: ResumenTab(repositorio: _AdminFalso()))),
      ));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsWidgets, reason: 'disciplinas activas (Natación está inactiva)');
      expect(find.text('disciplinas activas'), findsOneWidget);
      expect(find.text('1'), findsWidgets, reason: 'una confirmada y una en revisión');
      expect(find.text('\$10'), findsOneWidget, reason: 'confirmada + en revisión pagadas');
      expect(find.text('75 %'), findsOneWidget, reason: '3 de 4 sesiones');
      expect(find.text('estudiantes · 1 sin solvencia'), findsOneWidget);
      expect(find.text('Deportes más buscados'), findsOneWidget);
      expect(find.text('Ocupación de cupos'), findsOneWidget);
      expect(find.text('Reservas por estado'), findsOneWidget);
      expect(find.byType(GraficoBarras), findsNWidgets(3));
      final masBuscados = tester.widget<GraficoBarras>(find.byType(GraficoBarras).first);
      expect(masBuscados.datos.first.etiqueta, 'Fútbol');
      expect(masBuscados.datos.first.detalle, '41 consultas');
    });

    testWidgets('sin datos el gráfico lo dice en vez de quedar en blanco', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: GraficoBarras(datos: []))));
      expect(find.text('Sin datos todavía.'), findsOneWidget);
    });
  });

  group('Inicio del estudiante', () {
    testWidgets('al entrar llega a su panel con sus reservas y accesos; desde ahí abre el catálogo', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final deportes = DeporteRepositoryFalso.conDatosDePrueba();
      final inscripciones = InscripcionRepositoryFalso(deportes)
        ..agregar(Inscripcion(
          id: 'FUT-01_est-demo',
          estudianteId: 'est-demo',
          deporteCodigo: 'FUT-01',
          fechaInscripcion: DateTime(2026, 11, 1),
          estado: EstadoInscripcion.confirmada,
          nombreDeporte: 'Fútbol',
          horarios: 'Martes 16:00 - 18:00 · Cancha 1',
          sesiones: 2,
          sesionesAsistidas: 2,
        ))
        ..agregar(Inscripcion(
          id: 'TEN-01_est-demo',
          estudianteId: 'est-demo',
          deporteCodigo: 'TEN-01',
          fechaInscripcion: DateTime.now(),
          estado: EstadoInscripcion.enRevision,
          nombreDeporte: 'Tenis',
        ));
      final auth = AuthRepositoryFalso.conDatosDePrueba();
      await tester.pumpWidget(SamanDeportivoApp(notificaciones: NotificacionRepositoryFalso(), repositorio: auth, deportes: deportes, inscripciones: inscripciones));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'estudiante@correo.unimet.edu.ve');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Estudiante123');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Mi panel'), findsOneWidget);
      expect(find.text('Estudiante Prueba'), findsAtLeastNWidgets(1));
      expect(find.text('confirmadas'), findsOneWidget);
      expect(find.text('Tu pago está en revisión. La Coordinación de Deportes confirmará tu cupo pronto.'),
          findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Mis entrenamientos'), findsOneWidget);
      expect(find.text('Asistencia 2 de 2 sesiones'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, 600));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explorar deportes'));
      await tester.pumpAndSettle();
      expect(find.text('Catálogo de deportes'), findsOneWidget);
    });
  });
}
