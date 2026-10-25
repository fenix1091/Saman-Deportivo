import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/auth_repository.dart';
import 'falsos/auth_repository_falso.dart';
import 'package:saman_deportivo/viewmodels/auth_view_model.dart';

void main() {
  late AuthRepositoryFalso repositorio;
  late AuthViewModel vm;

  setUp(() {
    repositorio = AuthRepositoryFalso.conDatosDePrueba(latencia: Duration.zero);
    vm = AuthViewModel(repositorio);
  });

  tearDown(() => vm.dispose());

  group('Registro (CU-01)', () {
    Future<bool> registrar({String correo = 'nuevo@correo.unimet.edu.ve', String carnet = '20241110099'}) {
      return vm.registrar(
        cedula: 'v-31.985.476',
        nombre: 'Vincenzo Gallo',
        correo: correo,
        carnet: carnet,
        clave: 'Saman2026',
      );
    }

    test('crea un estudiante y abre su sesión', () async {
      expect(await registrar(), isTrue);
      await Future<void>.delayed(Duration.zero);
      final usuario = vm.usuario;
      expect(usuario, isA<Estudiante>());
      expect(usuario!.cedula, 'V-31985476');
      expect((usuario as Estudiante).estaActivo(), isTrue);
    });

    test('rechaza un correo ya registrado', () async {
      expect(await registrar(correo: 'estudiante@correo.unimet.edu.ve'), isFalse);
      expect(vm.error, ErrorAuth.correoYaRegistrado);
      expect(vm.error!.esCuentaExistente, isTrue);
    });

    test('rechaza un carnet ya registrado', () async {
      expect(await registrar(carnet: '20231110001'), isFalse);
      expect(vm.error, ErrorAuth.carnetYaRegistrado);
    });
  });

  group('Inicio de sesión (CU-02)', () {
    test('reconoce el rol de cada usuario y su pantalla de inicio', () async {
      const casos = {
        'estudiante@correo.unimet.edu.ve': ('Estudiante123', Rol.estudiante, '/catalogo'),
        'entrenador@unimet.edu.ve': ('Entrenador123', Rol.entrenador, '/entrenador/mis-deportes'),
        'admin@unimet.edu.ve': ('Admin1234', Rol.administrador, '/admin/dashboard'),
      };
      for (final MapEntry(key: correo, value: (clave, rol, ruta)) in casos.entries) {
        expect(await vm.iniciarSesion(correo, clave), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(vm.usuario!.rol, rol);
        expect(AuthViewModel.rutaInicio(rol), ruta);
        await vm.cerrarSesion();
        await Future<void>.delayed(Duration.zero);
        expect(vm.haySesion, isFalse);
      }
    });

    test('no distingue mayúsculas en el correo', () async {
      expect(await vm.iniciarSesion(' Admin@UNIMET.edu.ve ', 'Admin1234'), isTrue);
    });

    test('rechaza una contraseña incorrecta', () async {
      expect(await vm.iniciarSesion('admin@unimet.edu.ve', 'otraClave1'), isFalse);
      expect(vm.error, ErrorAuth.credencialesInvalidas);
      expect(vm.haySesion, isFalse);
    });

    test('bloquea la cuenta tras 5 intentos fallidos', () async {
      for (var i = 0; i < AuthRepositoryFalso.maxIntentos; i++) {
        await vm.iniciarSesion('admin@unimet.edu.ve', 'malaClave$i');
      }
      expect(await vm.iniciarSesion('admin@unimet.edu.ve', 'Admin1234'), isFalse);
      expect(vm.error, ErrorAuth.demasiadosIntentos);
    });

    test('la recuperación de contraseña no revela si el correo existe', () async {
      expect(await vm.recuperarClave('no-existe@correo.unimet.edu.ve'), isTrue);
      expect(vm.error, isNull);
    });
  });
}
