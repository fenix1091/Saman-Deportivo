import '../models/asistencia.dart';

/// Una insignia que el estudiante gana al entrenar. [actual] y [meta] sirven para
/// mostrar cuánto le falta a las que aún no tiene.
class Insignia {
  const Insignia({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.actual,
    required this.meta,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final int actual;
  final int meta;

  bool get lograda => actual >= meta;

  /// Avance de 0 a 1.
  double get avance => meta == 0 ? 1 : (actual / meta).clamp(0, 1).toDouble();
}

/// Nivel del estudiante según los entrenamientos a los que asistió.
class NivelDeportista {
  const NivelDeportista(this.nombre, this.desde);

  final String nombre;

  /// Asistencias necesarias para alcanzarlo.
  final int desde;

  static const niveles = [
    NivelDeportista('Novato', 0),
    NivelDeportista('Constante', 5),
    NivelDeportista('Atleta', 15),
    NivelDeportista('Élite', 30),
    NivelDeportista('Leyenda Samán', 60),
  ];
}

/// Asistencia del estudiante en una de sus disciplinas.
class ProgresoDisciplina {
  const ProgresoDisciplina({required this.codigo, required this.nombre, required this.sesiones, required this.asistidas});

  final String codigo;
  final String nombre;
  final int sesiones;
  final int asistidas;

  double get porcentaje => sesiones == 0 ? 0 : asistidas * 100 / sesiones;
}

/// "Mi progreso" del estudiante, calculado con sus asistencias registradas.
///
/// Es una función pura de las asistencias (sin Firebase) para poder probarla.
class ProgresoEstudiante {
  ProgresoEstudiante._({
    required this.sesiones,
    required this.presentes,
    required this.rachaActual,
    required this.mejorRacha,
    required this.porDisciplina,
    required this.recientes,
    required this.insignias,
  });

  /// Calcula el progreso. [nombres] traduce el código de cada disciplina a su nombre.
  factory ProgresoEstudiante.calcular(List<Asistencia> asistencias, {Map<String, String> nombres = const {}}) {
    final ordenadas = [...asistencias]..sort((a, b) {
        final f = a.fecha.compareTo(b.fecha);
        return f != 0 ? f : a.deporteCodigo.compareTo(b.deporteCodigo);
      });
    bool presente(Asistencia a) => a.estado == EstadoAsistencia.presente;

    var racha = 0;
    var mejor = 0;
    for (final a in ordenadas) {
      racha = presente(a) ? racha + 1 : 0;
      if (racha > mejor) mejor = racha;
    }

    final codigos = <String>{for (final a in ordenadas) a.deporteCodigo};
    final porDisciplina = [
      for (final c in codigos)
        ProgresoDisciplina(
          codigo: c,
          nombre: nombres[c] ?? c,
          sesiones: ordenadas.where((a) => a.deporteCodigo == c).length,
          asistidas: ordenadas.where((a) => a.deporteCodigo == c && presente(a)).length,
        ),
    ]..sort((a, b) => b.asistidas.compareTo(a.asistidas));

    final presentes = ordenadas.where(presente).length;
    final disciplinasConAsistencia = porDisciplina.where((d) => d.asistidas > 0).length;
    final perfecta = porDisciplina
        .where((d) => d.asistidas == d.sesiones)
        .fold<int>(0, (m, d) => d.sesiones > m ? d.sesiones : m);
    final finDeSemana = ordenadas.where((a) => presente(a) && a.fecha.weekday >= DateTime.saturday).length;

    return ProgresoEstudiante._(
      sesiones: ordenadas.length,
      presentes: presentes,
      rachaActual: racha,
      mejorRacha: mejor,
      porDisciplina: porDisciplina,
      recientes: ordenadas.reversed.take(14).toList(),
      insignias: [
        Insignia(
            id: 'primer-paso',
            titulo: 'Primer paso',
            descripcion: 'Asiste a tu primer entrenamiento.',
            actual: presentes,
            meta: 1),
        Insignia(
            id: 'en-racha',
            titulo: 'En racha',
            descripcion: 'Asiste a 3 entrenamientos seguidos sin faltar.',
            actual: mejor,
            meta: 3),
        Insignia(
            id: 'constante',
            titulo: 'Constante',
            descripcion: 'Suma 10 asistencias.',
            actual: presentes,
            meta: 10),
        Insignia(
            id: 'perfecta',
            titulo: 'Asistencia perfecta',
            descripcion: 'No faltes a ninguna de las primeras 4 sesiones de una disciplina.',
            actual: perfecta,
            meta: 4),
        Insignia(
            id: 'multideporte',
            titulo: 'Multideporte',
            descripcion: 'Entrena en 2 disciplinas distintas.',
            actual: disciplinasConAsistencia,
            meta: 2),
        Insignia(
            id: 'fin-de-semana',
            titulo: 'Guerrero de fin de semana',
            descripcion: 'Asiste a un entrenamiento un sábado o domingo.',
            actual: finDeSemana,
            meta: 1),
        Insignia(
            id: 'sin-fallar',
            titulo: 'Sin fallar',
            descripcion: 'Asiste a 8 entrenamientos seguidos.',
            actual: mejor,
            meta: 8),
        Insignia(
            id: 'imparable',
            titulo: 'Imparable',
            descripcion: 'Suma 25 asistencias.',
            actual: presentes,
            meta: 25),
      ],
    );
  }

  final int sesiones;
  final int presentes;

  /// Entrenamientos seguidos a los que asistió, contando desde el último.
  final int rachaActual;
  final int mejorRacha;
  final List<ProgresoDisciplina> porDisciplina;

  /// Últimas sesiones registradas, de la más reciente a la más antigua.
  final List<Asistencia> recientes;
  final List<Insignia> insignias;

  double get porcentaje => sesiones == 0 ? 0 : presentes * 100 / sesiones;

  int get insigniasLogradas => insignias.where((i) => i.lograda).length;

  NivelDeportista get nivel => NivelDeportista.niveles.lastWhere((n) => presentes >= n.desde);

  /// El nivel que sigue, o `null` si ya está en el último.
  NivelDeportista? get siguienteNivel {
    final i = NivelDeportista.niveles.indexOf(nivel);
    return i + 1 < NivelDeportista.niveles.length ? NivelDeportista.niveles[i + 1] : null;
  }

  /// Avance hacia el siguiente nivel, de 0 a 1.
  double get avanceNivel {
    final sig = siguienteNivel;
    if (sig == null) return 1;
    return ((presentes - nivel.desde) / (sig.desde - nivel.desde)).clamp(0, 1).toDouble();
  }
}
