import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/persona.dart';
import 'auth_repository.dart';

/// [AuthRepository] sobre Firebase Authentication y Cloud Firestore.
///
/// Cada usuario tiene un documento `usuarios/{uid}` con su rol. La cédula y el
/// carnet no se repiten gracias a los índices `cedulas/{cedula}` y `carnets/{carnet}`,
/// que se escriben en el mismo lote que el usuario (ver firestore.rules).
class AuthRepositoryFirebase implements AuthRepository {
  AuthRepositoryFirebase({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance {
    // Los correos de verificación y de contraseña salen en español.
    _auth.setLanguageCode('es');
    _suscripcion = _auth.authStateChanges().listen(_alCambiarUsuario);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final _sesion = StreamController<Persona?>.broadcast();
  late final StreamSubscription<User?> _suscripcion;
  Persona? _actual;

  /// Mientras se registra un estudiante, Firebase avisa la sesión antes de que exista
  /// su documento en Firestore; ese aviso se ignora hasta terminar el registro.
  bool _registrando = false;

  CollectionReference<Map<String, dynamic>> get _usuarios => _db.collection('usuarios');

  @override
  Persona? get usuarioActual => _actual;

  @override
  Stream<Persona?> get cambiosDeSesion => _sesion.stream;

  void _publicar(Persona? usuario) {
    _actual = usuario;
    _sesion.add(usuario);
  }

  Future<void> _alCambiarUsuario(User? user) async {
    if (_registrando || user?.uid == _actual?.uid) return;
    if (user == null) return _publicar(null);
    try {
      _publicar(await _leerPerfil(user.uid));
    } on AuthException {
      _publicar(null);
    }
  }

  /// Lee `usuarios/{uid}`. Si la cuenta no tiene perfil, cierra la sesión.
  ///
  /// Con [borrarSiEliminada], una cuenta que la Coordinación eliminó se borra del
  /// todo en este momento, para que su correo quede libre.
  Future<Persona> _leerPerfil(String uid, {bool borrarSiEliminada = false}) async {
    final doc = await _usuarios.doc(uid).get();
    final datos = doc.data();
    if (datos == null) {
      final user = _auth.currentUser;
      if (borrarSiEliminada && user != null && await _borrarSiFueEliminada(user)) {
        throw const AuthException(ErrorAuth.cuentaEliminada);
      }
      await _auth.signOut();
      throw const AuthException(ErrorAuth.perfilNoEncontrado);
    }
    return Persona.desdeMapa(uid, datos);
  }

  /// Eliminar un usuario desde el panel solo puede borrar su perfil: la cuenta de
  /// acceso únicamente la puede borrar su dueño. Por eso se termina de borrar aquí,
  /// la siguiente vez que esa cuenta abre sesión. Devuelve `true` si la borró.
  Future<bool> _borrarSiFueEliminada(User user) async {
    try {
      final marca = _db.collection('eliminados').doc(user.uid);
      if (!(await marca.get()).exists) return false;
      await marca.delete();
      await user.delete();
      return true;
    } on FirebaseException {
      return false;
    }
  }

  /// Si [correo] es de una cuenta eliminada y [clave] es la suya, la borra del todo
  /// para que el registro pueda crearla de nuevo. Devuelve `true` si quedó libre.
  Future<bool> _liberarCuentaEliminada(String correo, String clave) async {
    try {
      final credencial = await _auth.signInWithEmailAndPassword(email: correo, password: clave);
      final user = credencial.user!;
      final tienePerfil = (await _usuarios.doc(user.uid).get()).exists;
      if (!tienePerfil && await _borrarSiFueEliminada(user)) return true;
      await _auth.signOut();
      return false;
    } on FirebaseException {
      return false;
    }
  }

  @override
  Future<Persona?> restaurarSesion() async {
    final user = await _auth.authStateChanges().first;
    if (user == null) return _actual = null;
    try {
      return _actual = await _leerPerfil(user.uid);
    } on AuthException {
      return _actual = null;
    } on FirebaseException {
      return _actual = null;
    }
  }

  @override
  Future<Estudiante> registrarEstudiante({
    required String nacionalidad,
    required int cedula,
    required String nombre,
    required String apellido,
    required String correo,
    required String carnet,
    required String clave,
  }) async {
    _registrando = true;
    try {
      final direccion = correo.trim().toLowerCase();
      UserCredential credencial;
      try {
        credencial = await _auth.createUserWithEmailAndPassword(email: direccion, password: clave);
      } on FirebaseAuthException catch (e) {
        // El correo puede ser de una cuenta eliminada: se borra del todo y se crea de nuevo.
        final liberada = e.code == 'email-already-in-use' && await _liberarCuentaEliminada(direccion, clave);
        if (!liberada) rethrow;
        credencial = await _auth.createUserWithEmailAndPassword(email: direccion, password: clave);
      }
      final user = credencial.user!;
      final indiceCedula = _db.collection('cedulas').doc('$nacionalidad-$cedula');
      try {
        if ((await indiceCedula.get()).exists) {
          throw const AuthException(ErrorAuth.cedulaYaRegistrada);
        }
        // El carnet es opcional: solo se reserva si el estudiante lo escribió.
        if (carnet.isNotEmpty && (await _db.collection('carnets').doc(carnet).get()).exists) {
          throw const AuthException(ErrorAuth.carnetYaRegistrado);
        }
        final estudiante = Estudiante(
          uid: user.uid,
          nacionalidad: nacionalidad,
          cedula: cedula,
          nombre: nombre.trim(),
          apellido: apellido.trim(),
          correo: user.email ?? correo.trim().toLowerCase(),
          carnet: carnet,
        );
        final lote = _db.batch()
          ..set(_usuarios.doc(user.uid), {...estudiante.aMapa(), 'creadoEn': FieldValue.serverTimestamp()})
          ..set(indiceCedula, {'uid': user.uid});
        if (carnet.isNotEmpty) lote.set(_db.collection('carnets').doc(carnet), {'uid': user.uid});
        await lote.commit();
        unawaited(user.sendEmailVerification().catchError((_) {}));
        _publicar(estudiante);
        return estudiante;
      } catch (_) {
        // Sin perfil la cuenta no sirve: se borra para que el estudiante pueda reintentar.
        await user.delete().catchError((_) {});
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    } on FirebaseException catch (e) {
      throw AuthException(_traducir(e.code));
    } finally {
      _registrando = false;
    }
  }

  @override
  Future<Persona> iniciarSesion(String correo, String clave) async {
    // Mientras dura el inicio de sesión se ignora el aviso automático de Firebase,
    // para que no cierre la sesión antes de terminar de borrar una cuenta eliminada.
    _registrando = true;
    try {
      final credencial = await _auth.signInWithEmailAndPassword(email: correo.trim().toLowerCase(), password: clave);
      final usuario = await _leerPerfil(credencial.user!.uid, borrarSiEliminada: true);
      _publicar(usuario);
      // Si verificó el correo desde otro dispositivo, se anota al entrar.
      unawaited(comprobarCorreoVerificado().then((_) {}, onError: (_) {}));
      return usuario;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    } on FirebaseException catch (e) {
      throw AuthException(_traducir(e.code));
    } finally {
      _registrando = false;
    }
  }

  @override
  Future<void> enviarRecuperacionClave(String correo) async {
    try {
      await _auth.sendPasswordResetEmail(email: correo.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      // No se revela si el correo tiene cuenta.
      if (e.code == 'user-not-found') return;
      throw AuthException(_traducir(e.code));
    }
  }

  @override
  Future<String> correoDelEnlace(String codigo) async {
    try {
      return await _auth.verifyPasswordResetCode(codigo);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    }
  }

  @override
  Future<void> cambiarClaveConEnlace(String codigo, String clave) async {
    try {
      await _auth.confirmPasswordReset(code: codigo, newPassword: clave);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    }
  }

  @override
  Future<void> verificarCorreo(String codigo) async {
    try {
      await _auth.applyActionCode(codigo);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    }
  }

  @override
  Future<bool> comprobarCorreoVerificado() async {
    final actual = _actual;
    if (_auth.currentUser == null || actual is! Estudiante) return false;
    if (actual.correoVerificado) return true;
    try {
      // La Coordinación pudo darlo por verificado desde el panel.
      final perfil = await _usuarios.doc(actual.uid).get();
      if (perfil.data()?['correoVerificado'] == true) {
        _publicar(actual.conCorreoVerificado());
        return true;
      }
      await _auth.currentUser!.reload();
      final user = _auth.currentUser;
      if (user == null || !user.emailVerified) return false;
      // Las reglas leen la verificación del token: se renueva antes de anotarla en el perfil.
      await user.getIdToken(true);
      await _usuarios.doc(actual.uid).update({'correoVerificado': true});
      _publicar(actual.conCorreoVerificado());
      return true;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    } on FirebaseException catch (e) {
      throw AuthException(_traducir(e.code));
    }
  }

  @override
  Future<void> reenviarVerificacion() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    }
  }

  @override
  Future<void> cerrarSesion() async {
    await _auth.signOut();
    _publicar(null);
  }

  @override
  Future<Persona> actualizarPerfil(Persona usuario) async {
    try {
      await _usuarios.doc(usuario.uid).update({
        'nombre': usuario.nombre,
        'apellido': usuario.apellido,
        'telefono': usuario.telefono,
        'fotoUrl': usuario.fotoUrl,
      });
      _publicar(usuario);
      return usuario;
    } on FirebaseException catch (e) {
      throw AuthException(_traducir(e.code));
    }
  }

  /// La foto (ya reducida al elegirla) se guarda dentro del perfil como data URL,
  /// porque Cloud Storage exige el plan de pago Blaze.
  @override
  Future<String> subirFotoPerfil(String uid, Uint8List bytes, String extension) async {
    final tipo = extension == 'png' ? 'png' : (extension == 'webp' ? 'webp' : 'jpeg');
    return 'data:image/$tipo;base64,${base64Encode(bytes)}';
  }

  static ErrorAuth _traducir(String codigo) => switch (codigo) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'invalid-email' ||
        'user-disabled' =>
          ErrorAuth.credencialesInvalidas,
        'expired-action-code' || 'invalid-action-code' => ErrorAuth.enlaceInvalido,
        'email-already-in-use' => ErrorAuth.correoYaRegistrado,
        'weak-password' => ErrorAuth.claveDebil,
        'too-many-requests' => ErrorAuth.demasiadosIntentos,
        'network-request-failed' || 'unavailable' => ErrorAuth.sinConexion,
        'permission-denied' => ErrorAuth.sinPermiso,
        _ => ErrorAuth.desconocido,
      };

  void dispose() {
    _suscripcion.cancel();
    _sesion.close();
  }
}
