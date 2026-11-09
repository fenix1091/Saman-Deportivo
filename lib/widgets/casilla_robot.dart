/// Casilla "No soy un robot" de reCAPTCHA para los formularios públicos. En la
/// web dibuja la casilla; en el resto de plataformas (y en las pruebas) no dibuja
/// nada y se da por marcada.
library;

export 'casilla_robot_stub.dart' if (dart.library.html) 'casilla_robot_web.dart';
