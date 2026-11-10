import 'package:flutter_test/flutter_test.dart';
import 'package:saman_deportivo/core/router.dart';
import 'package:saman_deportivo/models/persona.dart';

void main() {
  const estudiante = Estudiante(
    uid: 'e1',
    cedula: 30111222,
    nombre: 'Estudiante Prueba',
    correo: 'estudiante@correo.unimet.edu.ve',
    carnet: '20231110001',
    correoVerificado: true,
  );
  const entrenador = Entrenador(
    uid: 't1',
    cedula: 20333444,
    nombre: 'Entrenador Prueba',
    correo: 'entrenador@unimet.edu.ve',
    especialidad: 'Fútbol',
  );

  group('Guardia de rutas', () {
    test('sin sesión, las rutas públicas se abren', () {
      for (final ruta in ['/', '/login', '/registro', '/recuperar-clave', '/catalogo', '/catalogo/FUT-01']) {
        expect(redirigir(null, Uri.parse(ruta)), isNull, reason: ruta);
      }
    });

    test('sin sesión, una ruta protegida manda al login y recuerda el destino', () {
      expect(redirigir(null, Uri.parse('/admin/dashboard')), '/login?destino=%2Fadmin%2Fdashboard');
    });

    test('con sesión, el login lleva a la pantalla del rol o al destino pendiente', () {
      expect(redirigir(estudiante, Uri.parse('/login')), '/estudiante');
      expect(redirigir(entrenador, Uri.parse('/login?destino=/entrenador/mis-deportes')), '/entrenador/mis-deportes');
    });

    test('mientras se recupera la sesión espera en /cargando y después vuelve a la ruta pedida', () {
      expect(redirigir(null, Uri.parse('/perfil'), listo: false), '/cargando?destino=%2Fperfil');
      expect(redirigir(estudiante, Uri.parse('/cargando?destino=/perfil')), '/perfil');
      expect(redirigir(null, Uri.parse('/cargando?destino=/perfil')), '/login?destino=%2Fperfil');
    });

    test('un rol no puede entrar en la sección de otro', () {
      expect(redirigir(estudiante, Uri.parse('/admin/dashboard')), '/estudiante');
      expect(redirigir(estudiante, Uri.parse('/entrenador/mis-deportes')), '/estudiante');
      expect(redirigir(entrenador, Uri.parse('/entrenador/mis-deportes')), isNull);
    });
    test('un estudiante sin verificar su correo solo ve la pantalla de verificación', () {
      const nuevo = Estudiante(uid: 'e2', cedula: 2, nombre: 'Nuevo', correo: 'n@correo.unimet.edu.ve', carnet: '');
      for (final ruta in ['/estudiante', '/catalogo', '/perfil', '/mis-inscripciones', '/login', '/']) {
        expect(redirigir(nuevo, Uri.parse(ruta)), '/verificar-correo', reason: ruta);
      }
      expect(redirigir(nuevo, Uri.parse('/verificar-correo')), isNull);
      expect(redirigir(nuevo, Uri.parse('/accion?mode=verifyEmail&oobCode=x')), isNull);
      expect(redirigir(nuevo.conCorreoVerificado(), Uri.parse('/estudiante')), isNull);
    });
  });
}
