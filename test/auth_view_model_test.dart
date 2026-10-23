import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/auth_repository.dart';
import 'package:saman_deportivo/repositories/auth_repository_local.dart';
import 'package:saman_deportivo/viewmodels/auth_view_model.dart';

void main() {
  late AuthRepositoryLocal repositorio;
  late AuthViewModel vm;

  setUp(() {
    repositorio = AuthRepositoryLocal.conDatosDePrueba(latencia: Duration.zero);
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
}
