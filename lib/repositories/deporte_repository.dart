import '../models/deporte.dart';
import '../models/resena.dart';

/// Contrato de acceso al catálogo de deportes (CU-04, CU-05, CU-06).
///
/// Los ViewModels solo conocen esta interfaz (patrón Repositorio). La app usa
/// [DeporteRepositoryFirebase]; las pruebas usan un repositorio falso en memoria.
abstract class DeporteRepository {
  /// Deportes activos. Emite de nuevo cada vez que cambia uno, así los cupos se
  /// ven en tiempo real sin recargar (RNF-04).
  Stream<List<Deporte>> deportesActivos();

  /// Un deporte en tiempo real; emite `null` si no existe.
  Stream<Deporte?> deporte(String codigo);

  /// Horarios semanales de un deporte, ordenados por día y hora.
  Future<List<Horario>> horarios(String codigo);

  /// Reseñas de un deporte, de la más reciente a la más antigua.
  Stream<List<Resena>> resenas(String codigo);

  /// Suma una consulta al contador de deportes más buscados (postcondición de CU-04).
  Future<void> registrarConsulta(String codigo);
}

/// Error al leer el catálogo.
class CatalogoException implements Exception {
  const CatalogoException(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'CatalogoException($mensaje)';
}

/// Orden de los horarios: por día de la semana y luego por hora de inicio.
int compararHorarios(Horario a, Horario b) {
  final porDia = a.dia.index.compareTo(b.dia.index);
  return porDia != 0 ? porDia : a.horaInicio.compareTo(b.horaInicio);
}
