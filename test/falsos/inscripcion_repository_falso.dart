import 'dart:async';

import 'package:saman_deportivo/models/deporte.dart';
import 'package:saman_deportivo/models/inscripcion.dart';
import 'package:saman_deportivo/models/pago.dart';
import 'package:saman_deportivo/models/persona.dart';
import 'package:saman_deportivo/repositories/inscripcion_repository.dart';
import 'package:saman_deportivo/repositories/pasarela_pago.dart';

import 'deporte_repository_falso.dart';

/// [InscripcionRepository] en memoria para las pruebas, sin conexión a Firebase.
///
/// Imita la transacción de Firestore: al confirmar el pago vuelve a leer el cupo
/// del [DeporteRepositoryFalso] y solo lo ocupa si todavía queda.
class InscripcionRepositoryFalso implements InscripcionRepository {
  InscripcionRepositoryFalso(this.deportes, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now;

  final DeporteRepositoryFalso deportes;
  final DateTime Function() _reloj;
  final guardadas = <String, Inscripcion>{};
  final pagos = <Pago>[];
  final _cambios = StreamController<void>.broadcast();

  /// Agrega una inscripción ya existente (por ejemplo, en otra disciplina).
  void agregar(Inscripcion inscripcion) {
    guardadas[inscripcion.id] = inscripcion;
    _cambios.add(null);
  }

  @override
  Stream<List<Inscripcion>> inscripcionesDe(String estudianteId) async* {
    List<Inscripcion> leer() => guardadas.values.where((i) => i.estudianteId == estudianteId).toList();
    yield leer();
    yield* _cambios.stream.map((_) => leer());
  }

  @override
  Future<Inscripcion> reservar(Estudiante estudiante, Deporte deporte) async {
    final id = Inscripcion.idPara(deporte.codigo, estudiante.uid);
    final previa = guardadas[id];
    if (previa != null && previa.estaVigente(_reloj())) {
      throw const InscripcionException(ErrorInscripcion.sinPermiso);
    }
    final nueva = Inscripcion(
      id: id,
      estudianteId: estudiante.uid,
      deporteCodigo: deporte.codigo,
      fechaInscripcion: _reloj(),
    );
    agregar(nueva);
    return nueva;
  }

  @override
  Future<Pago> confirmarPago(Inscripcion inscripcion, {required double monto, required String referencia}) async {
    final actual = guardadas[inscripcion.id]!;
    if (actual.estado != EstadoInscripcion.pendientePago) {
      throw const InscripcionException(ErrorInscripcion.reservaVencida);
    }
    final deporte = deportes.leer(inscripcion.deporteCodigo)!;
    final hayCupo = deporte.hayCupo();
    final pago = Pago(
      id: '${inscripcion.id}_${pagos.length + 1}',
      inscripcionId: inscripcion.id,
      monto: monto,
      referenciaExterna: referencia,
      fecha: _reloj(),
      estado: hayCupo ? EstadoPago.completado : EstadoPago.reembolsado,
    );
    pagos.add(pago);
    agregar(Inscripcion.desdeMapa(inscripcion.id, {
      ...actual.aMapa(),
      'estado': (hayCupo ? EstadoInscripcion.confirmada : EstadoInscripcion.rechazada).name,
      if (hayCupo) 'pagoId': pago.id,
    }));
    if (!hayCupo) throw const InscripcionException(ErrorInscripcion.cupoAgotado);
    deportes.cambiarCupos(deporte.codigo, deporte.cuposOcupados + 1);
    return pago;
  }

  @override
  Future<void> expirar(Inscripcion inscripcion) async {
    agregar(Inscripcion.desdeMapa(inscripcion.id, {...inscripcion.aMapa(), 'estado': EstadoInscripcion.expirada.name}));
  }
}

/// Pasarela de pruebas: aprueba al instante, o falla con [error] si se asigna.
class PasarelaFalsa implements PasarelaPago {
  ErrorInscripcion? error;
  int cobros = 0;

  @override
  Future<String> cobrar({required double monto, required String concepto}) async {
    if (error != null) throw InscripcionException(error!);
    cobros++;
    return 'PRUEBA-$cobros';
  }
}
