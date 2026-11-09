import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/main.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/admin_repository_firebase.dart';
import 'falsos/asistencia_repository_falso.dart';
import 'falsos/auth_repository_falso.dart';
import 'falsos/deporte_repository_falso.dart';

class _AdminRepositoryFalso implements AdminRepository {
  @override
  Future<void> asignarEntrenador(String codigo, String entrenadorId) async {}

  @override
  Future<void> actualizarActivoDeporte(String codigo, bool activo) async {}

  @override
  Future<void> eliminarHorario(String codigo, String horarioId) async {}

  @override
  Future<void> guardarDeporte(Deporte deporte, {bool nueva = false}) async {}

  @override
  Future<void> guardarHorario(String codigo, Horario horario) async {}

  @override
  Stream<List<Deporte>> observarDeportes() => Stream.value(const []);

  @override
  Stream<List<Entrenador>> observarEntrenadores() => Stream.value(const []);

  @override
  Stream<List<Horario>> observarHorarios(String codigo) =>
      Stream.value(const []);

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
  }) async {}

  @override
  Future<void> reenviarEnlace(String correo) async {}

  @override
  Stream<List<Inscripcion>> observarInscripciones() => Stream.value(const []);

  @override
  Future<void> confirmarReserva(String id) async {}

  @override
  Future<void> rechazarReserva(String id, String motivo) async {}

  @override
  Future<void> eliminarDeporte(String codigo) async {}

  @override
  Future<void> inscribirEstudiante(String codigo, String estudianteUid) async {}

  @override
  Future<void> retirarEstudiante(String inscripcionId) async {}

  @override
  Future<void> eliminarUsuario(String uid) async {}

  @override
  Stream<List<Persona>> observarUsuarios() => Stream.value(const []);

  @override
  Future<void> actualizarUsuario(String uid, Map<String, dynamic> cambios) async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> abrirLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final deportes = DeporteRepositoryFalso.conDatosDePrueba();
    await tester.pumpWidget(
      SamanDeportivoApp(
        repositorio:
            AuthRepositoryFalso.conDatosDePrueba(latencia: Duration.zero),
        deportes: deportes,
        adminRepository: _AdminRepositoryFalso(),
        asistenciaRepository: AsistenciaRepositoryFalso(deportes),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
  }

  testWidgets('el administrador entra y llega a su panel', (tester) async {
    await abrirLogin(tester);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'), 'admin@unimet.edu.ve');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'Admin1234');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Administración deportiva'), findsOneWidget);
    expect(find.text('Clases y horarios'), findsOneWidget);
    expect(find.text('Entrenadores'), findsOneWidget);
  });

  testWidgets('el entrenador ve sus datos en el perfil y cambia su teléfono',
      (tester) async {
    await abrirLogin(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'),
        'entrenador@unimet.edu.ve');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'Entrenador123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Fútbol'), findsOneWidget);
    expect(find.text('V-20333444'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Teléfono'), '0412-555');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('celular válido'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Teléfono'), '0412-5550000');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil actualizado'), findsOneWidget);
  });

  testWidgets('una contraseña incorrecta muestra el error y no entra',
      (tester) async {
    await abrirLogin(tester);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'), 'admin@unimet.edu.ve');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), 'Incorrecta1');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Correo o contraseña inválidos.'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsOneWidget);
  });
}
