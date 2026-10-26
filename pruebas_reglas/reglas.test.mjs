// Pruebas de las reglas de seguridad de Firestore (seguridad de los perfiles).
// Ejecutar con: npm test   (levanta el emulador de Firestore; requiere Java 11+)
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDoc, getDocs, increment, query, runTransaction, serverTimestamp, setDoc, Timestamp, updateDoc,
  where, writeBatch,
} from 'firebase/firestore';

let entorno;

const perfilEstudiante = (correo, extra = {}) => ({
  rol: 'estudiante',
  cedula: 'V-31985476',
  nombre: 'Vincenzo Gallo',
  correo,
  telefono: '',
  fotoUrl: '',
  carnet: '20221110045',
  estado: 'activo',
  solvente: false,
  carrera: '',
  creadoEn: serverTimestamp(),
  ...extra,
});

/** Escribe el perfil y sus índices en un lote, igual que AuthRepositoryFirebase. */
function registrar(db, uid, perfil, cedula = perfil.cedula, carnet = perfil.carnet) {
  const lote = writeBatch(db);
  lote.set(doc(db, 'usuarios', uid), perfil);
  lote.set(doc(db, 'cedulas', cedula), { uid });
  lote.set(doc(db, 'carnets', carnet), { uid });
  return lote.commit();
}

const comoEstudiante = () => entorno.authenticatedContext('est1', { email: 'est1@correo.unimet.edu.ve' }).firestore();
const comoOtroEstudiante = () => entorno.authenticatedContext('est2', { email: 'est2@correo.unimet.edu.ve' }).firestore();
const comoEntrenador = () => entorno.authenticatedContext('ent1', { email: 'ent1@unimet.edu.ve' }).firestore();
const comoAdmin = () => entorno.authenticatedContext('adm1', { email: 'adm1@unimet.edu.ve' }).firestore();
const sinSesion = () => entorno.unauthenticatedContext().firestore();

before(async () => {
  entorno = await initializeTestEnvironment({
    projectId: 'demo-saman-deportivo',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});

after(() => entorno.cleanup());

beforeEach(async () => {
  await entorno.clearFirestore();
  // Datos iniciales escritos sin reglas (como lo haría la consola de Firebase).
  await entorno.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const base = { telefono: '', fotoUrl: '' };
    await setDoc(doc(db, 'usuarios/est1'), { ...base, rol: 'estudiante', cedula: 'V-1', nombre: 'Uno', correo: 'est1@correo.unimet.edu.ve', carnet: '1', estado: 'activo', solvente: false, carrera: '' });
    await setDoc(doc(db, 'usuarios/est2'), { ...base, rol: 'estudiante', cedula: 'V-2', nombre: 'Dos', correo: 'est2@correo.unimet.edu.ve', carnet: '2', estado: 'activo', solvente: false, carrera: '' });
    await setDoc(doc(db, 'usuarios/ent1'), { ...base, rol: 'entrenador', cedula: 'V-3', nombre: 'Tres', correo: 'ent1@unimet.edu.ve', especialidad: 'Fútbol', aniosExperiencia: 5 });
    await setDoc(doc(db, 'usuarios/adm1'), { ...base, rol: 'administrador', cedula: 'V-4', nombre: 'Cuatro', correo: 'adm1@unimet.edu.ve', cargo: 'Coordinación' });
    await setDoc(doc(db, 'cedulas/V-1'), { uid: 'est1' });
    await setDoc(doc(db, 'carnets/1'), { uid: 'est1' });
    await setDoc(doc(db, 'deportes/FUT-01'), { nombre: 'Fútbol', cupoMaximo: 25 });
  });
});

describe('Registro de estudiantes (RF-01)', () => {
  const nuevo = () => entorno.authenticatedContext('nuevo', { email: 'nuevo@correo.unimet.edu.ve' }).firestore();

  test('un estudiante crea su perfil y sus índices de cédula y carnet', async () => {
    await assertSucceeds(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve')));
  });

  test('no puede registrarse como administrador ni como entrenador', async () => {
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { rol: 'administrador' })));
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { rol: 'entrenador' })));
  });

  test('no puede declararse solvente ni inactivo al registrarse', async () => {
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { solvente: true })));
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { estado: 'inactivo' })));
  });

  test('no puede crear el perfil de otra cuenta ni con otro correo', async () => {
    await assertFails(registrar(nuevo(), 'otro', perfilEstudiante('nuevo@correo.unimet.edu.ve')));
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('falso@correo.unimet.edu.ve')));
  });

  test('no puede agregar campos que no son del registro', async () => {
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { cargo: 'Coordinación' })));
  });

  test('una cédula o un carnet ya registrados hacen fallar el registro', async () => {
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { cedula: 'V-1' })));
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { carnet: '1' })));
  });

  test('no puede reservar una cédula que no es la de su perfil', async () => {
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve'), 'V-99999999'));
  });
});

describe('Seguridad de los perfiles (RF-02, RF-03)', () => {
  test('sin sesión no se puede leer ningún perfil', async () => {
    await assertFails(getDoc(doc(sinSesion(), 'usuarios/est1')));
    await assertFails(getDocs(collection(sinSesion(), 'usuarios')));
  });

  test('cada estudiante lee su perfil pero no el de otro ni la lista de usuarios', async () => {
    await assertSucceeds(getDoc(doc(comoEstudiante(), 'usuarios/est1')));
    await assertFails(getDoc(doc(comoEstudiante(), 'usuarios/est2')));
    await assertFails(getDocs(collection(comoEstudiante(), 'usuarios')));
  });

  test('el dueño puede cambiar su teléfono y su foto', async () => {
    await assertSucceeds(updateDoc(doc(comoEstudiante(), 'usuarios/est1'), { telefono: '04141234567', fotoUrl: 'data:image/jpeg;base64,AAAA' }));
  });

  test('el dueño no puede cambiarse el rol, la solvencia, la cédula ni el carnet', async () => {
    const db = comoEstudiante();
    await assertFails(updateDoc(doc(db, 'usuarios/est1'), { rol: 'administrador' }));
    await assertFails(updateDoc(doc(db, 'usuarios/est1'), { solvente: true }));
    await assertFails(updateDoc(doc(db, 'usuarios/est1'), { cedula: 'V-5' }));
    await assertFails(updateDoc(doc(db, 'usuarios/est1'), { carnet: '5' }));
  });

  test('nadie edita ni borra el perfil de otro usuario', async () => {
    await assertFails(updateDoc(doc(comoOtroEstudiante(), 'usuarios/est1'), { telefono: '04140000000' }));
    await assertFails(deleteDoc(doc(comoOtroEstudiante(), 'usuarios/est1')));
    await assertFails(updateDoc(doc(comoEntrenador(), 'usuarios/est1'), { telefono: '04140000000' }));
  });

  test('el entrenador puede consultar los perfiles (para su nómina) pero no editarlos', async () => {
    await assertSucceeds(getDoc(doc(comoEntrenador(), 'usuarios/est1')));
    await assertSucceeds(getDocs(collection(comoEntrenador(), 'usuarios')));
  });

  test('el administrador consulta y edita cualquier perfil (por ejemplo, la solvencia)', async () => {
    await assertSucceeds(getDocs(collection(comoAdmin(), 'usuarios')));
    await assertSucceeds(updateDoc(doc(comoAdmin(), 'usuarios/est1'), { solvente: true }));
  });

  test('una foto que no cabe en el documento se rechaza', async () => {
    await assertFails(updateDoc(doc(comoEstudiante(), 'usuarios/est1'), { fotoUrl: 'x'.repeat(1000001) }));
  });
  test('el administrador crea entrenadores y su índice de cédula, pero otros roles no', async () => {
    const entrenador = {
      rol: 'entrenador',
      cedula: 'V-55555555',
      nombre: 'Nuevo Entrenador',
      correo: 'nuevo@unimet.edu.ve',
      telefono: '',
      fotoUrl: '',
      especialidad: 'Natación',
      aniosExperiencia: 3,
    };
    const crear = (db, uid) => {
      const lote = writeBatch(db);
      lote.set(doc(db, 'usuarios', uid), entrenador);
      lote.set(doc(db, 'cedulas', entrenador.cedula), { uid });
      return lote.commit();
    };
    await assertSucceeds(crear(comoAdmin(), 'ent2'));
    await assertFails(crear(comoEstudiante(), 'ent3'));
    await assertFails(crear(comoAdmin(), 'ent4'));
    await assertFails(setDoc(doc(comoAdmin(), 'usuarios', 'admin-extra'), {
      ...entrenador,
      rol: 'administrador',
      cedula: 'V-66666666',
    }));
  });
});

describe('Estructura base de la gestión deportiva', () => {
  test('el catálogo de deportes es público, pero solo el administrador lo modifica', async () => {
    await assertSucceeds(getDoc(doc(sinSesion(), 'deportes/FUT-01')));
    await assertFails(setDoc(doc(sinSesion(), 'deportes/BAS-01'), { nombre: 'Básquet', cupoMaximo: 20 }));
    await assertFails(setDoc(doc(comoEstudiante(), 'deportes/BAS-01'), { nombre: 'Básquet', cupoMaximo: 20 }));
    await assertFails(updateDoc(doc(comoEntrenador(), 'deportes/FUT-01'), { cupoMaximo: 99 }));
    await assertSucceeds(setDoc(doc(comoAdmin(), 'deportes/BAS-01'), { nombre: 'Básquet', cupoMaximo: 20 }));
  });

  test('solo el administrador configura horarios y asigna entrenadores', async () => {
    const horario = { dia: 'lunes', horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha 1' };
    await assertSucceeds(setDoc(doc(comoAdmin(), 'deportes/FUT-01/horarios/h1'), horario));
    await assertFails(setDoc(doc(comoEstudiante(), 'deportes/FUT-01/horarios/h2'), horario));
    await assertSucceeds(updateDoc(doc(comoAdmin(), 'deportes/FUT-01'), { entrenadorId: 'ent1' }));
    await assertFails(updateDoc(doc(comoEntrenador(), 'deportes/FUT-01'), { entrenadorId: 'ent1' }));
  });

  test('un estudiante no puede escribir inscripciones ni pagos inventados', async () => {
    await assertFails(setDoc(doc(comoEstudiante(), 'inscripciones/i1'), { estudianteId: 'est1', deporteCodigo: 'FUT-01' }));
    await assertFails(setDoc(doc(comoEstudiante(), 'pagos/p1'), { monto: 5 }));
  });
});

describe('Catálogo público (RF-04, RF-05, RF-06)', () => {
  test('cualquiera lee los deportes, sus horarios y sus reseñas', async () => {
    await assertSucceeds(getDocs(collection(sinSesion(), 'deportes')));
    await assertSucceeds(getDocs(collection(sinSesion(), 'deportes/FUT-01/horarios')));
    await assertSucceeds(getDocs(collection(sinSesion(), 'resenas')));
  });

  test('una consulta suma 1 al contador de deportes más buscados, y nada más', async () => {
    await assertSucceeds(updateDoc(doc(sinSesion(), 'deportes/FUT-01'), { vecesBuscado: increment(1) }));
    await assertSucceeds(updateDoc(doc(comoEstudiante(), 'deportes/FUT-01'), { vecesBuscado: increment(1) }));
    await assertFails(updateDoc(doc(sinSesion(), 'deportes/FUT-01'), { vecesBuscado: 1000 }));
    await assertFails(updateDoc(doc(sinSesion(), 'deportes/FUT-01'), { vecesBuscado: increment(1), cupoMaximo: 99 }));
    await assertFails(updateDoc(doc(comoEstudiante(), 'deportes/FUT-01'), { cuposOcupados: 0 }));
  });
});

describe('Validación, cupos y pago de la inscripción (RF-07, RF-08, RF-09)', () => {
  const ID = 'FUT-01_est1';
  const reserva = () => ({
    estudianteId: 'est1', deporteCodigo: 'FUT-01', fechaInscripcion: serverTimestamp(),
    estado: 'pendientePago', motivo: '', pagoId: '',
  });

  /** Escribe sin reglas, como lo haría la consola de Firebase. */
  const preparar = (ruta, datos) =>
    entorno.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), ruta), datos));

  /** Hace lo mismo que InscripcionRepositoryFirebase.confirmarPago, en un lote. */
  function confirmar(db, { cupos = 21, monto = 5, estadoPago = 'completado', estadoInscripcion = 'confirmada' } = {}) {
    const pagoId = `${ID}_${Date.now()}`;
    const lote = writeBatch(db);
    lote.set(doc(db, 'pagos', pagoId), {
      inscripcionId: ID, monto, moneda: 'USD', metodo: 'PayPal', referenciaExterna: 'SANDBOX-1',
      fecha: serverTimestamp(), estado: estadoPago,
    });
    if (cupos !== null) lote.update(doc(db, 'deportes/FUT-01'), { cuposOcupados: cupos });
    lote.update(doc(db, 'inscripciones', ID), estadoInscripcion === 'confirmada'
      ? { estado: 'confirmada', pagoId }
      : { estado: estadoInscripcion, motivo: 'Sin cupo' });
    return lote.commit();
  }

  beforeEach(async () => {
    await preparar('deportes/FUT-01', {
      nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 20, costoReserva: 5, activo: true, entrenadorId: 'ent1',
    });
    await entorno.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'usuarios/est1'), { solvente: true }));
  });

  test('un estudiante activo y solvente reserva su cupo', async () => {
    await assertSucceeds(setDoc(doc(comoEstudiante(), 'inscripciones', ID), reserva()));
    await assertSucceeds(getDoc(doc(comoEstudiante(), 'inscripciones', ID)));
  });

  test('un estudiante no solvente o inactivo no puede reservar, aunque se salte la app (RN-01)', async () => {
    await assertFails(setDoc(doc(comoOtroEstudiante(), 'inscripciones/FUT-01_est2'),
      { ...reserva(), estudianteId: 'est2' }));
    await entorno.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'usuarios/est1'), { estado: 'inactivo' }));
    await assertFails(setDoc(doc(comoEstudiante(), 'inscripciones', ID), reserva()));
  });

  test('no puede reservar a nombre de otro, ni sin cupos, ni dos veces seguidas (RN-02, RN-03)', async () => {
    await assertFails(setDoc(doc(comoEstudiante(), 'inscripciones/FUT-01_est2'), { ...reserva(), estudianteId: 'est2' }));
    await assertFails(setDoc(doc(comoEstudiante(), 'inscripciones', ID), { ...reserva(), estado: 'confirmada' }));
    await assertSucceeds(setDoc(doc(comoEstudiante(), 'inscripciones', ID), reserva()));
    await assertFails(setDoc(doc(comoEstudiante(), 'inscripciones', ID), reserva()));
    await preparar('deportes/FUT-01', { nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 25, activo: true, entrenadorId: 'ent1' });
    await preparar(`inscripciones/${ID}`, { ...reserva(), estado: 'cancelada', fechaInscripcion: Timestamp.now() });
    await assertFails(setDoc(doc(comoEstudiante(), 'inscripciones', ID), reserva()));
  });

  test('otro estudiante no puede ver la inscripción ni el pago', async () => {
    await assertSucceeds(setDoc(doc(comoEstudiante(), 'inscripciones', ID), reserva()));
    await assertFails(getDoc(doc(comoOtroEstudiante(), 'inscripciones', ID)));
    await assertSucceeds(getDoc(doc(comoEntrenador(), 'inscripciones', ID)));
  });

  test('el pago completado confirma la inscripción y ocupa un cupo, todo junto (CU-07, paso 6)', async () => {
    await assertSucceeds(setDoc(doc(comoEstudiante(), 'inscripciones', ID), reserva()));
    await assertSucceeds(confirmar(comoEstudiante()));
  });

  test('no se puede confirmar sin pagar, sin ocupar el cupo, ni pagando otro monto', async () => {
    await assertSucceeds(setDoc(doc(comoEstudiante(), 'inscripciones', ID), reserva()));
    await assertFails(updateDoc(doc(comoEstudiante(), 'inscripciones', ID), { estado: 'confirmada', pagoId: 'x' }));
    await assertFails(confirmar(comoEstudiante(), { cupos: null }));
    await assertFails(confirmar(comoEstudiante(), { cupos: 22 }));
    await assertFails(confirmar(comoEstudiante(), { monto: 0.01 }));
    await assertFails(updateDoc(doc(comoEstudiante(), 'deportes/FUT-01'), { cuposOcupados: 21 }));
  });

  test('nunca se pasa del cupo máximo; sin cupo se rechaza y se reembolsa (RNF-05, CU-07 A5)', async () => {
    await assertSucceeds(setDoc(doc(comoEstudiante(), 'inscripciones', ID), reserva()));
    await preparar('deportes/FUT-01', {
      nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 25, costoReserva: 5, activo: true, entrenadorId: 'ent1',
    });
    await assertFails(confirmar(comoEstudiante(), { cupos: 26 }));
    await assertSucceeds(confirmar(comoEstudiante(), { cupos: null, estadoPago: 'reembolsado', estadoInscripcion: 'rechazada' }));
  });

  test('una reserva vencida no se puede pagar y se puede marcar como expirada (RN-05)', async () => {
    const haceVeinteMinutos = Timestamp.fromMillis(Date.now() - 20 * 60 * 1000);
    await preparar(`inscripciones/${ID}`, { ...reserva(), fechaInscripcion: haceVeinteMinutos });
    await assertFails(confirmar(comoEstudiante()));
    await assertSucceeds(updateDoc(doc(comoEstudiante(), 'inscripciones', ID), { estado: 'expirada', motivo: 'Vencida' }));
    await assertSucceeds(setDoc(doc(comoEstudiante(), 'inscripciones', ID), reserva()));
  });
});

describe('Consultar y cancelar inscripciones, reseñas (RF-10 a RF-13)', () => {
  const sembrar = (estado) => entorno.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'deportes/FUT-01'), { nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 3 });
    await setDoc(doc(db, 'inscripciones/FUT-01_est1'), { estudianteId: 'est1', deporteCodigo: 'FUT-01', estado, motivo: '' });
  });
  const cancelar = (db) => runTransaction(db, async (t) => {
    t.update(doc(db, 'inscripciones/FUT-01_est1'), { estado: 'cancelada' });
    t.update(doc(db, 'deportes/FUT-01'), { cuposOcupados: 2 });
  });
  const resena = { estudianteId: 'est1', autor: 'Uno', deporteCodigo: 'FUT-01', calificacion: 5, comentario: 'Muy bueno', fecha: new Date() };

  test('el estudiante ve sus inscripciones pero no las de otro', async () => {
    await sembrar('confirmada');
    await assertSucceeds(getDocs(query(collection(comoEstudiante(), 'inscripciones'), where('estudianteId', '==', 'est1'))));
    await assertFails(getDoc(doc(comoOtroEstudiante(), 'inscripciones/FUT-01_est1')));
  });

  test('cancelar su inscripción vigente libera un cupo, pero no dos veces ni la de otro', async () => {
    await sembrar('confirmada');
    await assertFails(cancelar(comoOtroEstudiante()));
    await assertSucceeds(cancelar(comoEstudiante()));
    await assertFails(cancelar(comoEstudiante()));
  });

  test('cancelar una reserva pendiente de pago no libera cupo, porque no lo ocupaba (RN-06)', async () => {
    await sembrar('pendientePago');
    await assertFails(cancelar(comoEstudiante()));
    await assertSucceeds(updateDoc(doc(comoEstudiante(), 'inscripciones/FUT-01_est1'), { estado: 'cancelada' }));
  });

  test('no puede liberar cupos sin cancelar ni cambiar otros campos', async () => {
    await sembrar('confirmada');
    await assertFails(updateDoc(doc(comoEstudiante(), 'deportes/FUT-01'), { cuposOcupados: 2 }));
    await assertFails(updateDoc(doc(comoEstudiante(), 'inscripciones/FUT-01_est1'), { estado: 'confirmada', motivo: 'x' }));
  });

  test('solo un inscrito confirmado publica su reseña, de 1 a 5', async () => {
    await sembrar('confirmada');
    await assertSucceeds(setDoc(doc(comoEstudiante(), 'resenas/FUT-01_est1'), resena));
    await assertFails(setDoc(doc(comoEstudiante(), 'resenas/FUT-01_est1'), { ...resena, calificacion: 6 }));
    await assertFails(setDoc(doc(comoOtroEstudiante(), 'resenas/FUT-01_est2'), { ...resena, estudianteId: 'est2' }));
    await assertFails(setDoc(doc(comoOtroEstudiante(), 'resenas/FUT-01_est1'), resena));
  });
});
