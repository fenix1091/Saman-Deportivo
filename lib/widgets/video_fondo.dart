/// Video de fondo para la portada. En la web usa un iframe de YouTube; en el
/// resto de plataformas (y en las pruebas) no dibuja nada.
library;

export 'video_fondo_stub.dart' if (dart.library.html) 'video_fondo_web.dart';
