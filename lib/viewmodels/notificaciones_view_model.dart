import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notificacion.dart';
import '../models/persona.dart';
import '../repositories/notificacion_repository.dart';

/// Campana de avisos: escucha los de la persona con sesión y cuenta los no leídos.
class NotificacionesViewModel extends ChangeNotifier {
  NotificacionesViewModel(this._repositorio);

  final NotificacionRepository _repositorio;
  StreamSubscription<List<Notificacion>>? _sub;
  List<Notificacion> _lista = const [];
  String? _uid;

  List<Notificacion> get notificaciones => _lista;
  int get noLeidas => _lista.where((n) => !n.leida).length;

  /// Empieza (o cambia) la escucha para la persona con sesión; `null` la detiene.
  void seguir(Persona? usuario) {
    if (usuario?.uid == _uid) return;
    _uid = usuario?.uid;
    _sub?.cancel();
    _lista = const [];
    if (usuario == null) {
      notifyListeners();
      return;
    }
    _sub = _repositorio.observar(usuario.uid, usuario.rol).listen((l) {
      _lista = l;
      notifyListeners();
    }, onError: (_) {
      _lista = const [];
      notifyListeners();
    });
  }

  Future<void> marcarLeida(Notificacion n) async {
    if (n.leida) return;
    try {
      await _repositorio.marcarLeida(n.id);
    } catch (_) {
      // Si falla, el aviso simplemente sigue sin leer.
    }
  }

  Future<void> marcarTodas() async {
    final ids = _lista.where((n) => !n.leida).map((n) => n.id).toList();
    if (ids.isEmpty) return;
    try {
      await _repositorio.marcarTodasLeidas(ids);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
