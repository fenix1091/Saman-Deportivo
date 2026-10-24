import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inscripcion.dart';

class InscripcionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _inscripciones =>
      _db.collection('inscripciones');

  /// 1. Consultar inscripciones del estudiante en tiempo real
  Stream<List<Inscripcion>> obtenerInscripcionesEstudiante(
      String estudianteId) {
    return _inscripciones
        .where('estudianteId', isEqualTo: estudianteId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Inscripcion.desdeMapa(doc.id, doc.data()))
            .toList());
  }

  /// 2. Cancelar inscripción con Transacción
  Future<void> cancelarInscripcion(
      String inscripcionId, String deporteCodigo) async {
    await _db.runTransaction((transaction) async {
      final inscRef = _inscripciones.doc(inscripcionId);
      final depRef = _db.collection('deportes').doc(deporteCodigo);

      final depSnap = await transaction.get(depRef);

      // Cambia el estado en la inscripción a 'cancelada'
      transaction.update(inscRef, {
        'estado': 'cancelada',
      });

      // Libera el cupo restando 1 en el deporte
      if (depSnap.exists) {
        final cuposActuales = depSnap.data()?['cuposOcupados'] as int? ?? 1;
        if (cuposActuales > 0) {
          transaction.update(depRef, {'cuposOcupados': cuposActuales - 1});
        }
      }
    });
  }
}
