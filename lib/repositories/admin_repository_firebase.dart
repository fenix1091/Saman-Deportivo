import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/deporte.dart';
import '../models/persona.dart';

abstract interface class AdminRepository {
  Stream<List<Deporte>> observarDeportes();
  Stream<List<Entrenador>> observarEntrenadores();
  Stream<List<Horario>> observarHorarios(String codigo);
  Future<void> guardarDeporte(Deporte deporte);
  Future<void> actualizarActivoDeporte(String codigo, bool activo);
  Future<void> asignarEntrenador(String codigo, String entrenadorId);
  Future<void> guardarHorario(String codigo, Horario horario);
  Future<void> eliminarHorario(String codigo, String horarioId);
  Future<void> registrarEntrenador({
    required String cedula,
    required String nombre,
    required String correo,
    required String telefono,
    required String especialidad,
    required int aniosExperiencia,
  });
  Future<void> reenviarEnlace(String correo);
}

class EntrenadorCreadoException implements Exception {
  const EntrenadorCreadoException(this.causa);

  final Object causa;

  @override
  String toString() =>
      'La cuenta se creó, pero no se pudo enviar el enlace: $causa';
}

/// Acceso a la gestión administrativa de deportes, horarios y entrenadores.
class AdminRepositoryFirebase implements AdminRepository {
  AdminRepositoryFirebase({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  @override
  Stream<List<Deporte>> observarDeportes() =>
      _db.collection('deportes').snapshots().map(
            (snapshot) => snapshot.docs
                .map((doc) => Deporte.desdeMapa(doc.id, doc.data()))
                .toList()
              ..sort((a, b) =>
                  a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())),
          );

  @override
  Stream<List<Entrenador>> observarEntrenadores() => _db
      .collection('usuarios')
      .where('rol', isEqualTo: Rol.entrenador.name)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Entrenador.desdeMapa(doc.id, doc.data()))
          .toList()
        ..sort((a, b) =>
            a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())));

  @override
  Stream<List<Horario>> observarHorarios(String codigo) => _db
      .collection('deportes')
      .doc(codigo)
      .collection('horarios')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Horario.desdeMapa(doc.id, doc.data()))
          .toList()
        ..sort((a, b) {
          final dia = a.dia.index.compareTo(b.dia.index);
          return dia == 0 ? a.horaInicio.compareTo(b.horaInicio) : dia;
        }));

  @override
  Future<void> guardarDeporte(Deporte deporte) async {
    final deportes = _db.collection('deportes');
    if (deporte.codigo.isEmpty) {
      await deportes.doc().set(deporte.aMapa());
      return;
    }
    await deportes.doc(deporte.codigo).update({
      'nombre': deporte.nombre,
      'descripcion': deporte.descripcion,
      'categoria': deporte.categoria,
      'cupoMaximo': deporte.cupoMaximo,
      'costoReserva': deporte.costoReserva,
      'imagenUrl': deporte.imagenUrl,
      'entrenadorId': deporte.entrenadorId,
      'activo': deporte.activo,
    });
  }

  @override
  Future<void> actualizarActivoDeporte(String codigo, bool activo) async {
    await _db.collection('deportes').doc(codigo).update({'activo': activo});
  }

  @override
  Future<void> asignarEntrenador(String codigo, String entrenadorId) async {
    if (entrenadorId.isNotEmpty) {
      final entrenador =
          await _db.collection('usuarios').doc(entrenadorId).get();
      if (entrenador.data()?['rol'] != Rol.entrenador.name) {
        throw StateError(
            'El usuario seleccionado no tiene el rol de entrenador.');
      }
    }
    await _db
        .collection('deportes')
        .doc(codigo)
        .update({'entrenadorId': entrenadorId});
  }

  @override
  Future<void> guardarHorario(String codigo, Horario horario) async {
    final horarios =
        _db.collection('deportes').doc(codigo).collection('horarios');
    final referencia =
        horario.id.isEmpty ? horarios.doc() : horarios.doc(horario.id);
    await referencia.set(horario.aMapa());
  }

  @override
  Future<void> eliminarHorario(String codigo, String horarioId) async {
    await _db
        .collection('deportes')
        .doc(codigo)
        .collection('horarios')
        .doc(horarioId)
        .delete();
  }

  @override
  Future<void> registrarEntrenador({
    required String cedula,
    required String nombre,
    required String correo,
    required String telefono,
    required String especialidad,
    required int aniosExperiencia,
  }) async {
    final cedulaRef = _db.collection('cedulas').doc(cedula);
    if ((await cedulaRef.get()).exists) {
      throw StateError('Ya existe una cuenta con esa cédula.');
    }

    final app = await Firebase.initializeApp(
      name: 'entrenador-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final authSecundario = FirebaseAuth.instanceFor(app: app);
    User? cuenta;
    try {
      final credencial = await authSecundario.createUserWithEmailAndPassword(
        email: correo.trim().toLowerCase(),
        password: _claveAleatoria(),
      );
      cuenta = credencial.user!;
      final entrenador = Entrenador(
        uid: cuenta.uid,
        cedula: cedula,
        nombre: nombre.trim(),
        correo: cuenta.email ?? correo.trim().toLowerCase(),
        telefono: telefono.trim(),
        especialidad: especialidad.trim(),
        aniosExperiencia: aniosExperiencia,
      );
      final lote = _db.batch()
        ..set(_db.collection('usuarios').doc(cuenta.uid), entrenador.aMapa())
        ..set(cedulaRef, {'uid': cuenta.uid});
      await lote.commit();
    } catch (error) {
      if (cuenta != null) {
        await cuenta.delete();
      }
      rethrow;
    } finally {
      await app.delete();
    }

    try {
      await _auth.sendPasswordResetEmail(email: correo.trim().toLowerCase());
    } on FirebaseAuthException catch (error) {
      throw EntrenadorCreadoException(error.message ?? error.code);
    }
  }

  @override
  Future<void> reenviarEnlace(String correo) =>
      _auth.sendPasswordResetEmail(email: correo);

  static String _claveAleatoria() {
    const caracteres =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final aleatorio = Random.secure();
    return List.generate(
        40, (_) => caracteres[aleatorio.nextInt(caracteres.length)]).join();
  }
}
