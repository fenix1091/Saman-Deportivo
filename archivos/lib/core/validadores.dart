/// Validaciones de los formularios de autenticación y perfil.
///
/// Cada función devuelve `null` si el valor es válido o el mensaje de error
/// que se muestra debajo del campo (en español y diciendo cómo corregirlo, RNF-07).
class Validadores {
  Validadores._();

  static const dominioEstudiantes = '@correo.unimet.edu.ve';

  /// Correos de la UNIMET que pueden registrarse: el de estudiante y el general.
  static const dominiosUnimet = [dominioEstudiantes, '@unimet.edu.ve'];

  /// Propuestas para terminar un correo a medio escribir con los dominios de la UNIMET:
  /// "vgallo" da "vgallo@correo.unimet.edu.ve" y "vgallo@unimet.edu.ve"; "vgallo@u" solo la segunda.
  static List<String> sugerenciasCorreo(String texto) {
    final t = texto.trim().toLowerCase();
    if (t.isEmpty || t.contains(' ')) return const [];
    final arroba = t.indexOf('@');
    final usuario = arroba < 0 ? t : t.substring(0, arroba);
    final escrito = arroba < 0 ? '' : t.substring(arroba);
    if (usuario.isEmpty || !RegExp(r'^[\w.+-]+$').hasMatch(usuario)) return const [];
    return [
      for (final dominio in dominiosUnimet)
        if (dominio.startsWith(escrito) && dominio != escrito) '$usuario$dominio',
    ];
  }

  static final _correo = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final _cedula = RegExp(r'^\d{6,9}$');
  static final _carnet = RegExp(r'^\d{11}$');
  static final _telefono = RegExp(r'^04(12|14|16|22|24|26)\d{7}$');

  static String? requerido(String? valor, String campo) =>
      (valor == null || valor.trim().isEmpty) ? 'Ingresa tu $campo.' : null;

  /// Correo con formato válido (para iniciar sesión con cualquier rol).
  static String? correo(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu correo.';
    if (!_correo.hasMatch(v)) return 'El correo no es válido. Ejemplo: nombre@correo.unimet.edu.ve';
    return null;
  }

  /// Correo institucional de estudiante (para el registro, CU-01).
  static String? correoEstudiante(String? valor) {
    final error = correo(valor);
    if (error != null) return error;
    final v = valor!.trim().toLowerCase();
    if (!dominiosUnimet.any(v.endsWith)) {
      return 'Usa tu correo de la UNIMET (${dominiosUnimet.join(' o ')}).';
    }
    return null;
  }

  /// Correo institucional de un entrenador que registra el administrador: solo
  /// cuentas de la UNIMET, para que nadie de fuera reciba el enlace de acceso.
  static String? correoEntrenador(String? valor) {
    final error = correo(valor);
    if (error != null) return error;
    final v = valor!.trim().toLowerCase();
    if (!dominiosUnimet.any(v.endsWith)) {
      return 'El entrenador debe tener correo de la UNIMET (${dominiosUnimet.join(' o ')}).';
    }
    return null;
  }

  static final _especialidad = RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ][A-Za-zÁÉÍÓÚÜÑáéíóúüñ ,/()'-]*$");

  /// Especialidad del entrenador: un deporte o área, solo letras (se admiten
  /// espacios, comas, barras y guiones: "Fútbol / Futsal"). Sin números.
  static String? especialidad(String? valor) {
    final v = (valor ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (v.isEmpty) return 'Ingresa la especialidad, por ejemplo Natación.';
    if (RegExp(r'\d').hasMatch(v)) return 'La especialidad no lleva números: escribe el deporte, por ejemplo Natación.';
    if (!_especialidad.hasMatch(v)) return 'Escribe la especialidad solo con letras, por ejemplo Fútbol / Futsal.';
    if (v.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]'), '').length < 3) {
      return 'La especialidad debe tener al menos 3 letras.';
    }
    if (v.length > 60) return 'La especialidad no puede pasar de 60 caracteres.';
    return null;
  }

  /// Años de experiencia: número entero de 0 a 60.
  static String? aniosExperiencia(String? valor) {
    final anios = int.tryParse((valor ?? '').trim());
    if (anios == null || anios < 0) return 'Ingresa un número igual o mayor que cero.';
    if (anios > 60) return 'Revisa los años de experiencia (máximo 60).';
    return null;
  }

  /// Letras de cédula admitidas: venezolano o extranjero.
  static const nacionalidades = ['V', 'E'];

  /// Número de cédula, solo dígitos (la letra se elige aparte): 31985476.
  static String? cedula(String? valor) {
    final v = (valor ?? '').replaceAll(RegExp(r'[\s.]'), '');
    if (v.isEmpty) return 'Ingresa tu cédula.';
    if (!_cedula.hasMatch(v)) return 'Escribe solo los números de la cédula, por ejemplo 31985476.';
    return null;
  }

  /// Convierte el texto del campo en el número que se guarda: "31.985.476" → 31985476.
  static int numeroCedula(String valor) => int.parse(valor.replaceAll(RegExp(r'[\s.]'), ''));

  /// Carnet UNIMET: opcional; si se escribe, son 11 dígitos.
  static String? carnet(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!_carnet.hasMatch(v)) return 'El carnet tiene 11 dígitos, sin guiones.';
    return null;
  }

  /// Solo letras (con acentos y ñ), espacios entre palabras y apóstrofo (D'Angelo).
  static final _soloLetras = RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ' ]+$");

  /// Nombre(s), sin el apellido: "María José".
  static String? nombre(String? valor) => _parteDelNombre(valor, 'nombre');

  /// Apellido(s), sin el nombre: "Pérez López".
  static String? apellido(String? valor) => _parteDelNombre(valor, 'apellido');

  static String? _parteDelNombre(String? valor, String campo) {
    final v = normalizarNombre(valor ?? '');
    if (v.isEmpty) return 'Ingresa tu $campo.';
    if (v.length > 40) return 'El $campo no puede pasar de 40 caracteres.';
    if (!_soloLetras.hasMatch(v)) return 'Escribe el $campo solo con letras, sin números ni símbolos.';
    return null;
  }

  /// Quita espacios de más y pone mayúscula inicial en cada palabra: "  maría   josé " → "María José".
  /// Así todos los nombres se guardan igual y se encuentran al buscar.
  static String normalizarNombre(String valor) => valor
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
      .join(' ');

  /// Al menos 8 caracteres, una letra y un número (requisito especial de CU-01).
  static String? clave(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Ingresa una contraseña.';
    if (v.length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
    if (!v.contains(RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]'))) return 'La contraseña debe tener al menos una letra.';
    if (!v.contains(RegExp(r'\d'))) return 'La contraseña debe tener al menos un número.';
    return null;
  }

  static String? confirmarClave(String? valor, String clave) => valor != clave ? 'Las contraseñas no coinciden.' : null;

  /// Teléfono móvil venezolano, opcional: 0414-1234567.
  static String? telefono(String? valor) {
    final v = (valor ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (v.isEmpty) return null;
    if (!_telefono.hasMatch(v)) return 'Escribe un celular válido, por ejemplo 0414-1234567.';
    return null;
  }
}
