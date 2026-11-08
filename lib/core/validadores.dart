/// Validaciones de los formularios de autenticación y perfil.
///
/// Cada función devuelve `null` si el valor es válido o el mensaje de error
/// que se muestra debajo del campo (en español y diciendo cómo corregirlo, RNF-07).
class Validadores {
  Validadores._();

  static const dominioEstudiantes = '@correo.unimet.edu.ve';

  /// Correos de la UNIMET que pueden registrarse: el de estudiante y el general.
  static const dominiosUnimet = [dominioEstudiantes, '@unimet.edu.ve'];

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
