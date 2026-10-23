import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/validadores.dart';

void main() {
  group('Validadores', () {
    test('el registro solo acepta el correo institucional de estudiante', () {
      expect(Validadores.correoEstudiante('vgallo@correo.unimet.edu.ve'), isNull);
      expect(Validadores.correoEstudiante('vgallo@gmail.com'), isNotNull);
      expect(Validadores.correoEstudiante('vgallo@unimet.edu.ve'), isNotNull);
      expect(Validadores.correoEstudiante('no-es-correo'), isNotNull);
    });

    test('la cédula acepta puntos y minúsculas y se normaliza', () {
      expect(Validadores.cedula('V-31.985.476'), isNull);
      expect(Validadores.cedula('e 12345678'), isNull);
      expect(Validadores.cedula('31985476'), isNotNull);
      expect(Validadores.normalizarCedula('v31.985.476'), 'V-31985476');
    });

    test('el carnet tiene 11 dígitos', () {
      expect(Validadores.carnet('20221110045'), isNull);
      expect(Validadores.carnet('2022111004'), isNotNull);
      expect(Validadores.carnet('2022-111-0045'), isNotNull);
    });

    test('la contraseña pide 8 caracteres, una letra y un número', () {
      expect(Validadores.clave('Saman2026'), isNull);
      expect(Validadores.clave('corta1'), isNotNull);
      expect(Validadores.clave('soloLetras'), isNotNull);
      expect(Validadores.clave('12345678'), isNotNull);
    });

    test('el nombre pide nombre y apellido', () {
      expect(Validadores.nombre('Vincenzo Gallo'), isNull);
      expect(Validadores.nombre('Vincenzo'), isNotNull);
    });
  });
}
