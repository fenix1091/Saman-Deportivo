import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/validacion_admin.dart';
import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/persona.dart';

void main() {
  const futbol = Deporte(codigo: 'FUT-01', nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 20, entrenadorId: 'ent-1');
  const ana =
      Estudiante(uid: 'a', cedula: 1, nombre: 'Ana', apellido: 'Pérez', correo: 'a@x', carnet: '1', solvente: true, correoVerificado: true);
  const carlos =
      Entrenador(uid: 'ent-1', cedula: 2, nombre: 'Carlos', apellido: 'Mora', correo: 'c@x', especialidad: 'Fútbol');
  const admin = Administrador(uid: 'adm', cedula: 3, nombre: 'Coordinación', correo: 'adm@x');

  Inscripcion ins(String uid, String codigo, EstadoInscripcion estado) => Inscripcion(
        id: Inscripcion.idPara(codigo, uid),
        estudianteId: uid,
        deporteCodigo: codigo,
        fechaInscripcion: DateTime.now(),
        estado: estado,
        nombreDeporte: 'Fútbol',
      );

  group('Eliminar una disciplina (punto 6 y 8)', () {
    test('se puede si no tiene inscripciones vigentes, aunque tenga historial', () {
      expect(ValidacionAdmin.eliminarDeporte(futbol, const []), isNull);
      expect(
        ValidacionAdmin.eliminarDeporte(futbol, [
          ins('a', 'FUT-01', EstadoInscripcion.cancelada),
          ins('b', 'FUT-01', EstadoInscripcion.rechazada),
          ins('c', 'FUT-01', EstadoInscripcion.expirada),
          ins('a', 'BAS-01', EstadoInscripcion.confirmada),
        ]),
        isNull,
      );
    });

    test('no se puede con inscripciones confirmadas, en revisión o pendientes, y dice cuántas', () {
      final motivo = ValidacionAdmin.eliminarDeporte(futbol, [
        ins('a', 'FUT-01', EstadoInscripcion.confirmada),
        ins('b', 'FUT-01', EstadoInscripcion.enRevision),
        ins('c', 'FUT-01', EstadoInscripcion.pendientePago),
      ]);
      expect(motivo, contains('3 inscripciones vigentes'));
      expect(motivo, contains('da de baja'));
    });
  });

  group('Eliminar un usuario (punto 8)', () {
    test('un estudiante sin inscripciones vigentes se puede eliminar', () {
      expect(
          ValidacionAdmin.eliminarUsuario(ana,
              adminUid: 'adm', inscripciones: [ins('a', 'FUT-01', EstadoInscripcion.cancelada)]),
          isNull);
    });

    test('un estudiante con una inscripción vigente no, y el motivo nombra la disciplina', () {
      final motivo = ValidacionAdmin.eliminarUsuario(ana,
          adminUid: 'adm', inscripciones: [ins('a', 'FUT-01', EstadoInscripcion.confirmada)]);
      expect(motivo, contains('1 inscripción vigente'));
      expect(motivo, contains('Fútbol'));
    });

    test('un entrenador con disciplinas asignadas no; sin ellas sí', () {
      expect(ValidacionAdmin.eliminarUsuario(carlos, adminUid: 'adm', deportes: [futbol]),
          contains('entrenador de Fútbol'));
      expect(ValidacionAdmin.eliminarUsuario(carlos, adminUid: 'adm', deportes: const []), isNull);
    });

    test('el administrador no se elimina a sí mismo ni a otros administradores desde el panel', () {
      expect(ValidacionAdmin.eliminarUsuario(admin, adminUid: 'adm'), contains('tu propia cuenta'));
      expect(ValidacionAdmin.eliminarUsuario(admin, adminUid: 'otro'), contains('no se eliminan'));
    });
  });

  group('Inscribir directamente a un estudiante (punto 7)', () {
    test('procede con estudiante activo y solvente, deporte con cupo y entrenador, sin inscripción previa vigente', () {
      expect(ValidacionAdmin.inscribirDirecto(ana, futbol, [ins('a', 'FUT-01', EstadoInscripcion.cancelada)]), isNull);
    });

    test('se niega y explica por qué en cada caso', () {
      const noSolvente = Estudiante(uid: 'b', cedula: 4, nombre: 'Luis', correo: 'l@x', carnet: '2');
      const inactivo = Estudiante(
          uid: 'c',
          cedula: 5,
          nombre: 'Marta',
          correo: 'm@x',
          carnet: '3',
          solvente: true, correoVerificado: true,
          estado: EstadoEstudiante.inactivo);
      expect(ValidacionAdmin.inscribirDirecto(noSolvente, futbol, const []), contains('no está solvente'));
      expect(ValidacionAdmin.inscribirDirecto(inactivo, futbol, const []), contains('inactivo'));
      expect(
          ValidacionAdmin.inscribirDirecto(
              ana,
              const Deporte(codigo: 'X', nombre: 'Lleno', cupoMaximo: 1, cuposOcupados: 1, entrenadorId: 'e'),
              const []),
          contains('no tiene cupos'));
      expect(ValidacionAdmin.inscribirDirecto(ana, const Deporte(codigo: 'Y', nombre: 'Solo', cupoMaximo: 5), const []),
          contains('entrenador'));
      expect(
          ValidacionAdmin.inscribirDirecto(ana,
              const Deporte(codigo: 'Z', nombre: 'Baja', cupoMaximo: 5, entrenadorId: 'e', activo: false), const []),
          contains('dada de baja'));
      expect(ValidacionAdmin.inscribirDirecto(ana, futbol, [ins('a', 'FUT-01', EstadoInscripcion.enRevision)]),
          contains('ya tiene una inscripción vigente'));
    });
  });
}
