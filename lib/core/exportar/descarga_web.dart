// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

/// Descarga [bytes] con el nombre [nombre] usando un enlace temporal.
Future<void> descargarArchivo(Uint8List bytes, String nombre, String tipo) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], tipo));
  final enlace = html.AnchorElement(href: url)
    ..download = nombre
    ..style.display = 'none';
  html.document.body!.append(enlace);
  enlace.click();
  enlace.remove();
  // Se libera después para no cortar la descarga en Safari.
  Future.delayed(const Duration(seconds: 5), () => html.Url.revokeObjectUrl(url));
}
