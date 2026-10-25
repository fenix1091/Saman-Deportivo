import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/validacion_inscripcion.dart';
import '../models/deporte.dart';
import '../models/inscripcion.dart';
import '../models/pago.dart';
import '../models/persona.dart';
import '../repositories/deporte_repository.dart';
import '../repositories/inscripcion_repository.dart';
import '../repositories/pasarela_pago.dart';

/// Inscripción de un estudiante en un deporte (CU-07, CU-08, CU-09; RF-07, RF-08, RF-09).
///
/// Valida estado, solvencia, cupo y choques de horario; reserva el cupo, cobra con
/// la pasarela y confirma la inscripción con su pago en una transacción.
class InscripcionViewModel extends ChangeNotifier {
  InscripcionViewModel({
    required DeporteRepository deportes,
    required InscripcionRepository inscripciones,
    required PasarelaPago pasarela,
    required this.estudiante,
    required this.codigo,
    DateTime Function()? reloj,
  })  : _deportes = deportes,
        _inscripciones = inscripciones,
        _pasarela = pasarela,
        _reloj = reloj ?? DateTime.now {
    _subDeporte = _deportes.deporte(codigo).listen((d) {
      _deporte = d;
      _cargandoDeporte = false;
      _notificar();
    }, onError: (_) => _fallarCarga());
    _subInscripciones = _inscripciones.inscripcionesDe(estudiante.uid).listen((lista) {
      _mias = lista;
      _cargandoInscripciones = false;
      _notificar();
      _cargarOtras();
    }, onError: (_) => _fallarCarga());
    _cargarHorarios();
  }

  final DeporteRepository _deportes;
  final InscripcionRepository _inscripciones;
  final PasarelaPago _pasarela;
  final DateTime Function() _reloj;
  final Estudiante estudiante;
  final String codigo;

  late final StreamSubscription<Deporte?> _subDeporte;
  late final StreamSubscription<List<Inscripcion>> _subInscripciones;
  bool _desechado = false;

  Deporte? _deporte;
  List<Horario> _horarios = const [];
  List<Inscripcion> _mias = const [];
  final _otras = <String, InscripcionConHorarios>{};
  bool _cargandoDeporte = true;
  bool _cargandoInscripciones = true;
  bool _cargandoHorarios = true;
  bool _procesando = false;
  String? _error;
  Pago? _pago;

  Deporte? get deporte => _deporte;
  List<Horario> get horarios => _horarios;
  bool get cargando => _cargandoDeporte || _cargandoInscripciones || _cargandoHorarios;
  bool get procesando => _procesando;
  String? get error => _error;

  /// Comprobante del pago que se acaba de hacer (CU-07, paso 7).
  Pago? get pago => _pago;

  /// Inscripción del estudiante en este deporte, si existe.
  Inscripcion? get inscripcion {
    for (final i in _mias) {
      if (i.deporteCodigo == codigo) return i;
    }
    return null;
  }

  bool get confirmada => inscripcion?.estado == EstadoInscripcion.confirmada;

  /// Reserva pendiente de pago que aún está dentro del plazo (RN-05).
  Inscripcion? get reservaPendiente {
    final i = inscripcion;
    return i != null && i.estado == EstadoInscripcion.pendientePago && !i.expiro(_reloj()) ? i : null;
  }

  /// Resultado de revisar todos los requisitos con los datos actuales (RF-07, RF-08).
  ResultadoValidacion? get validacion {
    final d = _deporte;
    if (d == null || cargando) return null;
    final otras = [
      for (final i in _mias)
        if (i.estaVigente(_reloj()))
          InscripcionConHorarios(
            inscripcion: i,
            nombreDeporte: _otras[i.deporteCodigo]?.nombreDeporte ?? i.deporteCodigo,
            horarios: _otras[i.deporteCodigo]?.horarios ?? const [],
          ),
    ];
    return ValidacionInscripcion.validar(
      estudiante: estudiante,
      deporte: d,
      horarios: _horarios,
      otras: otras,
      ahora: _reloj(),
    );
  }

  bool get puedePagar => !_procesando && !confirmada && (validacion?.aprobada ?? false);

  double get monto => _deporte?.costoReserva ?? 0;

  /// Reserva el cupo, cobra con PayPal y confirma la inscripción. Devuelve `true`
  /// si quedó CONFIRMADA. Si el pago se cancela, la reserva sigue pendiente (A4).
  Future<bool> inscribirYPagar() async {
    final d = _deporte;
    if (d == null || !puedePagar) {
      _error = ErrorInscripcion.noCumpleRequisitos.mensaje;
      _notificar();
      return false;
    }
    _procesando = true;
    _error = null;
    _notificar();
    try {
      var reserva = reservaPendiente;
      if (reserva == null) {
        final vencida = inscripcion;
        if (vencida != null && vencida.expiro(_reloj())) await _inscripciones.expirar(vencida);
        reserva = await _inscripciones.reservar(estudiante, d);
      }
      final referencia = monto == 0
          ? 'GRATUITA'
          : await _pasarela.cobrar(monto: monto, concepto: 'Reserva de cupo ${d.codigo} - ${d.nombre}');
      if (reserva.expiro(_reloj())) throw const InscripcionException(ErrorInscripcion.reservaVencida);
      _pago = await _inscripciones.confirmarPago(reserva, monto: monto, referencia: referencia);
      return true;
    } on InscripcionException catch (e) {
      _error = e.mensaje;
      return false;
    } catch (_) {
      _error = ErrorInscripcion.desconocido.mensaje;
      return false;
    } finally {
      _procesando = false;
      _notificar();
    }
  }

  Future<void> _cargarHorarios() async {
    try {
      _horarios = await _deportes.horarios(codigo);
    } catch (_) {
      _horarios = const [];
    }
    _cargandoHorarios = false;
    _notificar();
  }

  /// Carga el nombre y los horarios de las otras disciplinas vigentes (RN-04).
  Future<void> _cargarOtras() async {
    final faltan = _mias.where((i) => i.deporteCodigo != codigo && !_otras.containsKey(i.deporteCodigo)).toList();
    if (faltan.isEmpty) return;
    await Future.wait(faltan.map((i) async {
      try {
        final d = await _deportes.deporte(i.deporteCodigo).first;
        final h = await _deportes.horarios(i.deporteCodigo);
        _otras[i.deporteCodigo] =
            InscripcionConHorarios(inscripcion: i, nombreDeporte: d?.nombre ?? i.deporteCodigo, horarios: h);
      } catch (_) {
        // Sin sus horarios no se puede revisar el choque con esa disciplina.
      }
    }));
    _notificar();
  }

  void _fallarCarga() {
    _cargandoDeporte = false;
    _cargandoInscripciones = false;
    _error = ErrorInscripcion.sinConexion.mensaje;
    _notificar();
  }

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    _subDeporte.cancel();
    _subInscripciones.cancel();
    super.dispose();
  }
}
