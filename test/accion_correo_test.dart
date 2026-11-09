import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saman_deportivo/core/router.dart';
import 'package:saman_deportivo/main.dart';
import 'package:saman_deportivo/repositories/auth_repository.dart';
import 'package:saman_deportivo/viewmodels/accion_correo_view_model.dart';

import 'falsos/auth_repository_falso.dart';
import 'falsos/deporte_repository_falso.dart';
import 'falsos/notificacion_repository_falso.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rutaDeEnlaceDeCorreo', () {
    test('reconoce el enlace que manda Firebase y descarta el resto de parámetros', () {
      final ruta = rutaDeEnlaceDeCorreo(
          Uri.parse('https://saman-deportivo-7b59f.web.app/?mode=resetPassword&oobCode=abc123&apiKey=x&lang=es'));
      expect(ruta, '/accion?mode=resetPassword&oobCode=abc123');
    });

    test('una dirección normal no cambia la ruta inicial', () {
      expect(rutaDeEnlaceDeCorreo(Uri.parse('https://saman-deportivo-7b59f.web.app/')), isNull);
      expect(rutaDeEnlaceDeCorreo(Uri.parse('https://saman-deportivo-7b59f.web.app/?mode=resetPassword')), isNull);
    });
  });

  group('AccionCorreoViewModel', () {
    late AuthRepositoryFalso repo;

    setUp(() {
      repo = AuthRepositoryFalso.conDatosDePrueba();
      repo.enlaces['codigo-ok'] = 'estudiante@correo.unimet.edu.ve';
    });

    test('con un enlace vigente pide la contraseña y la cambia', () async {
      final vm = AccionCorreoViewModel(repo, modo: 'resetPassword', codigo: 'codigo-ok');
      await pumpEventQueue();
      expect(vm.estado, EstadoAccion.pidiendoClave);
      expect(vm.correo, 'estudiante@correo.unimet.edu.ve');

      expect(await vm.guardarClave('ClaveNueva123'), isTrue);
      expect(vm.estado, EstadoAccion.listo);
      await repo.iniciarSesion('estudiante@correo.unimet.edu.ve', 'ClaveNueva123');
      expect(repo.usuarioActual, isNotNull);
    });

    test('un enlace vencido, usado o incompleto se marca como inválido', () async {
      final vencido = AccionCorreoViewModel(repo, modo: 'resetPassword', codigo: 'no-existe');
      await pumpEventQueue();
      expect(vencido.estado, EstadoAccion.invalido);
      expect(vencido.error, ErrorAuth.enlaceInvalido.mensaje);

      final sinCodigo = AccionCorreoViewModel(repo, modo: 'resetPassword', codigo: null);
      expect(sinCodigo.estado, EstadoAccion.invalido);
      final otroModo = AccionCorreoViewModel(repo, modo: 'otraCosa', codigo: 'codigo-ok');
      expect(otroModo.estado, EstadoAccion.invalido);
    });

    test('el enlace de bienvenida verifica el correo', () async {
      final vm = AccionCorreoViewModel(repo, modo: 'verifyEmail', codigo: 'codigo-ok');
      await pumpEventQueue();
      expect(vm.estado, EstadoAccion.listo);
      expect(repo.verificados, contains('estudiante@correo.unimet.edu.ve'));
    });
  });

  testWidgets('al abrir el enlace del correo se crea la contraseña nueva sin salir de la app', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = AuthRepositoryFalso.conDatosDePrueba();
    repo.enlaces['codigo-ok'] = 'estudiante@correo.unimet.edu.ve';

    await tester.pumpWidget(SamanDeportivoApp(
      repositorio: repo,
      deportes: DeporteRepositoryFalso(),
      notificaciones: NotificacionRepositoryFalso(),
      rutaInicial: '/accion?mode=resetPassword&oobCode=codigo-ok',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Crea tu contraseña nueva'), findsOneWidget);
    expect(find.text('Cuenta: estudiante@correo.unimet.edu.ve'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña nueva'), 'corta');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();
    expect(find.text('La contraseña debe tener al menos 8 caracteres.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña nueva'), 'ClaveNueva123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Repite la contraseña'), 'ClaveNueva123');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();

    expect(find.text('Contraseña cambiada'), findsOneWidget);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Contraseña cambiada'), findsNothing);
  });
}
