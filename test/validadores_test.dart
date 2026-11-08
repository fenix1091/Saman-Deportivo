import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/validadores.dart';

void main() {
  group('Validadores', () {
    test('el registro solo acepta el correo institucional de estudiante', () {
      expect(Validadores.correoEstudiante('vgallo@correo.unimet.edu.ve'), isNull);
      expect(Validadores.correoEstudiante('vgallo@gmail.com'), isNotNull);
      expect(Validadores.correoEstudiante('vgallo@unimet.edu.ve'), isNull);
      expect(Validadores.correoEstudiante('vgallo@unimet.com'), isNotNull);
      expect(Validadores.correoEstudiante('no-es-correo'), isNotNull);
    });

    test('la cédula es solo el número (acepta puntos) y se guarda como entero', () {
      expect(Validadores.cedula('31985476'), isNull);
      expect(Validadores.cedula('31.985.476'), isNull);
      expect(Validadores.cedula('V-31985476'), isNotNull);
      expect(Validadores.cedula('12345'), isNotNull);
      expect(Validadores.cedula(''), isNotNull);
      expect(Validadores.numeroCedula('31.985.476'), 31985476);
    });

    test('el carnet tiene 11 dígitos', () {
      expect(Validadores.carnet('20221110045'), isNull);
      expect(Validadores.carnet(''), isNull, reason: 'el carnet es opcional');
      expect(Validadores.carnet('2022111004'), isNotNull);
      expect(Validadores.carnet('2022-111-0045'), isNotNull);
    });

    test('la contraseña pide 8 caracteres, una letra y un número', () {
      expect(Validadores.clave('Saman2026'), isNull);
      expect(Validadores.clave('corta1'), isNotNull);
      expect(Validadores.clave('soloLetras'), isNotNull);
      expect(Validadores.clave('12345678'), isNotNull);
    });

    test('nombre y apellido van por separado, solo con letras', () {
      expect(Validadores.nombre('Vincenzo'), isNull);
      expect(Validadores.nombre('María José'), isNull);
      expect(Validadores.apellido("D'Angelo"), isNull);
      expect(Validadores.nombre(''), isNotNull);
      expect(Validadores.apellido('Gallo-2'), isNotNull);
      expect(Validadores.apellido('Gallo-Pérez'), isNotNull);
      expect(Validadores.nombre('x' * 41), isNotNull);
      expect(Validadores.normalizarNombre('  maría   JOSÉ '), 'María José');
    });
  });
}
