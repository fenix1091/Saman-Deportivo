import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deporte.dart';

class DeporteRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream para obtener la lista de deportes en tiempo real (RF-04 y RF-06)
  Stream<List<Deporte>> getDeportesStream() {
    return _db.collection('deportes').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Deporte.desdeMapa(doc.id, doc.data());
      }).toList();
    });
  }
}
