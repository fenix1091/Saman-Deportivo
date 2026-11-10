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
    version: '1.5',
    fecha: DateTime(2026, 11, 9),
    titulo: 'Verificación del correo al registrarse',
    cambios: const [
      'Al crear la cuenta se pasa a la pantalla "Revisa tu correo", que avanza sola cuando se abre el enlace enviado.',
      'Se puede reenviar el correo o dejar la verificación para después.',
      'Sin verificar el correo se puede navegar, pero no reservar un cupo.',
      'El administrador puede dar un correo por verificado desde Usuarios, igual que la solvencia.',
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
