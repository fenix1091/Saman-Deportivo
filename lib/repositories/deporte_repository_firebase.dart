import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/deporte.dart';
import '../models/resena.dart';
import 'deporte_repository.dart';

/// [DeporteRepository] sobre Cloud Firestore.
///
/// Lee `deportes/{codigo}`, su subcolección `horarios` y la colección `resenas`.
/// Todo es de lectura pública (ver firestore.rules).
class DeporteRepositoryFirebase implements DeporteRepository {
  DeporteRepositoryFirebase({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _deportes => _db.collection('deportes');

  @override
  Stream<List<Deporte>> deportesActivos() {
    return _deportes.where('activo', isEqualTo: true).snapshots().map((consulta) {
      final lista = [for (final doc in consulta.docs) Deporte.desdeMapa(doc.id, doc.data())];
      lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      return lista;
    }).handleError((Object e) => throw _traducir(e));
  }

  @override
  Stream<Deporte?> deporte(String codigo) {
    return _deportes.doc(codigo).snapshots().map((doc) {
      final datos = doc.data();
      return datos == null ? null : Deporte.desdeMapa(doc.id, datos);
    }).handleError((Object e) => throw _traducir(e));
  }

  @override
  Future<List<Horario>> horarios(String codigo) async {
    try {
      final consulta = await _deportes.doc(codigo).collection('horarios').get();
      return [for (final doc in consulta.docs) Horario.desdeMapa(doc.id, doc.data())]..sort(compararHorarios);
    } catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Stream<List<Resena>> resenas(String codigo) {
    // Se ordena en el teléfono para no necesitar un índice compuesto en Firestore.
    return _db.collection('resenas').where('deporteCodigo', isEqualTo: codigo).snapshots().map((consulta) {
      final lista = [for (final doc in consulta.docs) Resena.desdeMapa(doc.id, doc.data())];
      lista.sort((a, b) => b.fecha.compareTo(a.fecha));
      return lista;
    }).handleError((Object e) => throw _traducir(e));
  }

  @override
  Future<void> registrarConsulta(String codigo) async {
    try {
      await _deportes.doc(codigo).update({'vecesBuscado': FieldValue.increment(1)});
    } catch (_) {
      // El contador es solo para las estadísticas: si falla, no se molesta al usuario.
    }
  }

  CatalogoException _traducir(Object e) {
    if (e is FirebaseException && e.code == 'unavailable') {
      return const CatalogoException('No hay conexión. Revisa tu internet e inténtalo de nuevo.');
    }
    return const CatalogoException('No pudimos cargar el catálogo. Inténtalo de nuevo.');
  }
}
