import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inscripcion.dart';
import '../models/resena.dart';

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

  /// 2. Cancelar inscripción con Transacción (CU-10)
  Future<void> cancelarInscripcion(
      String inscripcionId, String deporteCodigo) async {
    await _db.runTransaction((transaction) async {
      final inscRef = _inscripciones.doc(inscripcionId);
      final depRef = _db.collection('deportes').doc(deporteCodigo);

      final depSnap = await transaction.get(depRef);

      transaction.update(inscRef, {
        'estado': 'cancelada',
      });

      if (depSnap.exists) {
        final cuposActuales = depSnap.data()?['cuposOcupados'] as int? ?? 1;
        if (cuposActuales > 0) {
          transaction.update(depRef, {'cuposOcupados': cuposActuales - 1});
        }
      }
    });
  }

  /// 3. Publicar o actualizar Reseña (CU-12)
  Future<void> publicarResena({
    required String deporteCodigo,
    required String estudianteId,
    required int calificacion,
    required String comentario,
  }) async {
    final resenaId = '${deporteCodigo}_$estudianteId';

    final resena = Resena(
      id: resenaId,
      deporteCodigo: deporteCodigo,
      estudianteId: estudianteId,
      calificacion: calificacion,
      comentario: comentario,
      fecha: DateTime.now(),
    );

    await _db
        .collection('resenas')
        .doc(resenaId)
        .set(resena.aMapa(), SetOptions(merge: true));
  }
}
