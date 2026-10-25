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
  Future<Persona> _leerPerfil(String uid) async {
    final doc = await _usuarios.doc(uid).get();
    final datos = doc.data();
    if (datos == null) {
      await _auth.signOut();
      throw const AuthException(ErrorAuth.perfilNoEncontrado);
    }
    return Persona.desdeMapa(uid, datos);
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
    required String cedula,
    required String nombre,
    required String correo,
    required String carnet,
    required String clave,
  }) async {
    _registrando = true;
    try {
      final credencial =
          await _auth.createUserWithEmailAndPassword(email: correo.trim().toLowerCase(), password: clave);
      final user = credencial.user!;
      try {
        if ((await _db.collection('cedulas').doc(cedula).get()).exists) {
          throw const AuthException(ErrorAuth.cedulaYaRegistrada);
        }
        if ((await _db.collection('carnets').doc(carnet).get()).exists) {
          throw const AuthException(ErrorAuth.carnetYaRegistrado);
        }
        final estudiante = Estudiante(
          uid: user.uid,
          cedula: cedula,
          nombre: nombre.trim(),
          correo: user.email ?? correo.trim().toLowerCase(),
          carnet: carnet,
        );
        final lote = _db.batch()
          ..set(_usuarios.doc(user.uid), {...estudiante.aMapa(), 'creadoEn': FieldValue.serverTimestamp()})
          ..set(_db.collection('cedulas').doc(cedula), {'uid': user.uid})
          ..set(_db.collection('carnets').doc(carnet), {'uid': user.uid});
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
    try {
      final credencial = await _auth.signInWithEmailAndPassword(email: correo.trim().toLowerCase(), password: clave);
      final usuario = await _leerPerfil(credencial.user!.uid);
      _publicar(usuario);
      return usuario;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    } on FirebaseException catch (e) {
      throw AuthException(_traducir(e.code));
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
  Future<void> cerrarSesion() async {
    await _auth.signOut();
    _publicar(null);
  }

  @override
  Future<Persona> actualizarPerfil(Persona usuario) async {
    try {
      await _usuarios.doc(usuario.uid).update({'telefono': usuario.telefono, 'fotoUrl': usuario.fotoUrl});
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
