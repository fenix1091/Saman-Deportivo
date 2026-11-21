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

/// Pasarela de PayPal simulada.
///
/// En la web publicada el pago va por los botones oficiales de PayPal en modo
/// sandbox (widgets/botones_paypal_web.dart), que crean y capturan la orden en el
/// navegador con el Client ID, sin servidor ni clave secreta. Esta clase queda
/// para las pruebas y para cuando no hay Client ID: genera una referencia
/// `SANDBOX-...` después de la ventana de aprobación.
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
