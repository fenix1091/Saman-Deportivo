import '../models/asistencia.dart';
import '../models/deporte.dart';

/// Un estudiante de la nómina de una disciplina (RF-14): datos del perfil que ve
/// el entrenador más el avance de asistencia guardado en su inscripción.
class EstudianteInscrito {
  const EstudianteInscrito({
    required this.uid,
    required this.inscripcionId,
    required this.nombreCompleto,
    this.cedulaTexto = '',
    this.carnet = '',
    this.sesiones = 0,
    this.sesionesAsistidas = 0,
  });

  final String uid;
  final String inscripcionId;
  final String nombreCompleto;
  final String cedulaTexto;
  final String carnet;
  final int sesiones;
  final int sesionesAsistidas;
}

/// Contrato del módulo del entrenador (CU-13, CU-14, CU-15; RF-14 a RF-16).
///
/// Los ViewModels solo conocen esta interfaz (patrón Repositorio). La app usa
/// [AsistenciaRepositoryFirebase]; las pruebas usan un repositorio falso en memoria.
abstract class AsistenciaRepository {
  /// Disciplinas asignadas al entrenador, en tiempo real.
  Stream<List<Deporte>> deportesDe(String entrenadorId);

  /// Nómina de una disciplina: solo los estudiantes con inscripción CONFIRMADA (RF-14).
  Stream<List<EstudianteInscrito>> nomina(String codigo);

  /// Todas las asistencias registradas en la disciplina, en tiempo real (RF-16).
  Stream<List<Asistencia>> asistenciasDe(String codigo);

  /// Guarda la asistencia de una fecha (RF-15): un documento por estudiante en
  /// `asistencias/{codigo}_{uid}_{aaaa-mm-dd}`. Si la fecha ya se había registrado,
  /// actualiza los estados en vez de duplicarlos, y mantiene al día los contadores
  /// `sesiones` y `sesionesAsistidas` de cada inscripción.
  Future<void> registrarAsistencia({
    required String codigo,
    required DateTime fecha,
    required Map<String, bool> presentes,
  });
}

/// Id del documento de asistencia de un estudiante en una fecha.
String idAsistencia(String codigo, String uid, DateTime fecha) => '${codigo}_${uid}_${claveFecha(fecha)}';

/// Fecha como "aaaa-mm-dd", sin hora.
String claveFecha(DateTime f) => '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

/// Error al leer o guardar la asistencia.
class AsistenciaException implements Exception {
  const AsistenciaException(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'AsistenciaException($mensaje)';
}
