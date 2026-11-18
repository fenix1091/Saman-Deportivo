import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/asistencia.dart';
import '../models/deporte.dart';
import '../models/inscripcion.dart';
import '../models/persona.dart';
import 'asistencia_repository.dart';

/// [AsistenciaRepository] sobre Cloud Firestore.
///
/// firestore.rules solo deja escribir asistencias al entrenador asignado a la
/// disciplina (y leerlas a él, al administrador y al propio estudiante).
class AsistenciaRepositoryFirebase implements AsistenciaRepository {
  AsistenciaRepositoryFirebase({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Perfiles ya leídos, para no volver a pedirlos en cada cambio de la nómina.
  final _perfiles = <String, Persona>{};

  @override
  Stream<List<Deporte>> deportesDe(String entrenadorId) => _db
      .collection('deportes')
      .where('entrenadorId', isEqualTo: entrenadorId)
      .snapshots()
      .map((consulta) => [for (final d in consulta.docs) Deporte.desdeMapa(d.id, d.data())]
        ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())))
      .handleError((Object e) => throw _traducir(e));

  @override
  Stream<List<EstudianteInscrito>> nomina(String codigo) => _db
          .collection('inscripciones')
          .where('deporteCodigo', isEqualTo: codigo)
          .where('estado', isEqualTo: EstadoInscripcion.confirmada.name)
          .snapshots()
          .asyncMap((consulta) async {
        final lista = <EstudianteInscrito>[];
        for (final doc in consulta.docs) {
          final inscripcion = Inscripcion.desdeMapa(doc.id, doc.data());
          final perfil = await _perfil(inscripcion.estudianteId);
          lista.add(EstudianteInscrito(
            uid: inscripcion.estudianteId,
            inscripcionId: inscripcion.id,
            nombreCompleto: perfil?.nombreCompleto ?? 'Estudiante',
            cedulaTexto: perfil?.cedulaTexto ?? '',
            carnet: perfil is Estudiante ? perfil.carnet : '',
            sesiones: inscripcion.sesiones,
            sesionesAsistidas: inscripcion.sesionesAsistidas,
          ));
        }
        lista.sort((a, b) => a.nombreCompleto.toLowerCase().compareTo(b.nombreCompleto.toLowerCase()));
        return lista;
      }).handleError((Object e) => throw _traducir(e));

  Future<Persona?> _perfil(String uid) async {
    final guardado = _perfiles[uid];
    if (guardado != null) return guardado;
    final doc = await _db.collection('usuarios').doc(uid).get();
    final datos = doc.data();
    if (datos == null) return null;
    return _perfiles[uid] = Persona.desdeMapa(uid, datos);
  }

  @override
  Stream<List<Asistencia>> asistenciasDe(String codigo) => _db
      .collection('asistencias')
      .where('deporteCodigo', isEqualTo: codigo)
      .snapshots()
      .map((consulta) => [for (final d in consulta.docs) Asistencia.desdeMapa(d.id, d.data())])
      .handleError((Object e) => throw _traducir(e));

  @override
  Future<void> registrarAsistencia({
    required String codigo,
    required DateTime fecha,
    required Map<String, bool> presentes,
  }) async {
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final asistencias = _db.collection('asistencias');
    final inscripciones = _db.collection('inscripciones');
    try {
      await _db.runTransaction((tx) async {
        // Primero todas las lecturas (lo exige Firestore), después las escrituras.
        final previas = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        final fichas = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final uid in presentes.keys) {
          previas[uid] = await tx.get(asistencias.doc(idAsistencia(codigo, uid, dia)));
          fichas[uid] = await tx.get(inscripciones.doc(Inscripcion.idPara(codigo, uid)));
        }
        for (final entrada in presentes.entries) {
          final uid = entrada.key;
          final presente = entrada.value;
          final previa = previas[uid]!;
          final estabaPresente = previa.data()?['estado'] == EstadoAsistencia.presente.name;
          final asistencia = Asistencia(
            id: idAsistencia(codigo, uid, dia),
            inscripcionId: Inscripcion.idPara(codigo, uid),
            estudianteId: uid,
            deporteCodigo: codigo,
            fecha: dia,
            estado: presente ? EstadoAsistencia.presente : EstadoAsistencia.ausente,
          );
          tx.set(asistencias.doc(asistencia.id), asistencia.aMapa());

          // Contadores de la inscripción: una sesión nueva suma 1; cambiar el estado
          // de una sesión ya registrada solo mueve las asistidas.
          final ficha = fichas[uid]!.data();
          if (ficha == null) continue;
          final sesiones = (ficha['sesiones'] as num?)?.toInt() ?? 0;
          final asistidas = (ficha['sesionesAsistidas'] as num?)?.toInt() ?? 0;
          final nuevaSesion = !previa.exists;
          final deltaAsistidas = (presente ? 1 : 0) - (estabaPresente ? 1 : 0);
          tx.update(inscripciones.doc(Inscripcion.idPara(codigo, uid)), {
            'sesiones': sesiones + (nuevaSesion ? 1 : 0),
            'sesionesAsistidas': (asistidas + deltaAsistidas).clamp(0, sesiones + 1),
          });
        }
      });
    } catch (e) {
      throw _traducir(e);
    }
  }

  AsistenciaException _traducir(Object e) {
    if (e is AsistenciaException) return e;
    if (e is FirebaseException) {
      return switch (e.code) {
        'permission-denied' => const AsistenciaException('Solo el entrenador asignado puede registrar la asistencia.'),
        'unavailable' => const AsistenciaException('No hay conexión. Revisa tu internet e inténtalo de nuevo.'),
        _ => AsistenciaException('No se pudo guardar la asistencia (${e.code}).'),
      };
    }
    return const AsistenciaException('Ocurrió un error inesperado. Inténtalo de nuevo.');
  }
}
