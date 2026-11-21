/// Una actualización publicada del sistema, con lo que cambió para quien lo usa.
class Novedad {
  const Novedad({required this.version, required this.fecha, required this.titulo, required this.cambios});

  final String version;
  final DateTime fecha;
  final String titulo;
  final List<String> cambios;
}

/// Registro de actualizaciones de Samán Deportivo, de la más reciente a la más antigua.
///
/// Solo lo ve el administrador, desde su perfil. Al publicar una versión nueva se
/// agrega su entrada al principio de esta lista.
final novedades = <Novedad>[
  Novedad(
    version: '1.15',
    fecha: DateTime(2026, 11, 21),
    titulo: 'Borradores, lugares sin choques y catálogo sin conexión',
    cambios: const [
      'Una disciplina sin entrenador o sin horarios queda como borrador: no sale en el catálogo ni recibe '
          'inscripciones, y en Clases y horarios lleva la etiqueta «Borrador» con lo que le falta.',
      'Al agregar un horario se revisan también las demás disciplinas: un lugar no puede quedar ocupado a la misma '
          'hora por dos clases.',
      'El catálogo se puede ver sin conexión (solo lectura) con lo último que se cargó; la app también abre sin '
          'internet una vez instalada.',
    ],
  ),
  Novedad(
    version: '1.14',
    fecha: DateTime(2026, 11, 21),
    titulo: 'Devolución al cancelar antes de la aprobación',
    cambios: const [
      'Si un estudiante cancela una inscripción pagada que aún no fue aprobada, se le avisa que se le devolverá el '
          'dinero porque la inscripción no se completó.',
      'La Coordinación recibe un aviso para hacer la devolución por PayPal, y en Revisión de reservas (filtro '
          'Cancelada) la reserva muestra "Devolución pendiente" con el botón Marcar como devuelto.',
      'Al marcarla, el estudiante recibe el aviso de que su pago fue devuelto.',
    ],
  ),
  Novedad(
    version: '1.13',
    fecha: DateTime(2026, 11, 21),
    titulo: 'Pago con animación',
    cambios: const [
      'Mientras se registra el pago aparece "Procesando tu pago", y al terminar una palomita animada confirma que '
          'se procesó antes de mostrar el comprobante.',
    ],
  ),
  Novedad(
    version: '1.12',
    fecha: DateTime(2026, 11, 21),
    titulo: 'Pago con PayPal',
    cambios: const [
      'La reserva se paga con los botones oficiales de PayPal (modo de pruebas, sin dinero real): con una cuenta de prueba de PayPal o con tarjeta.',
      'El cupo se aparta al abrir PayPal y la reserva pasa a revisión en cuanto PayPal confirma el cobro.',
      'En Revisión de reservas, cada reserva pagada muestra el número de la transacción de PayPal para comprobarlo antes de confirmarla.',
    ],
  ),
  Novedad(
    version: '1.11',
    fecha: DateTime(2026, 11, 21),
    titulo: 'Especialidad del entrenador desde las disciplinas',
    cambios: const [
      'Al registrar o editar un entrenador, la especialidad se elige de una lista con las disciplinas que ya existen, '
          'en vez de escribirla a mano.',
    ],
  ),
  Novedad(
    version: '1.10',
    fecha: DateTime(2026, 11, 19),
    titulo: 'Disciplinas y reseñas para el entrenador',
    cambios: const [
      'El entrenador tiene en su menú la página Disciplinas, con solo las disciplinas que tiene asignadas.',
      'La ficha de cada disciplina muestra el promedio de estrellas y las reseñas de los estudiantes.',
      'Arreglado: el entrenador ya puede guardar la asistencia (antes daba error al guardarla por primera vez en el '
          'día), también en disciplinas con muchos inscritos.',
    ],
  ),
  Novedad(
    version: '1.9',
    fecha: DateTime(2026, 11, 18),
    titulo: 'Mejor uso del espacio y datos del entrenador validados',
    cambios: const [
      'El resumen del administrador cabe en una pantalla: cifras compactas y gráficos de dos en dos.',
      'Toda la web aprovecha las pantallas anchas: el detalle de cada deporte, el perfil y la inscripción van en dos '
          'columnas; el catálogo llega a cuatro; clases, entrenadores, reservas, usuarios, Mis inscripciones, Mis '
          'entrenamientos, las disciplinas del entrenador y la toma de asistencia se reparten en columnas.',
      'Al registrar un entrenador, el correo tiene que ser de la UNIMET.',
      'La especialidad del entrenador solo admite letras (sin números), al registrarlo y al editarlo.',
      'Una reserva cancelada por la Coordinación muestra al estudiante el motivo de la cancelación.',
    ],
  ),
  Novedad(
    version: '1.8',
    fecha: DateTime(2026, 11, 17),
    titulo: 'Cancelar o cambiar reservas desde la administración',
    cambios: const [
      'En Revisión de reservas, cualquier reserva vigente se puede cancelar a mano con un motivo (por ejemplo, si el '
          'estudiante no se presenta) y decidir si el pago se marca como reembolsado.',
      'También se puede cambiar una reserva a otra disciplina: conserva el estado y el pago, y el cupo pasa de una a otra.',
      'Nuevo filtro "No se presentan": reservas confirmadas de estudiantes que faltaron a todas sus sesiones.',
      'El estudiante recibe un aviso en la campana con el motivo o la nueva disciplina.',
    ],
  ),
  Novedad(
    version: '1.7',
    fecha: DateTime(2026, 11, 17),
    titulo: 'Reportes en PDF y Excel y códigos únicos',
    cambios: const [
      'Entrenadores: la lista de inscritos y la asistencia de cada disciplina se descargan en PDF o Excel.',
      'Administración: lista de inscritos por disciplina y reporte general descargables en PDF o Excel.',
      'Al crear una disciplina, el formulario avisa al momento si el código ya existe y no deja guardarla.',
    ],
  ),
  Novedad(
    version: '1.6',
    fecha: DateTime(2026, 11, 17),
    titulo: 'Página de cada disciplina para el entrenador',
    cambios: const [
      'El entrenador puede abrir cualquiera de sus disciplinas desde su tarjeta o desde el calendario de la semana.',
      'La página de la disciplina reúne horarios y lugar, descripción, cupos, estudiantes inscritos con su asistencia, '
          'la toma de asistencia y el historial.',
    ],
  ),
  Novedad(
    version: '1.5',
    fecha: DateTime(2026, 11, 9),
    titulo: 'Verificación del correo al registrarse',
    cambios: const [
      'Al crear la cuenta se pasa a la pantalla "Revisa tu correo", que avanza sola cuando se abre el enlace enviado.',
      'Hasta verificar el correo no se puede entrar a la aplicación; el correo se puede reenviar desde esa pantalla.',
      'El administrador puede dar un correo por verificado desde Usuarios, igual que la solvencia.',
      'Eliminar un usuario ya no bloquea su correo: la cuenta se borra del todo y puede registrarse de nuevo.',
    ],
  ),
  Novedad(
    version: '1.4',
    fecha: DateTime(2026, 11, 9),
    titulo: 'Nueva imagen, más seguridad y registro de actualizaciones',
    cambios: const [
      'Pantallas de entrar, crear cuenta y recuperar contraseña con diseño nuevo a pantalla partida.',
      'Aspecto unificado en toda la aplicación: campos, botones, tarjetas y ventanas, con transiciones entre pantallas.',
      'El campo de correo propone terminar la dirección con @correo.unimet.edu.ve o @unimet.edu.ve.',
      'Casilla "No soy un robot" en el registro y verificación invisible de reCAPTCHA en toda la web.',
      'Pantalla propia para crear la contraseña nueva desde el enlace del correo; los correos salen en español.',
      'Solo se registran correos de la UNIMET y una cuenta eliminada ya no puede volver a crearse.',
      'Corregido: la campana de notificaciones no mostraba los avisos.',
      'Corregido: la ventana de editar usuario se abría vacía.',
      'Pantalla de carga con la marca mientras abre la aplicación.',
      'Este registro de actualizaciones en el perfil del administrador.',
    ],
  ),
  Novedad(
    version: '1.3',
    fecha: DateTime(2026, 11, 8),
    titulo: 'Notificaciones, calendario y menú lateral',
    cambios: const [
      'Menú lateral por rol con la marca; en el teléfono pasa a la parte inferior.',
      'Campana de notificaciones: reserva recibida, confirmada, rechazada, inscripción directa y retiro.',
      'Calendario semanal en los paneles del estudiante y del entrenador.',
      'Portadas con foto en cada disciplina y video de fondo en la página de bienvenida.',
      'Flecha de regreso en todas las pantallas.',
    ],
  ),
  Novedad(
    version: '1.2',
    fecha: DateTime(2026, 11, 8),
    titulo: 'Construcción: reservas en revisión, entrenador y administración completa',
    cambios: const [
      'La reserva pagada queda en revisión hasta que la Coordinación confirma o rechaza el pago.',
      'Entrenador: sus disciplinas, nómina de inscritos confirmados, asistencia por fecha e historial.',
      'Administrador: resumen con gráficos, reservas, inscritos de cada disciplina, entrenadores y usuarios.',
      'Disciplinas con código único, costo, duración y foto; se eliminan solo si no tienen inscripciones vigentes.',
      'Las reseñas solo se publican después de asistir a un entrenamiento.',
      'Panel del estudiante con sus reservas y su asistencia.',
    ],
  ),
  Novedad(
    version: '1.1',
    fecha: DateTime(2026, 11, 7),
    titulo: 'Registro más simple y página de bienvenida',
    cambios: const [
      'Registro con cédula numérica (V o E), nombre y apellido por separado y carnet opcional.',
      'Se aceptan los correos @correo.unimet.edu.ve y @unimet.edu.ve.',
      'El perfil permite cambiar nombre, apellido, teléfono y foto.',
      'Página de bienvenida nueva y filtros del catálogo en una ventana centrada.',
      'Gestión de usuarios para el administrador: buscar, filtrar, marcar solvencia y editar.',
    ],
  ),
  Novedad(
    version: '1.0',
    fecha: DateTime(2026, 10, 25),
    titulo: 'Primera versión publicada',
    cambios: const [
      'Registro, inicio de sesión por rol, recuperación de contraseña y perfil.',
      'Catálogo público con búsqueda, filtros, cupos en tiempo real y detalle de cada disciplina.',
      'Inscripción con validación de solvencia, control de cupos y pago simulado con PayPal.',
      'Mis inscripciones, cancelación y reseñas.',
      'Panel de administración para clases, horarios y entrenadores; toma de asistencia.',
      'Reglas de seguridad por rol en la base de datos y publicación en Firebase Hosting.',
    ],
  ),
];
