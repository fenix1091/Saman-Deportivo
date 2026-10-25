import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'falsos/auth_repository_falso.dart';
import 'package:saman_deportivo/viewmodels/perfil_view_model.dart';

void main() {
  late AuthRepositoryFalso repositorio;
  late PerfilViewModel vm;

  setUp(() async {
    repositorio = AuthRepositoryFalso.conDatosDePrueba(latencia: Duration.zero);
    await repositorio.iniciarSesion('estudiante@correo.unimet.edu.ve', 'Estudiante123');
    vm = PerfilViewModel(repositorio);
  });

  group('Perfil (CU-03)', () {
    test('guarda el teléfono sin tocar los datos no editables', () async {
      expect(await vm.guardar(telefono: '0414-123 4567'), isTrue);
      final usuario = repositorio.usuarioActual as Estudiante;
      expect(usuario.telefono, '04141234567');
      expect(usuario.carnet, '20231110001');
      expect(usuario.cedula, 'V-30111222');
    });

    test('sube la foto nueva al guardar', () async {
      expect(vm.elegirFoto(Uint8List.fromList([1, 2, 3]), 'yo.PNG'), isTrue);
      expect(await vm.guardar(telefono: ''), isTrue);
      expect(repositorio.usuarioActual!.fotoUrl, startsWith('data:image/png;base64,'));
      expect(vm.fotoNueva, isNull);
    });

    test('rechaza una foto demasiado pesada y conserva la anterior', () {
      final grande = Uint8List(PerfilViewModel.tamanoMaximoFoto + 1);
      expect(vm.elegirFoto(grande, 'foto.jpg'), isFalse);
      expect(vm.error, contains('pesada'));
      expect(vm.fotoNueva, isNull);
    });

    test('rechaza un formato no permitido', () {
      expect(vm.elegirFoto(Uint8List(10), 'foto.gif'), isFalse);
      expect(vm.error, isNotNull);
    });
  });

  test('cada rol se guarda y se lee igual desde Firestore', () {
    final usuarios = <Persona>[
      const Estudiante(
          uid: 'a', cedula: 'V-1', nombre: 'A B', correo: 'a@correo.unimet.edu.ve', carnet: '1', solvente: false),
      const Entrenador(
          uid: 'b',
          cedula: 'V-2',
          nombre: 'C D',
          correo: 'b@unimet.edu.ve',
          especialidad: 'Tenis',
          aniosExperiencia: 3),
      const Administrador(uid: 'c', cedula: 'V-3', nombre: 'E F', correo: 'c@unimet.edu.ve', cargo: 'Coordinador'),
    ];
    for (final u in usuarios) {
      final copia = Persona.desdeMapa(u.uid, u.aMapa());
      expect(copia.runtimeType, u.runtimeType);
      expect(copia.aMapa(), u.aMapa());
    }
  });
}
