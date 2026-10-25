import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/deporte.dart';
import '../models/inscripcion.dart';
import '../models/pago.dart';
import '../models/persona.dart';
import 'inscripcion_repository.dart';

/// [InscripcionRepository] sobre Cloud Firestore.
///
/// La inscripción vive en `inscripciones/{codigo}_{uid}` y cada pago en
/// `pagos/{idInscripcion}_{milisegundos}`. firestore.rules comprueba en el servidor
/// que el estudiante esté activo y solvente, que haya cupo y que el cupo solo suba
/// de uno en uno junto con un pago completado (RNF-05).
class InscripcionRepositoryFirebase implements InscripcionRepository {
  InscripcionRepositoryFirebase({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _inscripciones => _db.collection('inscripciones');

  @override
  Stream<List<Inscripcion>> inscripcionesDe(String estudianteId) {
    return _inscripciones
        .where('estudianteId', isEqualTo: estudianteId)
        .snapshots()
        .map((consulta) => [for (final doc in consulta.docs) Inscripcion.desdeMapa(doc.id, doc.data())])
        .handleError((Object e) => throw _traducir(e));
  }

  @override
  Future<Inscripcion> reservar(Estudiante estudiante, Deporte deporte) async {
    final id = Inscripcion.idPara(deporte.codigo, estudiante.uid);
    try {
      await _inscripciones.doc(id).set({
        'estudianteId': estudiante.uid,
        'deporteCodigo': deporte.codigo,
        'fechaInscripcion': FieldValue.serverTimestamp(),
        'estado': EstadoInscripcion.pendientePago.name,
        'motivo': '',
        'pagoId': '',
      });
      final guardada = await _inscripciones.doc(id).get();
      return Inscripcion.desdeMapa(id, guardada.data()!);
    } catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Future<Pago> confirmarPago(Inscripcion inscripcion, {required double monto, required String referencia}) async {
    final refInscripcion = _inscripciones.doc(inscripcion.id);
    final refDeporte = _db.collection('deportes').doc(inscripcion.deporteCodigo);
    final pagoId = '${inscripcion.id}_${DateTime.now().millisecondsSinceEpoch}';
    final refPago = _db.collection('pagos').doc(pagoId);
    try {
      final resultado = await _db.runTransaction((tx) async {
        final deporteDoc = await tx.get(refDeporte);
        final inscripcionDoc = await tx.get(refInscripcion);
        final actual = Inscripcion.desdeMapa(inscripcion.id, inscripcionDoc.data()!);
        if (actual.estado != EstadoInscripcion.pendientePago) {
          throw const InscripcionException(ErrorInscripcion.reservaVencida);
        }
        final deporte = Deporte.desdeMapa(deporteDoc.id, deporteDoc.data()!);
        final hayCupo = deporte.hayCupo();
        final pago = {
          'inscripcionId': inscripcion.id,
          'monto': monto,
          'moneda': 'USD',
          'metodo': 'PayPal',
          'referenciaExterna': referencia,
          'fecha': FieldValue.serverTimestamp(),
          'estado': (hayCupo ? EstadoPago.completado : EstadoPago.reembolsado).name,
        };
        tx.set(refPago, pago);
        if (hayCupo) {
          tx.update(refDeporte, {'cuposOcupados': deporte.cuposOcupados + 1});
          tx.update(refInscripcion, {'estado': EstadoInscripcion.confirmada.name, 'pagoId': pagoId});
        } else {
          tx.update(refInscripcion, {
            'estado': EstadoInscripcion.rechazada.name,
            'motivo': 'El cupo se agotó mientras pagaba; pago reembolsado.',
          });
        }
        return hayCupo;
      });
      if (!resultado) throw const InscripcionException(ErrorInscripcion.cupoAgotado);
      return Pago(
        id: pagoId,
        inscripcionId: inscripcion.id,
        monto: monto,
        referenciaExterna: referencia,
        fecha: DateTime.now(),
        estado: EstadoPago.completado,
      );
    } catch (e) {
      throw _traducir(e);
    }
  }

  @override
  Future<void> expirar(Inscripcion inscripcion) async {
    try {
      await _inscripciones.doc(inscripcion.id).update({
        'estado': EstadoInscripcion.expirada.name,
        'motivo': 'Pasaron ${Inscripcion.minutosParaPagar} minutos sin completar el pago.',
      });
    } catch (e) {
      throw _traducir(e);
    }
  }

  InscripcionException _traducir(Object e) {
    if (e is InscripcionException) return e;
    if (e is FirebaseException) {
      return switch (e.code) {
        // Las reglas rechazan una inscripción que no cumple los requisitos (por ejemplo,
        // un estudiante no solvente que se saltó la validación de la app).
        'permission-denied' => const InscripcionException(ErrorInscripcion.noCumpleRequisitos),
        'unavailable' => const InscripcionException(ErrorInscripcion.sinConexion),
        _ => const InscripcionException(ErrorInscripcion.desconocido),
      };
    }
    return const InscripcionException(ErrorInscripcion.desconocido);
  }
}
