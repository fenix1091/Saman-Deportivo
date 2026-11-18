import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/validadores.dart';

void main() {
  group('sugerenciasCorreo', () {
    test('con solo el usuario propone los dos dominios de la UNIMET', () {
      expect(Validadores.sugerenciasCorreo('vgallo'), ['vgallo@correo.unimet.edu.ve', 'vgallo@unimet.edu.ve']);
      expect(Validadores.sugerenciasCorreo(' VGallo '), ['vgallo@correo.unimet.edu.ve', 'vgallo@unimet.edu.ve']);
    });

    test('al empezar el dominio deja solo los que coinciden', () {
      expect(Validadores.sugerenciasCorreo('vgallo@'), ['vgallo@correo.unimet.edu.ve', 'vgallo@unimet.edu.ve']);
      expect(Validadores.sugerenciasCorreo('vgallo@u'), ['vgallo@unimet.edu.ve']);
      expect(Validadores.sugerenciasCorreo('vgallo@corr'), ['vgallo@correo.unimet.edu.ve']);
    });

    test('no propone nada si está vacío, completo, con otro dominio o mal escrito', () {
      expect(Validadores.sugerenciasCorreo(''), isEmpty);
      expect(Validadores.sugerenciasCorreo('vgallo@unimet.edu.ve'), isEmpty);
      expect(Validadores.sugerenciasCorreo('vgallo@gmail.com'), isEmpty);
      expect(Validadores.sugerenciasCorreo('@unimet'), isEmpty);
      expect(Validadores.sugerenciasCorreo('v gallo'), isEmpty);
    });
  });

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

  group('Entrenador (lo registra el administrador)', () {
    test('el correo tiene que ser de la UNIMET', () {
      expect(Validadores.correoEntrenador('cmora@unimet.edu.ve'), isNull);
      expect(Validadores.correoEntrenador('cmora@correo.unimet.edu.ve'), isNull);
      expect(Validadores.correoEntrenador(' CMora@UNIMET.edu.ve '), isNull);
      expect(Validadores.correoEntrenador('arroba@correo.com'),
          'El entrenador debe tener correo de la UNIMET (@correo.unimet.edu.ve o @unimet.edu.ve).');
      expect(Validadores.correoEntrenador('carlos@gmail.com'), isNotNull);
      expect(Validadores.correoEntrenador('cmora@unimet.edu.ve.com'), isNotNull);
      expect(Validadores.correoEntrenador(''), 'Ingresa tu correo.');
    });

    test('la especialidad es un deporte escrito con letras, sin números', () {
      for (final v in ['Natación', 'Fútbol / Futsal', 'Voleibol de playa', 'Tenis, pádel', 'Artes marciales (Judo)']) {
        expect(Validadores.especialidad(v), isNull, reason: v);
      }
      expect(Validadores.especialidad('12345'),
          'La especialidad no lleva números: escribe el deporte, por ejemplo Natación.');
      expect(Validadores.especialidad('Fútbol 5'), isNotNull);
      expect(Validadores.especialidad('Natación!!'), 'Escribe la especialidad solo con letras, por ejemplo Fútbol / Futsal.');
      expect(Validadores.especialidad('ab'), 'La especialidad debe tener al menos 3 letras.');
      expect(Validadores.especialidad('   '), 'Ingresa la especialidad, por ejemplo Natación.');
      expect(Validadores.especialidad('a' * 61), isNotNull);
    });

    test('los años de experiencia van de 0 a 60', () {
      expect(Validadores.aniosExperiencia('0'), isNull);
      expect(Validadores.aniosExperiencia('12'), isNull);
      expect(Validadores.aniosExperiencia('-1'), isNotNull);
      expect(Validadores.aniosExperiencia('61'), 'Revisa los años de experiencia (máximo 60).');
      expect(Validadores.aniosExperiencia('diez'), isNotNull);
    });
  });
}
