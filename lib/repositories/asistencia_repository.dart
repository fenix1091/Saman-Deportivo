import 'package:cloud_firestore/cloud_firestore.dart';

class AsistenciaRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// RF-14: Obtener estudiantes inscritos en una disciplina
  Stream<List<Map<String, dynamic>>> obtenerEstudiantesInscritos(
      String deporteId) {
    return _db
        .collection('usuarios')
        .where('rol', isEqualTo: 'estudiante')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// RF-15: Registrar asistencia por lote
  Future<void> registrarAsistencia({
    required String deporteId,
    required DateTime fecha,
    required Map<String, bool> asistenciaMap,
  }) async {
    final fechaIso =
        "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
    final batch = _db.batch();

    asistenciaMap.forEach((estudianteUid, presente) {
      final docRef = _db
          .collection('asistencias')
          .doc('${deporteId}_${estudianteUid}_$fechaIso');

      batch.set(
        docRef,
        {
          'deporteId': deporteId,
          'estudianteUid': estudianteUid,
          'fecha': Timestamp.fromDate(fecha),
          'presente': presente,
        },
        SetOptions(merge: true),
      );
    });

    await batch.commit();
  }

  /// RF-16: Obtener porcentajes de asistencia por alumno
  Stream<Map<String, double>> obtenerPorcentajesAsistencia(String deporteId) {
    return _db
        .collection('asistencias')
        .where('deporteId', isEqualTo: deporteId)
        .snapshots()
        .map((snapshot) {
      final Map<String, int> totalSesiones = {};
      final Map<String, int> totalAsistidas = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final uid = data['estudianteUid'] as String;
        final presente = data['presente'] as bool? ?? false;

        totalSesiones[uid] = (totalSesiones[uid] ?? 0) + 1;
        if (presente) {
          totalAsistidas[uid] = (totalAsistidas[uid] ?? 0) + 1;
        }
      }

      final Map<String, double> porcentajes = {};
      totalSesiones.forEach((uid, total) {
        final asistidas = totalAsistidas[uid] ?? 0;
        porcentajes[uid] =
            double.parse(((asistidas / total) * 100).toStringAsFixed(1));
      });

      return porcentajes;
    });
  }
}
