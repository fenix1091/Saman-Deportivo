import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notificacion.dart';
import '../models/persona.dart';

/// Contrato de los avisos dentro de la app (sustituyen al correo de RF-22).
abstract class NotificacionRepository {
  /// Avisos dirigidos a la persona o a su rol, en tiempo real, del más reciente al más antiguo.
  Stream<List<Notificacion>> observar(String uid, Rol rol);

  Future<void> marcarLeida(String id);

  Future<void> marcarTodasLeidas(Iterable<String> ids);

  /// Crea un aviso. Lo usan los repositorios al confirmar, rechazar, inscribir o retirar.
  Future<void> crear(Notificacion notificacion);
}

/// [NotificacionRepository] sobre Cloud Firestore.
///
/// Las reglas dejan a cualquier usuario crear avisos solo para el rol administrador
/// (por ejemplo "nueva reserva por revisar"); los avisos a personas los crea el administrador.
class NotificacionRepositoryFirebase implements NotificacionRepository {
  NotificacionRepositoryFirebase({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('notificaciones');

  @override
  Stream<List<Notificacion>> observar(String uid, Rol rol) => _col
      // Los avisos a un rol van con paraUid vacío; la consulta lo dice para que las reglas la acepten.
      .where(Filter.or(
        Filter('paraUid', isEqualTo: uid),
        Filter.and(Filter('paraUid', isEqualTo: ''), Filter('paraRol', isEqualTo: rol.name)),
      ))
      .snapshots()
      .map((c) =>
          [for (final d in c.docs) Notificacion.desdeMapa(d.id, d.data())]..sort((a, b) => b.fecha.compareTo(a.fecha)));

  @override
  Future<void> marcarLeida(String id) => _col.doc(id).update({'leida': true});

  @override
  Future<void> marcarTodasLeidas(Iterable<String> ids) async {
    final lote = _db.batch();
    for (final id in ids) {
      lote.update(_col.doc(id), {'leida': true});
    }
    await lote.commit();
  }

  @override
  Future<void> crear(Notificacion n) => _col.doc().set({...n.aMapa(), 'fecha': FieldValue.serverTimestamp()});
}

/// Crea un aviso sin que un fallo al notificar rompa la operación principal.
Future<void> notificarSinFallar(NotificacionRepository? repo, Notificacion n) async {
  if (repo == null) return;
  try {
    await repo.crear(n);
  } catch (_) {
    // El aviso es secundario: la reserva, el pago o la asistencia ya quedaron guardados.
  }
}
