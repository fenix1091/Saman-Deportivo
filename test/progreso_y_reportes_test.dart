import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/core/exportar/reportes.dart';
import 'package:saman_deportivo/core/exportar/reportes_saman.dart';
import 'package:saman_deportivo/core/progreso.dart';
import 'package:saman_deportivo/core/validacion_admin.dart';
import 'package:saman_deportivo/main.dart';
import 'package:saman_deportivo/models/asistencia.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/admin_repository_firebase.dart';
import 'package:saman_deportivo/repositories/asistencia_repository.dart';
import 'package:saman_deportivo/views/admin/admin_dashboard_view.dart';

import 'falsos/asistencia_repository_falso.dart';
import 'falsos/auth_repository_falso.dart';
import 'falsos/deporte_repository_falso.dart';
import 'falsos/inscripcion_repository_falso.dart';
import 'falsos/notificacion_repository_falso.dart';

Asistencia _a(String codigo, String uid, DateTime fecha, bool presente) => Asistencia(
      id: idAsistencia(codigo, uid, fecha),
      inscripcionId: '${codigo}_$uid',
      estudianteId: uid,
      deporteCodigo: codigo,
      fecha: fecha,
      estado: presente ? EstadoAsistencia.presente : EstadoAsistencia.ausente,
    );

class _AdminClasesFalso implements AdminRepository {
  final guardados = <Deporte>[];

  /// Código que el "servidor" rechaza como repetido aunque no esté en la lista.
  String? repetidoEnServidor;

  @override
  Stream<List<Entrenador>> observarEntrenadores() => Stream.value(const []);

  @override
  Stream<List<Deporte>> observarDeportes() =>
      Stream.value(const [Deporte(codigo: 'NAT-01', nombre: 'Natación', cupoMaximo: 12)]);

  @override
  Stream<List<Horario>> observarHorarios(String codigo) => Stream.value(const []);

  @override
  Stream<List<Inscripcion>> observarInscripciones() => Stream.value(const []);

  @override
  Stream<List<Persona>> observarUsuarios() => Stream.value(const []);

  @override
  Future<void> guardarDeporte(Deporte deporte, {bool nueva = false}) async {
    if (deporte.codigo == repetidoEnServidor) throw CodigoRepetidoException(deporte.codigo);
    guardados.add(deporte);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Mi progreso', () {
    test('sin asistencias empieza en Novato, sin racha ni insignias', () {
      final p = ProgresoEstudiante.calcular(const []);
      expect(p.sesiones, 0);
      expect(p.porcentaje, 0);
      expect(p.rachaActual, 0);
      expect(p.insigniasLogradas, 0);
      expect(p.nivel.nombre, 'Novato');
      expect(p.siguienteNivel!.nombre, 'Constante');
    });

    test('cuenta la racha actual, la mejor racha, el nivel y las insignias', () {
      // Fútbol: P P P A P P (martes y jueves); Tenis: P un sábado.
      final asistencias = [
        _a('FUT-01', 'e', DateTime(2026, 10, 6), true),
        _a('FUT-01', 'e', DateTime(2026, 10, 8), true),
        _a('FUT-01', 'e', DateTime(2026, 10, 13), true),
        _a('FUT-01', 'e', DateTime(2026, 10, 15), false),
        _a('FUT-01', 'e', DateTime(2026, 10, 20), true),
        _a('FUT-01', 'e', DateTime(2026, 10, 22), true),
        _a('TEN-01', 'e', DateTime(2026, 10, 24), true),
      ];
      final p = ProgresoEstudiante.calcular(asistencias, nombres: {'FUT-01': 'Fútbol'});
      expect(p.sesiones, 7);
      expect(p.presentes, 6);
      expect(p.rachaActual, 3, reason: 'los dos últimos de fútbol y el de tenis');
      expect(p.mejorRacha, 3);
      expect(p.nivel.nombre, 'Constante');
      expect(p.avanceNivel, closeTo(0.1, 0.001), reason: '1 de las 10 asistencias entre Constante y Atleta');
      final logradas = {for (final i in p.insignias.where((i) => i.lograda)) i.id};
      expect(logradas, {'primer-paso', 'en-racha', 'multideporte', 'fin-de-semana'});
      final perfecta = p.insignias.firstWhere((i) => i.id == 'perfecta');
      expect(perfecta.actual, 1, reason: 'solo Tenis va al 100 %, con 1 sesión');
      expect(p.porDisciplina.first.nombre, 'Fútbol');
      expect(p.porDisciplina.first.porcentaje.round(), 83);
      expect(p.porDisciplina.last.nombre, 'TEN-01', reason: 'sin nombre conocido usa el código');
      expect(p.recientes.first.deporteCodigo, 'TEN-01');
    });

    testWidgets('el estudiante abre Mi progreso desde el menú y ve su nivel, su racha y sus insignias',
        (tester) async {
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
          fechaInscripcion: DateTime(2026, 10, 1),
          estado: EstadoInscripcion.confirmada,
          nombreDeporte: 'Fútbol',
        ));
      final asistencia = AsistenciaRepositoryFalso(deportes);
      for (final (dia, presente) in [(6, true), (8, true), (13, true), (15, false), (20, true)]) {
        final a = _a('FUT-01', 'est-demo', DateTime(2026, 10, dia), presente);
        asistencia.asistencias[a.id] = a;
      }
      final otro = _a('FUT-01', 'otro', DateTime(2026, 10, 6), true);
      asistencia.asistencias[otro.id] = otro;

      await tester.pumpWidget(SamanDeportivoApp(
        notificaciones: NotificacionRepositoryFalso(),
        repositorio: AuthRepositoryFalso.conDatosDePrueba(),
        deportes: deportes,
        inscripciones: inscripciones,
        asistenciaRepository: asistencia,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'estudiante@correo.unimet.edu.ve');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Estudiante123');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Progreso'));
      await tester.pumpAndSettle();
      expect(find.text('Mi progreso'), findsWidgets);
      expect(find.text('80 %'), findsOneWidget, reason: '4 de 5 (la del otro estudiante no cuenta)');
      expect(find.text('Novato'), findsOneWidget);
      expect(find.text('Te falta 1 asistencia para Constante'), findsOneWidget);
      expect(find.text('Racha de 1'), findsOneWidget);
      expect(find.text('Mejor racha: 3'), findsOneWidget);
      expect(find.text('4 de 5 asistencias'), findsOneWidget);
      expect(find.text('2 DE 8 CONSEGUIDAS'), findsOneWidget, reason: 'Primer paso y En racha');
      expect(find.text('Guerrero de fin de semana'), findsOneWidget);
    });
  });

  group('Código de disciplina repetido', () {
    const existentes = [
      Deporte(codigo: 'NAT-01', nombre: 'Natación', cupoMaximo: 12),
      Deporte(codigo: 'BAS-01', nombre: 'Baloncesto', cupoMaximo: 15),
    ];

    test('no deja repetir un código aunque cambien mayúsculas, espacios o guiones', () {
      for (final c in ['NAT-01', 'nat-01', 'NAT01', ' nat 01 ']) {
        expect(ValidacionAdmin.codigoRepetido(c, existentes),
            'Ya existe una disciplina con ese código: Natación (NAT-01).', reason: c);
      }
      expect(ValidacionAdmin.codigoRepetido('NAT-02', existentes), isNull);
      expect(ValidacionAdmin.codigoRepetido('', existentes), isNull);
    });

    Future<_AdminClasesFalso> abrirNuevaClase(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _AdminClasesFalso();
      await tester.pumpWidget(SamanDeportivoApp(
        notificaciones: NotificacionRepositoryFalso(),
        repositorio: AuthRepositoryFalso.conDatosDePrueba(),
        deportes: DeporteRepositoryFalso.conDatosDePrueba(),
        adminRepository: repo,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'admin@unimet.edu.ve');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Admin1234');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      final contexto = tester.element(find.byType(AdminDashboardView));
      GoRouter.of(contexto).go('/admin/${SeccionAdmin.clases.name}');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva clase'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('el formulario avisa al escribir un código que ya existe y no guarda', (tester) async {
      final repo = await abrirNuevaClase(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Código único *'), 'nat-01');
      await tester.pumpAndSettle();
      expect(find.text('Ya existe una disciplina con ese código: Natación (NAT-01).'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre *'), 'Natación avanzada');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(repo.guardados, isEmpty);
      expect(find.text('Nueva clase'), findsNWidgets(2), reason: 'la ventana sigue abierta con lo escrito');

      await tester.enterText(find.widgetWithText(TextFormField, 'Código único *'), 'NAT-02');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(repo.guardados.single.codigo, 'NAT-02');
      expect(find.text('Guardar'), findsNothing, reason: 'se cerró al guardar');
    });

    testWidgets('si el servidor detecta el código repetido, la ventana no se cierra', (tester) async {
      final repo = await abrirNuevaClase(tester);
      repo.repetidoEnServidor = 'VOL-01';
      await tester.enterText(find.widgetWithText(TextFormField, 'Código único *'), 'VOL-01');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre *'), 'Voleibol');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Ya existe una disciplina con el código VOL-01. Usa otro código.'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Voleibol'), findsOneWidget, reason: 'no se pierde lo escrito');
    });
  });

  group('Exportar a PDF y Excel', () {
    const futbol = Deporte(codigo: 'FUT-01', nombre: 'Fútbol', categoria: 'Colectivo', cupoMaximo: 25, cuposOcupados: 2);
    const nomina = [
      EstudianteInscrito(uid: 'a', inscripcionId: 'FUT-01_a', nombreCompleto: 'Ana Pérez', cedulaTexto: 'V-28555123'),
      EstudianteInscrito(uid: 'b', inscripcionId: 'FUT-01_b', nombreCompleto: 'Luis Rojas'),
    ];
    final asistencias = [
      _a('FUT-01', 'a', DateTime(2026, 11, 3), true),
      _a('FUT-01', 'b', DateTime(2026, 11, 3), false),
      _a('FUT-01', 'a', DateTime(2026, 11, 5), true),
      _a('FUT-01', 'b', DateTime(2026, 11, 5), true),
    ];

    test('el reporte de asistencia trae inscritos, sesiones y el detalle por fecha', () {
      final r = ReportesSaman.asistenciaDisciplina(futbol, nomina, asistencias);
      expect(r.archivo, 'asistencia_FUT-01');
      expect(r.subtitulo, contains('2 inscritos · 2 sesiones · 75 % de asistencia'));
      expect(r.tablas.map((t) => t.titulo), ['Inscritos', 'Sesiones', 'Detalle por fecha']);
      expect(r.tablas[0].filas.first, [1, 'Ana Pérez', 'V-28555123', '', 2, 2, 100.0]);
      expect(r.tablas[0].filas.last, [2, 'Luis Rojas', '', '', 2, 1, 50.0]);
      expect(r.tablas[1].filas.first, ['05/11/2026', 2, 0, 2, 100.0], reason: 'la sesión más reciente primero');
      expect(r.tablas[2].filas.length, 4);
    });

    test('el reporte general resume disciplinas, reservas y estudiantes', () {
      final r = ReportesSaman.general(
        const [futbol],
        [
          Inscripcion(
              id: 'FUT-01_a',
              estudianteId: 'a',
              deporteCodigo: 'FUT-01',
              fechaInscripcion: DateTime(2026, 11, 1),
              estado: EstadoInscripcion.confirmada,
              monto: 5,
              sesiones: 4,
              sesionesAsistidas: 3),
        ],
        const [
          Estudiante(uid: 'a', cedula: 1, nombre: 'Ana', correo: 'a@x', carnet: '1', solvente: true),
          Estudiante(uid: 'b', cedula: 2, nombre: 'Luis', correo: 'b@x', carnet: '2'),
        ],
      );
      final resumen = {for (final f in r.tablas[0].filas) f[0]: f[1]};
      expect(resumen['Ingresos por reservas (USD)'], 5.0);
      expect(resumen['Asistencia promedio (%)'], 75.0);
      expect(resumen['Estudiantes no solventes'], 1);
      expect(r.tablas[1].filas.single[2], 'Sin asignar');
      expect(r.tablas[2].filas.length, 2);
    });

    test('genera un PDF y un Excel válidos, con una hoja por tabla', () async {
      final r = ReportesSaman.asistenciaDisciplina(futbol, nomina, asistencias, fecha: DateTime(2026, 11, 17, 9));
      final pdf = await GeneradorReportes.pdf(r);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');

      final libro = xl.Excel.decodeBytes(GeneradorReportes.excel(r));
      expect(libro.tables.keys.toSet(), {'Inscritos', 'Sesiones', 'Detalle por fecha'});
      final hoja = libro.tables['Inscritos']!;
      final valores = [for (final fila in hoja.rows) fila.map((c) => c?.value?.toString() ?? '').toList()];
      expect(valores.any((f) => f.contains('Ana Pérez') && f.contains('V-28555123')), isTrue);
      expect(valores.any((f) => f.contains('Estudiante') && f.contains('% asistencia')), isTrue);
    });

    test('el PDF no falla con signos que no caben en sus fuentes', () async {
      const r = Reporte(
        titulo: 'Prueba — “comillas” y emoji 🏆',
        subtitulo: 'Lunes 16:00 – 18:00',
        archivo: 'prueba',
        tablas: [TablaReporte(titulo: 'Tabla', columnas: ['A'], filas: [['Señal ✓']])],
      );
      expect((await GeneradorReportes.pdf(r)).isNotEmpty, isTrue);
    });
  });
}
