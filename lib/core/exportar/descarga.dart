/// Descarga de archivos generados en la app (PDF y Excel). En la web abre la
/// descarga del navegador; en el resto de plataformas (y en las pruebas) no hace nada.
library;

export 'descarga_stub.dart' if (dart.library.html) 'descarga_web.dart';
