/// Validaciones de los formularios de autenticación y perfil.
///
/// Cada función devuelve `null` si el valor es válido o el mensaje de error
/// que se muestra debajo del campo (en español y diciendo cómo corregirlo, RNF-07).
class Validadores {
  Validadores._();

  static const dominioEstudiantes = '@correo.unimet.edu.ve';

  static final _correo = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final _cedula = RegExp(r'^[VE]-?\d{6,9}$');
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
    if (!valor!.trim().toLowerCase().endsWith(dominioEstudiantes)) {
      return 'Usa tu correo institucional ($dominioEstudiantes).';
    }
    return null;
  }

  /// Cédula venezolana o de extranjero: V-12345678 o E-12345678.
  static String? cedula(String? valor) {
    final v = normalizarCedula(valor ?? '');
    if (v.isEmpty) return 'Ingresa tu cédula.';
    if (!_cedula.hasMatch(v)) return 'Escribe la cédula con su letra, por ejemplo V-31985476.';
    return null;
  }

  /// Quita puntos y espacios y pone la letra en mayúscula: "v 31.985.476" → "V-31985476".
  static String normalizarCedula(String valor) {
    final limpio = valor.toUpperCase().replaceAll(RegExp(r'[\s.]'), '');
    if (limpio.length > 1 && !limpio.contains('-') && RegExp(r'^[VE]\d').hasMatch(limpio)) {
      return '${limpio[0]}-${limpio.substring(1)}';
    }
    return limpio;
  }

  /// Carnet UNIMET: 11 dígitos.
  static String? carnet(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu carnet.';
    if (!_carnet.hasMatch(v)) return 'El carnet tiene 11 dígitos, sin guiones.';
    return null;
  }

  static String? nombre(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu nombre y apellido.';
    if (v.split(RegExp(r'\s+')).length < 2) return 'Escribe al menos un nombre y un apellido.';
    return null;
  }

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
