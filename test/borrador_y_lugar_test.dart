import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/validacion_admin.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/viewmodels/catalogo_view_model.dart';

import 'falsos/deporte_repository_falso.dart';

Future<void> esperar() => Future<void>.delayed(Duration.zero);

void main() {
  const martes = Horario(id: 'h1', dia: DiaSemana.martes, horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha 1');

  group('RN-07: una disciplina sin entrenador u horarios queda como borrador', () {
    const conTodo = Deporte(codigo: 'FUT-01', nombre: 'Fútbol', cupoMaximo: 20, entrenadorId: 'e1');
    const sinEntrenador = Deporte(codigo: 'VOL-01', nombre: 'Voleibol', cupoMaximo: 20);
    const sinHorarios = Deporte(codigo: 'TEN-01', nombre: 'Tenis', cupoMaximo: 8, entrenadorId: 'e1');

    test('dice qué le falta para publicarse', () {
      expect(conTodo.esBorrador(const [martes]), isFalse);
      expect(sinEntrenador.esBorrador(const [martes]), isTrue);
      expect(sinHorarios.esBorrador(const []), isTrue);
      expect(sinEntrenador.faltaParaPublicar(const []), 'Falta entrenador y horarios');
      expect(sinHorarios.faltaParaPublicar(const []), 'Falta horarios');
    });

    test('el catálogo público no muestra los borradores', () async {
      final repo = DeporteRepositoryFalso(
        deportes: const [conTodo, sinEntrenador, sinHorarios],
        horarios: const {
          'FUT-01': [martes],
          'VOL-01': [martes],
        },
      );
      final vm = CatalogoViewModel(repo);
      addTearDown(vm.dispose);
      await esperar();
      await esperar();
      expect([for (final d in vm.resultados) d.codigo], ['FUT-01']);
    });
  });

  group('RF-19: un lugar no se usa a la misma hora por dos clases', () {
    const futbol = Deporte(codigo: 'FUT-01', nombre: 'Fútbol', cupoMaximo: 20);
    const rugby = Deporte(codigo: 'RUG-01', nombre: 'Rugby', cupoMaximo: 20);
    const viejo = Deporte(codigo: 'VIE-01', nombre: 'Viejo', cupoMaximo: 20, activo: false);
    final ocupados = {
      futbol: const [martes],
      rugby: const [
        Horario(id: 'r1', dia: DiaSemana.martes, horaInicio: '17:00', horaFin: '19:00', lugar: 'cancha 1 ')
      ],
      viejo: const [Horario(id: 'v1', dia: DiaSemana.lunes, horaInicio: '08:00', horaFin: '10:00', lugar: 'Gimnasio')],
    };

    test('avisa si se cruza con otra disciplina en el mismo lugar', () {
      const nuevo = Horario(id: '', dia: DiaSemana.martes, horaInicio: '18:00', horaFin: '19:30', lugar: 'Cancha 1');
      expect(ValidacionAdmin.cruceDeLugar('BAS-01', nuevo, ocupados), contains('Rugby (RUG-01)'));
    });

    test('avisa si se cruza con otro horario de la misma clase', () {
      const nuevo = Horario(id: '', dia: DiaSemana.martes, horaInicio: '15:00', horaFin: '16:30', lugar: 'Cancha 1');
      expect(
          ValidacionAdmin.cruceDeLugar('FUT-01', nuevo, {
            futbol: const [martes]
          }),
          contains('de esta clase'));
    });

    test('deja guardar en otro lugar, otro día, al editar el mismo horario o junto a una clase inactiva', () {
      const otroLugar =
          Horario(id: '', dia: DiaSemana.martes, horaInicio: '16:00', horaFin: '18:00', lugar: 'Gimnasio');
      const otroDia =
          Horario(id: '', dia: DiaSemana.miercoles, horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha 1');
      const mismo = Horario(id: 'h1', dia: DiaSemana.martes, horaInicio: '16:00', horaFin: '17:00', lugar: 'Cancha 1');
      const junto = Horario(id: '', dia: DiaSemana.lunes, horaInicio: '09:00', horaFin: '10:00', lugar: 'Gimnasio');
      expect(ValidacionAdmin.cruceDeLugar('BAS-01', otroLugar, ocupados), isNull);
      expect(ValidacionAdmin.cruceDeLugar('BAS-01', otroDia, ocupados), isNull);
      expect(
          ValidacionAdmin.cruceDeLugar('FUT-01', mismo, {
            futbol: const [martes]
          }),
          isNull);
      expect(ValidacionAdmin.cruceDeLugar('BAS-01', junto, ocupados), isNull);
    });
  });
}
