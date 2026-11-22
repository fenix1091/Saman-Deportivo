import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/validacion_admin.dart';
import '../core/validadores.dart';
import '../models/deporte.dart';
import '../models/inscripcion.dart';
import '../models/notificacion.dart';
import '../models/pago.dart';
import '../models/persona.dart';
import 'notificacion_repository.dart';

abstract interface class AdminRepository {
  Stream<List<Deporte>> observarDeportes();
  Stream<List<Entrenador>> observarEntrenadores();
  Stream<List<Horario>> observarHorarios(String codigo);

  /// Crea una disciplina ([nueva] con su código único como id) o actualiza una
  /// existente. Lanza [CodigoRepetidoException] si el código ya está en uso.
  Future<void> guardarDeporte(Deporte deporte, {bool nueva = false});
  Future<void> actualizarActivoDeporte(String codigo, bool activo);
  Future<void> asignarEntrenador(String codigo, String entrenadorId);
  Future<void> guardarHorario(String codigo, Horario horario);
  Future<void> eliminarHorario(String codigo, String horarioId);
  Future<void> registrarEntrenador({
    required String nacionalidad,
    required int cedula,
    required String nombre,
    required String apellido,
    required String correo,
    required String telefono,
    required String especialidad,
    required int aniosExperiencia,
  });
  Future<void> reenviarEnlace(String correo);

  /// Todos los usuarios (estudiantes, entrenadores y administradores), ordenados por apellido.
  Stream<List<Persona>> observarUsuarios();

  /// Cambia campos del perfil de cualquier usuario: nombre, solvencia, estado, etc.
  Future<void> actualizarUsuario(String uid, Map<String, dynamic> cambios);

  /// Todas las reservas (inscripciones) del sistema, en tiempo real, de la más
  /// reciente a la más antigua. Sirve para revisar los pagos y para el resumen.
  Stream<List<Inscripcion>> observarInscripciones();

  /// Número de la transacción de PayPal del pago `pagos/{pagoId}` (para
  /// comprobarlo en la cuenta de PayPal antes de confirmar la reserva).
  Future<String?> referenciaDePago(String pagoId);

  /// La Coordinación ya devolvió por PayPal el pago de una reserva que el
  /// estudiante canceló antes de la aprobación: marca el pago como reembolsado
  /// y le avisa al estudiante.
  Future<void> marcarDevuelto(String inscripcionId);

  /// Da por válido el pago de una reserva en revisión: pasa a CONFIRMADA.
  Future<void> confirmarReserva(String id);

  /// Rechaza una reserva en revisión: libera su cupo y marca el pago como reembolsado.
  Future<void> rechazarReserva(String id, String motivo);

  /// Elimina por completo una disciplina y sus horarios. Solo si no tiene
  /// inscripciones vigentes ([ValidacionAdmin.eliminarDeporte]); si las tiene lanza
  /// [OperacionNoPermitidaException] con el motivo.
  Future<void> eliminarDeporte(String codigo);

  /// Inscribe directamente a un estudiante (sin pago, estado CONFIRMADA, ocupa cupo),
  /// previa [ValidacionAdmin.inscribirDirecto].
  Future<void> inscribirEstudiante(String codigo, String estudianteUid);

  /// Retira a un estudiante de una disciplina: cancela su inscripción vigente y
  /// libera el cupo si lo ocupaba.
  Future<void> retirarEstudiante(String inscripcionId);

  /// Cancela a mano una reserva vigente (por ejemplo, si el estudiante no se
  /// presenta): pasa a CANCELADA con [motivo], libera el cupo si lo ocupaba y, si
  /// [reembolsar], marca su pago como reembolsado. Avisa al estudiante.
  Future<void> cancelarReserva(String inscripcionId, {required String motivo, bool reembolsar = false});

  /// Cambia una reserva vigente a otra disciplina ([ValidacionAdmin.cambiarReserva]):
  /// la anterior queda CANCELADA y la nueva conserva el estado, el pago y el monto.
  /// Mueve el cupo de una disciplina a la otra y avisa al estudiante.
  Future<void> cambiarReserva(String inscripcionId, String nuevoCodigo);

  /// Elimina el perfil de un usuario y sus índices de cédula y carnet, previa
  /// [ValidacionAdmin.eliminarUsuario]. La cuenta de acceso queda sin perfil y no
  /// puede entrar (borrar la cuenta de Auth exige Cloud Functions).
  Future<void> eliminarUsuario(String uid);
}

/// La operación no cumple una regla de negocio del panel; [mensaje] explica cuál.
class OperacionNoPermitidaException implements Exception {
  const OperacionNoPermitidaException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Ya existe una disciplina con ese código (el código es el id del documento).
class CodigoRepetidoException implements Exception {
  const CodigoRepetidoException(this.codigo);

  final String codigo;

  @override
  String toString() => 'Ya existe una disciplina con el código $codigo.';
}

/// La reserva ya no está en revisión (otro administrador la resolvió antes).
class ReservaNoRevisableException implements Exception {
  const ReservaNoRevisableException();

  @override
  String toString() => 'La reserva ya no está en revisión.';
}

class EntrenadorCreadoException implements Exception {
  const EntrenadorCreadoException(this.causa);

  final Object causa;

  @override
  String toString() => 'La cuenta se creó, pero no se pudo enviar el enlace: $causa';
}

/// Acceso a la gestión administrativa de deportes, horarios y entrenadores.
class AdminRepositoryFirebase implements AdminRepository {
  AdminRepositoryFirebase({FirebaseFirestore? db, FirebaseAuth? auth, NotificacionRepository? notificaciones})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _notificaciones = notificaciones;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final NotificacionRepository? _notificaciones;

  Future<void> _avisar(String uid, TipoNotificacion tipo, String mensaje, {String ruta = '/mis-inscripciones'}) =>
      notificarSinFallar(
        _notificaciones,
        Notificacion(
            id: '',
            paraUid: uid,
            deUid: _auth.currentUser?.uid ?? '',
            tipo: tipo,
            titulo: tipo.titulo,
            mensaje: mensaje,
            ruta: ruta,
            fecha: DateTime.now()),
      );

  @override
  Stream<List<Deporte>> observarDeportes() => _db.collection('deportes').snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => Deporte.desdeMapa(doc.id, doc.data())).toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())),
      );

  @override
  Stream<List<Entrenador>> observarEntrenadores() => _db
      .collection('usuarios')
      .where('rol', isEqualTo: Rol.entrenador.name)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Entrenador.desdeMapa(doc.id, doc.data())).toList()
        ..sort((a, b) => a.nombreCompleto.toLowerCase().compareTo(b.nombreCompleto.toLowerCase())));

  @override
  Stream<List<Horario>> observarHorarios(String codigo) => _db
      .collection('deportes')
      .doc(codigo)
      .collection('horarios')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Horario.desdeMapa(doc.id, doc.data())).toList()
        ..sort((a, b) {
          final dia = a.dia.index.compareTo(b.dia.index);
          return dia == 0 ? a.horaInicio.compareTo(b.horaInicio) : dia;
        }));

  @override
  Future<void> guardarDeporte(Deporte deporte, {bool nueva = false}) async {
    final deportes = _db.collection('deportes');
    if (nueva || deporte.codigo.isEmpty) {
      final ref = deporte.codigo.isEmpty ? deportes.doc() : deportes.doc(deporte.codigo);
      await _db.runTransaction((tx) async {
        final existente = await tx.get(ref);
        if (existente.exists) throw CodigoRepetidoException(ref.id);
        tx.set(ref, deporte.aMapa());
      });
      return;
    }
    await deportes.doc(deporte.codigo).update({
      'nombre': deporte.nombre,
      'descripcion': deporte.descripcion,
      'categoria': deporte.categoria,
      'cupoMaximo': deporte.cupoMaximo,
      'costoReserva': deporte.costoReserva,
      'duracion': deporte.duracion,
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
    final deporte = _db.collection('deportes').doc(codigo);
    if (entrenadorId.isEmpty) {
      await deporte.update({'entrenadorId': '', 'entrenador': FieldValue.delete()});
      return;
    }
    final perfil = (await _db.collection('usuarios').doc(entrenadorId).get()).data();
    if (perfil?['rol'] != Rol.entrenador.name) {
      throw StateError('El usuario seleccionado no tiene el rol de entrenador.');
    }
    // El catálogo es público y no puede leer `usuarios`: se copia el nombre que muestra.
    await deporte.update({
      'entrenadorId': entrenadorId,
      'entrenador': EntrenadorAsignado.desdePerfil(perfil!).aMapa(),
    });
  }

  @override
  Future<void> guardarHorario(String codigo, Horario horario) async {
    // RF-19: el lugar no puede estar ocupado a esa hora por esta u otra disciplina.
    final deportes = await _db.collection('deportes').get();
    final ocupados = Map.fromEntries(await Future.wait(deportes.docs.map((d) async {
      final hs = await d.reference.collection('horarios').get();
      return MapEntry(
        Deporte.desdeMapa(d.id, d.data()),
        [for (final h in hs.docs) Horario.desdeMapa(h.id, h.data())],
      );
    })));
    final cruce = ValidacionAdmin.cruceDeLugar(codigo, horario, ocupados);
    if (cruce != null) throw OperacionNoPermitidaException(cruce);
    final horarios = _db.collection('deportes').doc(codigo).collection('horarios');
    final referencia = horario.id.isEmpty ? horarios.doc() : horarios.doc(horario.id);
    await referencia.set(horario.aMapa());
  }

  @override
  Future<void> eliminarHorario(String codigo, String horarioId) async {
    await _db.collection('deportes').doc(codigo).collection('horarios').doc(horarioId).delete();
  }

  @override
  Future<void> registrarEntrenador({
    required String nacionalidad,
    required int cedula,
    required String nombre,
    required String apellido,
    required String correo,
    required String telefono,
    required String especialidad,
    required int aniosExperiencia,
  }) async {
    // Las mismas reglas del formulario, por si se llama sin pasar por él.
    final invalido = Validadores.correoEntrenador(correo) ?? Validadores.especialidad(especialidad);
    if (invalido != null) throw OperacionNoPermitidaException(invalido);
    final cedulaRef = _db.collection('cedulas').doc('$nacionalidad-$cedula');
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
        nacionalidad: nacionalidad,
        cedula: cedula,
        nombre: nombre.trim(),
        apellido: apellido.trim(),
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
  Stream<List<Persona>> observarUsuarios() => _db.collection('usuarios').snapshots().map((snapshot) => snapshot.docs
      .map((doc) => Persona.desdeMapa(doc.id, doc.data()))
      .toList()
    ..sort((a, b) => '${a.apellido} ${a.nombre}'.toLowerCase().compareTo('${b.apellido} ${b.nombre}'.toLowerCase())));

  @override
  Future<void> actualizarUsuario(String uid, Map<String, dynamic> cambios) =>
      _db.collection('usuarios').doc(uid).update(cambios);

  @override
  Future<void> reenviarEnlace(String correo) => _auth.sendPasswordResetEmail(email: correo);

  static String _claveAleatoria() {
    const caracteres = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final aleatorio = Random.secure();
    return List.generate(40, (_) => caracteres[aleatorio.nextInt(caracteres.length)]).join();
  }

  @override
  Stream<List<Inscripcion>> observarInscripciones() => _db.collection('inscripciones').snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => Inscripcion.desdeMapa(doc.id, doc.data())).toList()
        ..sort((a, b) => b.fechaInscripcion.compareTo(a.fechaInscripcion)));

  @override
  Future<String?> referenciaDePago(String pagoId) async {
    final doc = await _db.collection('pagos').doc(pagoId).get();
    return doc.data()?['referenciaExterna'] as String?;
  }

  @override
  Future<void> marcarDevuelto(String inscripcionId) async {
    final ref = _db.collection('inscripciones').doc(inscripcionId);
    final inscripcion = await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (doc.data() == null) throw const OperacionNoPermitidaException('La reserva ya no existe.');
      final inscripcion = Inscripcion.desdeMapa(doc.id, doc.data()!);
      if (inscripcion.estado != EstadoInscripcion.cancelada || inscripcion.pagoId.isEmpty) {
        throw const OperacionNoPermitidaException('Esta reserva no tiene un pago por devolver.');
      }
      final refPago = _db.collection('pagos').doc(inscripcion.pagoId);
      final pago = await tx.get(refPago);
      if (pago.data()?['estado'] != EstadoPago.completado.name) {
        throw const OperacionNoPermitidaException('Este pago ya estaba marcado como devuelto.');
      }
      tx.update(refPago, {'estado': EstadoPago.reembolsado.name});
      tx.update(ref, {'motivo': Inscripcion.motivoDevuelto});
      return inscripcion;
    });
    await _avisar(
        inscripcion.estudianteId,
        TipoNotificacion.pagoDevuelto,
        'La Coordinación de Deportes te devolvió \$${inscripcion.monto.toStringAsFixed(2)} de tu reserva en '
        '${_nombre(inscripcion)}. Lo verás en la cuenta de PayPal con la que pagaste.');
  }

  @override
  Future<void> confirmarReserva(String id) async {
    final ref = _db.collection('inscripciones').doc(id);
    final reserva = await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (doc.data()?['estado'] != EstadoInscripcion.enRevision.name) {
        throw const ReservaNoRevisableException();
      }
      tx.update(ref, {'estado': EstadoInscripcion.confirmada.name, 'motivo': ''});
      return Inscripcion.desdeMapa(doc.id, doc.data()!);
    });
    await _avisar(reserva.estudianteId, TipoNotificacion.reservaConfirmada,
        'Tu cupo en ${_nombre(reserva)} quedó confirmado. ¡Nos vemos en el entrenamiento!');
  }

  static String _nombre(Inscripcion i) => i.nombreDeporte.isEmpty ? i.deporteCodigo : i.nombreDeporte;

  @override
  Future<void> rechazarReserva(String id, String motivo) async {
    final ref = _db.collection('inscripciones').doc(id);
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final datos = doc.data();
      if (datos?['estado'] != EstadoInscripcion.enRevision.name) {
        throw const ReservaNoRevisableException();
      }
      final refDeporte = _db.collection('deportes').doc(datos!['deporteCodigo'] as String);
      final deporte = await tx.get(refDeporte);
      final ocupados = (deporte.data()?['cuposOcupados'] as num?)?.toInt() ?? 0;
      final pagoId = datos['pagoId'] as String? ?? '';
      if (pagoId.isNotEmpty) {
        tx.update(_db.collection('pagos').doc(pagoId), {'estado': EstadoPago.reembolsado.name});
      }
      if (ocupados > 0) tx.update(refDeporte, {'cuposOcupados': ocupados - 1});
      tx.update(ref, {'estado': EstadoInscripcion.rechazada.name, 'motivo': motivo});
    });
    final reserva = Inscripcion.desdeMapa(id, (await ref.get()).data()!);
    await _avisar(reserva.estudianteId, TipoNotificacion.reservaRechazada,
        'Tu reserva en ${_nombre(reserva)} fue rechazada: $motivo El pago quedó marcado como reembolsado.');
  }

  Future<List<Inscripcion>> _inscripcionesDe(String campo, String valor) async {
    final consulta = await _db.collection('inscripciones').where(campo, isEqualTo: valor).get();
    return [for (final d in consulta.docs) Inscripcion.desdeMapa(d.id, d.data())];
  }

  @override
  Future<void> eliminarDeporte(String codigo) async {
    final ref = _db.collection('deportes').doc(codigo);
    final doc = await ref.get();
    final datos = doc.data();
    if (datos == null) return;
    final deporte = Deporte.desdeMapa(codigo, datos);
    final motivo = ValidacionAdmin.eliminarDeporte(deporte, await _inscripcionesDe('deporteCodigo', codigo));
    if (motivo != null) throw OperacionNoPermitidaException(motivo);
    final horarios = await ref.collection('horarios').get();
    final lote = _db.batch();
    for (final h in horarios.docs) {
      lote.delete(h.reference);
    }
    lote.delete(ref);
    await lote.commit();
  }

  @override
  Future<void> inscribirEstudiante(String codigo, String estudianteUid) async {
    final refDeporte = _db.collection('deportes').doc(codigo);
    final refUsuario = _db.collection('usuarios').doc(estudianteUid);
    final refInscripcion = _db.collection('inscripciones').doc(Inscripcion.idPara(codigo, estudianteUid));
    final horarios = await refDeporte.collection('horarios').get();
    final textoHorarios = [for (final h in horarios.docs) Horario.desdeMapa(h.id, h.data())]
        .map((h) => h.lugar.isEmpty ? h.etiqueta : '${h.etiqueta} · ${h.lugar}')
        .join('\n');
    await _db.runTransaction((tx) async {
      final deporteDoc = await tx.get(refDeporte);
      final usuarioDoc = await tx.get(refUsuario);
      final previa = await tx.get(refInscripcion);
      if (deporteDoc.data() == null) throw const OperacionNoPermitidaException('La disciplina ya no existe.');
      final persona = usuarioDoc.data() == null ? null : Persona.desdeMapa(estudianteUid, usuarioDoc.data()!);
      if (persona is! Estudiante) throw const OperacionNoPermitidaException('Solo se puede inscribir a estudiantes.');
      final deporte = Deporte.desdeMapa(codigo, deporteDoc.data()!);
      final anteriores = [if (previa.data() != null) Inscripcion.desdeMapa(previa.id, previa.data()!)];
      final motivo = ValidacionAdmin.inscribirDirecto(persona, deporte, anteriores);
      if (motivo != null) throw OperacionNoPermitidaException(motivo);
      tx.set(refInscripcion, {
        'estudianteId': estudianteUid,
        'deporteCodigo': codigo,
        'fechaInscripcion': FieldValue.serverTimestamp(),
        'estado': EstadoInscripcion.confirmada.name,
        'motivo': 'Inscrito por la Coordinación de Deportes.',
        'pagoId': '',
        'nombreDeporte': deporte.nombre,
        'horarios': textoHorarios,
        'monto': 0,
        'descripcion': deporte.descripcion,
        'duracion': deporte.duracion,
        'cupoMaximo': deporte.cupoMaximo,
        'sesiones': 0,
        'sesionesAsistidas': 0,
      });
      tx.update(refDeporte, {'cuposOcupados': deporte.cuposOcupados + 1});
    });
    final deporteDoc = await refDeporte.get();
    final nombre = deporteDoc.data()?['nombre'] as String? ?? codigo;
    await _avisar(estudianteUid, TipoNotificacion.inscripcionDirecta,
        'La Coordinación de Deportes te inscribió en $nombre. Ya puedes ver tus horarios en Mi panel.',
        ruta: '/estudiante');
  }

  @override
  Future<void> retirarEstudiante(String inscripcionId) =>
      cancelarReserva(inscripcionId, motivo: 'Retirado por la Coordinación de Deportes.');

  @override
  Future<void> cancelarReserva(String inscripcionId, {required String motivo, bool reembolsar = false}) async {
    final ref = _db.collection('inscripciones').doc(inscripcionId);
    final inscripcion = await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (doc.data() == null) throw const OperacionNoPermitidaException('La reserva ya no existe.');
      final inscripcion = Inscripcion.desdeMapa(doc.id, doc.data()!);
      final error = ValidacionAdmin.cancelarReserva(inscripcion);
      if (error != null) throw OperacionNoPermitidaException(error);
      final refDeporte = _db.collection('deportes').doc(inscripcion.deporteCodigo);
      final deporte = await tx.get(refDeporte);
      final ocupados = (deporte.data()?['cuposOcupados'] as num?)?.toInt() ?? 0;
      if (inscripcion.ocupaCupo && ocupados > 0) tx.update(refDeporte, {'cuposOcupados': ocupados - 1});
      if (reembolsar && inscripcion.pagoId.isNotEmpty) {
        tx.update(_db.collection('pagos').doc(inscripcion.pagoId), {'estado': EstadoPago.reembolsado.name});
      }
      tx.update(ref, {'estado': EstadoInscripcion.cancelada.name, 'motivo': motivo});
      return inscripcion;
    });
    final reembolso = reembolsar && inscripcion.pagoId.isNotEmpty ? ' El pago quedó marcado como reembolsado.' : '';
    await _avisar(inscripcion.estudianteId, TipoNotificacion.retiro,
        'La Coordinación de Deportes canceló tu reserva en ${_nombre(inscripcion)}. Motivo: $motivo$reembolso');
  }

  @override
  Future<void> cambiarReserva(String inscripcionId, String nuevoCodigo) async {
    final ref = _db.collection('inscripciones').doc(inscripcionId);
    final refDestino = _db.collection('deportes').doc(nuevoCodigo);
    final horarios = await refDestino.collection('horarios').get();
    final textoHorarios = [for (final h in horarios.docs) Horario.desdeMapa(h.id, h.data())]
        .map((h) => h.lugar.isEmpty ? h.etiqueta : '${h.etiqueta} · ${h.lugar}')
        .join('\n');
    final (anterior, destino) = await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (doc.data() == null) throw const OperacionNoPermitidaException('La reserva ya no existe.');
      final reserva = Inscripcion.desdeMapa(doc.id, doc.data()!);
      final refNueva = _db.collection('inscripciones').doc(Inscripcion.idPara(nuevoCodigo, reserva.estudianteId));
      final refOrigen = _db.collection('deportes').doc(reserva.deporteCodigo);
      final origenDoc = await tx.get(refOrigen);
      final destinoDoc = await tx.get(refDestino);
      final previa = await tx.get(refNueva);
      if (destinoDoc.data() == null) throw const OperacionNoPermitidaException('La disciplina elegida ya no existe.');
      final destino = Deporte.desdeMapa(nuevoCodigo, destinoDoc.data()!);
      final error = ValidacionAdmin.cambiarReserva(
          reserva, destino, [if (previa.data() != null) Inscripcion.desdeMapa(previa.id, previa.data()!)]);
      if (error != null) throw OperacionNoPermitidaException(error);
      final origen = reserva.nombreDeporte.isEmpty ? reserva.deporteCodigo : reserva.nombreDeporte;
      if (reserva.ocupaCupo) {
        final ocupados = (origenDoc.data()?['cuposOcupados'] as num?)?.toInt() ?? 0;
        if (ocupados > 0) tx.update(refOrigen, {'cuposOcupados': ocupados - 1});
        tx.update(refDestino, {'cuposOcupados': destino.cuposOcupados + 1});
      }
      tx.update(ref, {
        'estado': EstadoInscripcion.cancelada.name,
        'motivo': 'Cambiada a ${destino.nombre} por la Coordinación de Deportes.',
      });
      tx.set(refNueva, {
        'estudianteId': reserva.estudianteId,
        'deporteCodigo': nuevoCodigo,
        'fechaInscripcion': FieldValue.serverTimestamp(),
        'estado': reserva.estado.name,
        'motivo': 'Cambiada desde $origen por la Coordinación de Deportes.',
        'pagoId': reserva.pagoId,
        'nombreDeporte': destino.nombre,
        'horarios': textoHorarios,
        'monto': reserva.monto,
        'descripcion': destino.descripcion,
        'duracion': destino.duracion,
        'cupoMaximo': destino.cupoMaximo,
        'sesiones': 0,
        'sesionesAsistidas': 0,
      });
      return (reserva, destino);
    });
    await _avisar(
        anterior.estudianteId,
        TipoNotificacion.cambioReserva,
        'La Coordinación de Deportes cambió tu reserva de ${_nombre(anterior)} a ${destino.nombre}. '
        'Revisa tus nuevos horarios en Mis inscripciones.');
  }

  @override
  Future<void> eliminarUsuario(String uid) async {
    final refUsuario = _db.collection('usuarios').doc(uid);
    final doc = await refUsuario.get();
    final datos = doc.data();
    if (datos == null) return;
    final persona = Persona.desdeMapa(uid, datos);
    final deportes = persona is Entrenador
        ? [
            for (final d in (await _db.collection('deportes').where('entrenadorId', isEqualTo: uid).get()).docs)
              Deporte.desdeMapa(d.id, d.data())
          ]
        : const <Deporte>[];
    final motivo = ValidacionAdmin.eliminarUsuario(
      persona,
      adminUid: _auth.currentUser?.uid ?? '',
      inscripciones: persona is Estudiante ? await _inscripcionesDe('estudianteId', uid) : const [],
      deportes: deportes,
    );
    if (motivo != null) throw OperacionNoPermitidaException(motivo);
    final lote = _db.batch();
    lote.delete(_db.collection('cedulas').doc(persona.cedulaTexto));
    if (persona is Estudiante && persona.carnet.isNotEmpty) lote.delete(_db.collection('carnets').doc(persona.carnet));
    lote.delete(refUsuario);
    // La marca impide que la cuenta de acceso vuelva a crearse un perfil (ver firestore.rules).
    lote.set(_db.collection('eliminados').doc(uid), {
      'correo': persona.correo,
      'cedula': persona.cedulaTexto,
      'fecha': FieldValue.serverTimestamp(),
    });
    await lote.commit();
  }
}
