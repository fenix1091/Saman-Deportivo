/// Conversión de fechas entre Firestore y los modelos.
///
/// Los modelos no dependen de cloud_firestore: Firestore devuelve las fechas como
/// Timestamp, que se reconoce por su método toDate().
library;

DateTime? leerFecha(Object? valor) {
  if (valor == null) return null;
  if (valor is DateTime) return valor;
  if (valor is String) return DateTime.tryParse(valor);
  try {
    return (valor as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}
