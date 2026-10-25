// Pruebas de las reglas de seguridad de Firestore (seguridad de los perfiles).
// Ejecutar con: npm test   (levanta el emulador de Firestore; requiere Java 11+)
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDoc, getDocs, query, runTransaction, serverTimestamp, setDoc, updateDoc, where, writeBatch,
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

  test('las inscripciones y los pagos quedan cerrados hasta el Hito 3', async () => {
    await assertFails(setDoc(doc(comoEstudiante(), 'inscripciones/i1'), { estudianteId: 'est1', deporteCodigo: 'FUT-01' }));
    await assertFails(setDoc(doc(comoEstudiante(), 'pagos/p1'), { monto: 5 }));
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
  const resena = { estudianteId: 'est1', deporteCodigo: 'FUT-01', calificacion: 5, comentario: 'Muy bueno', fecha: new Date() };

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
