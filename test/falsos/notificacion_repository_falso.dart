import 'dart:async';

import 'package:saman_deportivo/models/notificacion.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/notificacion_repository.dart';

/// [NotificacionRepository] en memoria para las pruebas.
class NotificacionRepositoryFalso implements NotificacionRepository {
  final guardadas = <String, Notificacion>{};
  final _cambios = StreamController<void>.broadcast();
  int _n = 0;

  void agregar(Notificacion n) {
    guardadas[n.id] = n;
    _cambios.add(null);
  }

  @override
  Stream<List<Notificacion>> observar(String uid, Rol rol) async* {
    List<Notificacion> leer() => guardadas.values.where((n) => n.paraUid == uid || n.paraRol == rol.name).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    yield leer();
    yield* _cambios.stream.map((_) => leer());
  }

  @override
  Future<void> marcarLeida(String id) async {
    final n = guardadas[id];
    if (n != null) agregar(n.copiarCon(leida: true));
  }

  @override
  Future<void> marcarTodasLeidas(Iterable<String> ids) async {
    for (final id in ids) {
      await marcarLeida(id);
    }
  }

  @override
  Future<void> crear(Notificacion n) async {
    _n++;
    agregar(Notificacion.desdeMapa('n$_n', {...n.aMapa(), 'fecha': DateTime.now()}));
  }
}
