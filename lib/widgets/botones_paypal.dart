/// Botones oficiales de PayPal para pagar la reserva (CU-09, RF-09). En la web
/// carga el SDK de PayPal en modo sandbox; en el resto de plataformas (y en las
/// pruebas) [payPalDisponible] es `false` y la app usa la pasarela simulada.
library;

export 'botones_paypal_stub.dart' if (dart.library.html) 'botones_paypal_web.dart';
