import 'inscripcion_repository.dart';

/// Pasarela con la que se cobra la reserva del cupo (CU-09, RF-09).
///
/// Samán Deportivo nunca ve los datos de la tarjeta: la pasarela devuelve solo la
/// referencia de la orden, que es lo que se guarda en el [Pago] (RNF-03).
abstract class PasarelaPago {
  /// Cobra [monto] en USD y devuelve la referencia de la orden aprobada.
  ///
  /// Lanza [InscripcionException] con [ErrorInscripcion.pagoCancelado] si el
  /// estudiante cierra la ventana, o [ErrorInscripcion.pagoRechazado] si se rechaza.
  Future<String> cobrar({required double monto, required String concepto});
}

/// Pasarela de PayPal en modo sandbox simulado.
///
/// Capturar una orden real de PayPal exige guardar la clave secreta en un servidor
/// (una Cloud Function), y Cloud Functions necesita el plan Blaze de Firebase.
/// Mientras tanto esta clase genera una referencia con el mismo formato que las
/// órdenes de PayPal; la vista muestra antes la ventana de aprobación. Para pasar
/// a PayPal real basta con otra implementación de [PasarelaPago].
class PasarelaPayPalSimulada implements PasarelaPago {
  PasarelaPayPalSimulada({this.demora = const Duration(milliseconds: 800)});

  final Duration demora;

  @override
  Future<String> cobrar({required double monto, required String concepto}) async {
    await Future<void>.delayed(demora);
    final marca = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return 'SANDBOX-$marca';
  }
}
