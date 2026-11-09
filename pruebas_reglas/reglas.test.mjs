// Pruebas de las reglas de seguridad de Firestore (seguridad de los perfiles).
// Ejecutar con: npm test   (levanta el emulador de Firestore; requiere Java 11+)
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  and, collection, deleteDoc, doc, getDoc, getDocs, increment, or, query, runTransaction, serverTimestamp, setDoc, Timestamp, updateDoc,
  where, writeBatch,
} from 'firebase/firestore';

let entorno;

const perfilEstudiante = (correo, extra = {}) => ({
  rol: 'estudiante',
  nacionalidad: 'V',
  cedula: 31985476,
  nombre: 'Vincenzo',
  apellido: 'Gallo',
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
function registrar(db, uid, perfil, cedula = `${perfil.nacionalidad}-${perfil.cedula}`, carnet = perfil.carnet) {
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
    await setDoc(doc(db, 'usuarios/est1'), { ...base, rol: 'estudiante', nacionalidad: 'V', cedula: 1, nombre: 'Uno', apellido: 'Prueba', correo: 'est1@correo.unimet.edu.ve', carnet: '1', estado: 'activo', solvente: false, carrera: '' });
    await setDoc(doc(db, 'usuarios/est2'), { ...base, rol: 'estudiante', nacionalidad: 'V', cedula: 2, nombre: 'Dos', apellido: 'Prueba', correo: 'est2@correo.unimet.edu.ve', carnet: '2', estado: 'activo', solvente: false, carrera: '' });
    await setDoc(doc(db, 'usuarios/ent1'), { ...base, rol: 'entrenador', nacionalidad: 'V', cedula: 3, nombre: 'Tres', apellido: 'Prueba', correo: 'ent1@unimet.edu.ve', especialidad: 'Fútbol', aniosExperiencia: 5 });
    await setDoc(doc(db, 'usuarios/adm1'), { ...base, rol: 'administrador', nacionalidad: 'V', cedula: 4, nombre: 'Cuatro', apellido: 'Prueba', correo: 'adm1@unimet.edu.ve', cargo: 'Coordinación' });
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

  test('solo se registran correos de la universidad', async () => {
    const externo = entorno.authenticatedContext('externo', { email: 'alguien@gmail.com' }).firestore();
    await assertFails(registrar(externo, 'externo', perfilEstudiante('alguien@gmail.com')));
    const parecido = entorno.authenticatedContext('parecido', { email: 'alguien@unimet.edu.ve.com' }).firestore();
    await assertFails(registrar(parecido, 'parecido', perfilEstudiante('alguien@unimet.edu.ve.com')));
    const personal = entorno.authenticatedContext('personal', { email: 'docente@unimet.edu.ve' }).firestore();
    await assertSucceeds(registrar(personal, 'personal', perfilEstudiante('docente@unimet.edu.ve')));
  });

  test('una cuenta cuyo perfil fue eliminado no puede volver a crearlo', async () => {
    await assertSucceeds(setDoc(doc(comoAdmin(), 'eliminados/nuevo'), { correo: 'nuevo@correo.unimet.edu.ve', cedula: 'V-31985476', fecha: serverTimestamp() }));
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve')));
    await assertFails(getDoc(doc(nuevo(), 'eliminados/nuevo')));
    await assertFails(deleteDoc(doc(comoEstudiante(), 'eliminados/nuevo')));
  });

  test('no puede agregar campos que no son del registro', async () => {
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { cargo: 'Coordinación' })));
  });

  test('una cédula o un carnet ya registrados hacen fallar el registro', async () => {
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { cedula: 1 })));
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { carnet: '1' })));
  });

  test('el registro exige el nombre y el apellido por separado', async () => {
    const { apellido, ...sinApellido } = perfilEstudiante('nuevo@correo.unimet.edu.ve');
    await assertFails(registrar(nuevo(), 'nuevo', sinApellido, 'V-31985476'));
  });

  test('la cédula se guarda como número y con su letra (V o E)', async () => {
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { cedula: '31985476' }), 'V-31985476'));
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { nacionalidad: 'X' })));
    await assertFails(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { cedula: -5 })));
    await assertSucceeds(registrar(nuevo(), 'nuevo', perfilEstudiante('nuevo@correo.unimet.edu.ve', { nacionalidad: 'E' })));
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

  test('el dueño puede cambiar su nombre, su apellido, su teléfono y su foto', async () => {
    await assertSucceeds(updateDoc(doc(comoEstudiante(), 'usuarios/est1'), { telefono: '04141234567', fotoUrl: 'data:image/jpeg;base64,AAAA' }));
    await assertSucceeds(updateDoc(doc(comoEstudiante(), 'usuarios/est1'), { nombre: 'Uno', apellido: 'Cambiado' }));
  });

  test('nombre y apellido no pueden quedar vacíos, ser muy largos ni dejar de ser texto', async () => {
    const db = comoEstudiante();
    await assertFails(updateDoc(doc(db, 'usuarios/est1'), { nombre: '' }));
    await assertFails(updateDoc(doc(db, 'usuarios/est1'), { apellido: '' }));
    await assertFails(updateDoc(doc(db, 'usuarios/est1'), { nombre: 'x'.repeat(41) }));
    await assertFails(updateDoc(doc(db, 'usuarios/est1'), { apellido: 12345 }));
  });

  test('el dueño no puede cambiarse el rol, la solvencia, la cédula ni el carnet', async () => {
    const db = comoEstudiante();
    await assertFails(updateDoc(doc(db, 'usuarios/est1'), { rol: 'administrador' }));
    await assertFails(updateDoc(doc(db, 'usuarios/est1'), { solvente: true }));
    await assertFails(updateDoc(doc(db, 'usuarios/est1'), { cedula: 5 }));
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
    // Con la cédula numérica se puede filtrar por rangos.
    const rango = await assertSucceeds(getDocs(query(collection(comoAdmin(), 'usuarios'), where('cedula', '>=', 2), where('cedula', '<=', 3))));
    if (rango.size !== 2) throw new Error(`se esperaban 2 usuarios en el rango y llegaron ${rango.size}`);
    await assertSucceeds(updateDoc(doc(comoAdmin(), 'usuarios/est1'), { solvente: true }));
  });

  test('una foto que no cabe en el documento se rechaza', async () => {
    await assertFails(updateDoc(doc(comoEstudiante(), 'usuarios/est1'), { fotoUrl: 'x'.repeat(1000001) }));
  });
  test('el administrador crea entrenadores y su índice de cédula, pero otros roles no', async () => {
    const entrenador = {
      rol: 'entrenador',
      nacionalidad: 'V',
      cedula: 55555555,
      nombre: 'Nuevo',
      apellido: 'Entrenador',
      correo: 'nuevo@unimet.edu.ve',
      telefono: '',
      fotoUrl: '',
      especialidad: 'Natación',
      aniosExperiencia: 3,
    };
    const crear = (db, uid) => {
      const lote = writeBatch(db);
      lote.set(doc(db, 'usuarios', uid), entrenador);
      lote.set(doc(db, 'cedulas', `V-${entrenador.cedula}`), { uid });
      return lote.commit();
    };
    await assertSucceeds(crear(comoAdmin(), 'ent2'));
    await assertFails(crear(comoEstudiante(), 'ent3'));
    await assertFails(crear(comoAdmin(), 'ent4'));
    await assertFails(setDoc(doc(comoAdmin(), 'usuarios', 'admin-extra'), {
      ...entrenador,
      rol: 'administrador',
      cedula: 66666666,
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
  function confirmar(db, { cupos = 21, monto = 5, estadoPago = 'completado', estadoInscripcion = 'enRevision' } = {}) {
    const pagoId = `${ID}_${Date.now()}`;
    const lote = writeBatch(db);
    lote.set(doc(db, 'pagos', pagoId), {
      inscripcionId: ID, monto, moneda: 'USD', metodo: 'PayPal', referenciaExterna: 'SANDBOX-1',
      fecha: serverTimestamp(), estado: estadoPago,
    });
    if (cupos !== null) lote.update(doc(db, 'deportes/FUT-01'), { cuposOcupados: cupos });
    lote.update(doc(db, 'inscripciones', ID), estadoInscripcion === 'enRevision' || estadoInscripcion === 'confirmada'
      ? { estado: estadoInscripcion, pagoId }
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

  test('el pago completado deja la reserva en revisión y ocupa un cupo, todo junto (CU-07, paso 6)', async () => {
    await assertSucceeds(setDoc(doc(comoEstudiante(), 'inscripciones', ID), reserva()));
    await assertSucceeds(confirmar(comoEstudiante()));
  });

  test('el estudiante no puede confirmarse a sí mismo: pagar no salta la revisión', async () => {
    await assertSucceeds(setDoc(doc(comoEstudiante(), 'inscripciones', ID), reserva()));
    await assertFails(confirmar(comoEstudiante(), { estadoInscripcion: 'confirmada' }));
  });

  test('la reserva guarda la copia de los datos del deporte, sin sesiones inventadas', async () => {
    const completa = {
      ...reserva(), nombreDeporte: 'Fútbol', horarios: 'Martes 16:00 - 18:00 · Cancha 1', monto: 5,
      descripcion: 'Selección', duracion: 'Trimestre 2627-1', cupoMaximo: 25, sesiones: 0, sesionesAsistidas: 0,
    };
    await assertSucceeds(setDoc(doc(comoEstudiante(), 'inscripciones', ID), completa));
    await preparar(`inscripciones/${ID}`, { ...completa, estado: 'cancelada', fechaInscripcion: Timestamp.now() });
    await assertFails(setDoc(doc(comoEstudiante(), 'inscripciones', ID), { ...completa, sesionesAsistidas: 3 }));
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

describe('Revisión de reservas por el administrador (Hito 3, punto 4)', () => {
  const ID = 'FUT-01_est1';
  const sembrar = (estado, pagoId = '') => entorno.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'deportes/FUT-01'), { nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 21, costoReserva: 5, activo: true, entrenadorId: 'ent1' });
    await setDoc(doc(db, 'inscripciones', ID), { estudianteId: 'est1', deporteCodigo: 'FUT-01', estado, motivo: '', pagoId, fechaInscripcion: Timestamp.now() });
    if (pagoId) await setDoc(doc(db, 'pagos', pagoId), { inscripcionId: ID, monto: 5, moneda: 'USD', metodo: 'PayPal', referenciaExterna: 'X', fecha: Timestamp.now(), estado: 'completado' });
  });

  test('el administrador confirma una reserva en revisión; el estudiante y el entrenador no', async () => {
    await sembrar('enRevision');
    await assertFails(updateDoc(doc(comoEstudiante(), 'inscripciones', ID), { estado: 'confirmada' }));
    await assertFails(updateDoc(doc(comoEntrenador(), 'inscripciones', ID), { estado: 'confirmada' }));
    await assertSucceeds(updateDoc(doc(comoAdmin(), 'inscripciones', ID), { estado: 'confirmada', motivo: '' }));
  });

  test('el administrador rechaza liberando el cupo y reembolsando el pago', async () => {
    await sembrar('enRevision', `${ID}_1`);
    const db = comoAdmin();
    await assertSucceeds(runTransaction(db, async (t) => {
      t.update(doc(db, 'pagos', `${ID}_1`), { estado: 'reembolsado' });
      t.update(doc(db, 'deportes/FUT-01'), { cuposOcupados: 20 });
      t.update(doc(db, 'inscripciones', ID), { estado: 'rechazada', motivo: 'Pago no validado' });
    }));
  });

  test('el estudiante puede cancelar su reserva en revisión y recupera el cupo', async () => {
    await sembrar('enRevision');
    const db = comoEstudiante();
    await assertSucceeds(runTransaction(db, async (t) => {
      t.update(doc(db, 'inscripciones', ID), { estado: 'cancelada' });
      t.update(doc(db, 'deportes/FUT-01'), { cuposOcupados: 20 });
    }));
  });

  test('una reserva en revisión no sirve todavía para reseñar', async () => {
    await sembrar('enRevision');
    await assertFails(setDoc(doc(comoEstudiante(), 'resenas', ID),
      { estudianteId: 'est1', autor: 'Uno', deporteCodigo: 'FUT-01', calificacion: 5, comentario: 'Bien', fecha: new Date() }));
  });
});

describe('Consultar y cancelar inscripciones, reseñas (RF-10 a RF-13)', () => {
  const sembrar = (estado, extra = { sesiones: 2, sesionesAsistidas: 1 }) => entorno.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'deportes/FUT-01'), { nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 3 });
    await setDoc(doc(db, 'inscripciones/FUT-01_est1'), { estudianteId: 'est1', deporteCodigo: 'FUT-01', estado, motivo: '', ...extra });
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

  test('sin haber asistido a ningún entrenamiento no se puede reseñar (reservó pero no cursó)', async () => {
    await sembrar('confirmada', { sesiones: 0, sesionesAsistidas: 0 });
    await assertFails(setDoc(doc(comoEstudiante(), 'resenas/FUT-01_est1'), resena));
    await sembrar('confirmada', { sesiones: 3, sesionesAsistidas: 0 });
    await assertFails(setDoc(doc(comoEstudiante(), 'resenas/FUT-01_est1'), resena));
  });
});

describe('Gestión del administrador: eliminar e inscribir (Hito 3, puntos 6 a 8)', () => {
  beforeEach(() => entorno.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'deportes/FUT-01'), { nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 3, activo: true, entrenadorId: 'ent1' });
    await setDoc(doc(db, 'deportes/FUT-01/horarios/h1'), { dia: 'martes', horaInicio: '16:00', horaFin: '18:00', lugar: 'Cancha' });
    await setDoc(doc(db, 'inscripciones/FUT-01_est2'), { estudianteId: 'est2', deporteCodigo: 'FUT-01', estado: 'confirmada', motivo: '' });
  }));

  test('solo el administrador elimina una disciplina con sus horarios', async () => {
    await assertFails(deleteDoc(doc(comoEntrenador(), 'deportes/FUT-01')));
    await assertFails(deleteDoc(doc(comoEstudiante(), 'deportes/FUT-01/horarios/h1')));
    const db = comoAdmin();
    const lote = writeBatch(db);
    lote.delete(doc(db, 'deportes/FUT-01/horarios/h1'));
    lote.delete(doc(db, 'deportes/FUT-01'));
    await assertSucceeds(lote.commit());
  });

  test('el administrador inscribe y retira estudiantes directamente; el estudiante no se confirma solo', async () => {
    const db = comoAdmin();
    await assertSucceeds(runTransaction(db, async (t) => {
      t.set(doc(db, 'inscripciones/FUT-01_est1'), {
        estudianteId: 'est1', deporteCodigo: 'FUT-01', fechaInscripcion: serverTimestamp(), estado: 'confirmada',
        motivo: 'Inscrito por la Coordinación de Deportes.', pagoId: '', monto: 0, sesiones: 0, sesionesAsistidas: 0,
      });
      t.update(doc(db, 'deportes/FUT-01'), { cuposOcupados: 4 });
    }));
    await assertFails(setDoc(doc(comoEstudiante(), 'inscripciones/FUT-01_est1'),
      { estudianteId: 'est1', deporteCodigo: 'FUT-01', fechaInscripcion: serverTimestamp(), estado: 'confirmada', motivo: '', pagoId: '' }));
    await assertSucceeds(runTransaction(db, async (t) => {
      t.update(doc(db, 'inscripciones/FUT-01_est2'), { estado: 'cancelada', motivo: 'Retirado por la Coordinación de Deportes.' });
      t.update(doc(db, 'deportes/FUT-01'), { cuposOcupados: 3 });
    }));
  });

  test('solo el administrador elimina un perfil y sus índices', async () => {
    await assertFails(deleteDoc(doc(comoEstudiante(), 'usuarios/est1')));
    await assertFails(deleteDoc(doc(comoEstudiante(), 'cedulas/V-1')));
    const db = comoAdmin();
    const lote = writeBatch(db);
    lote.delete(doc(db, 'cedulas/V-1'));
    lote.delete(doc(db, 'carnets/1'));
    lote.delete(doc(db, 'usuarios/est1'));
    await assertSucceeds(lote.commit());
  });
});

describe('Notificaciones dentro de la app (RF-22)', () => {
  const aviso = (extra = {}) => ({
    paraUid: '', paraRol: 'administrador', deUid: 'est1', tipo: 'reservaRecibida', titulo: 'Nueva reserva por revisar',
    mensaje: 'Un estudiante pagó su reserva en Fútbol.', ruta: '/admin/reservas', fecha: serverTimestamp(), leida: false, ...extra,
  });

  test('un estudiante avisa a los administradores de su reserva, pero no a otras personas ni con otro tipo', async () => {
    await assertSucceeds(setDoc(doc(comoEstudiante(), 'notificaciones/n1'), aviso()));
    await assertFails(setDoc(doc(comoEstudiante(), 'notificaciones/n2'), aviso({ paraUid: 'est2', paraRol: '' })));
    await assertFails(setDoc(doc(comoEstudiante(), 'notificaciones/n3'), aviso({ tipo: 'reservaConfirmada' })));
    await assertFails(setDoc(doc(comoEstudiante(), 'notificaciones/n4'), aviso({ deUid: 'est2' })));
    await assertFails(setDoc(doc(sinSesion(), 'notificaciones/n5'), aviso()));
  });

  test('el administrador avisa a quien quiera; solo el destinatario lee y marca como leído', async () => {
    await assertSucceeds(setDoc(doc(comoAdmin(), 'notificaciones/p1'), aviso({ paraUid: 'est1', paraRol: '', deUid: 'adm1', tipo: 'reservaConfirmada' })));
    await assertSucceeds(getDoc(doc(comoEstudiante(), 'notificaciones/p1')));
    await assertFails(getDoc(doc(comoOtroEstudiante(), 'notificaciones/p1')));
    await assertSucceeds(updateDoc(doc(comoEstudiante(), 'notificaciones/p1'), { leida: true }));
    await assertFails(updateDoc(doc(comoEstudiante(), 'notificaciones/p1'), { mensaje: 'otro' }));
    await assertFails(updateDoc(doc(comoOtroEstudiante(), 'notificaciones/p1'), { leida: true }));
  });

  test('los avisos al rol administrador los lee el administrador y no el estudiante', async () => {
    await entorno.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'notificaciones/r1'), aviso({ fecha: Timestamp.now() })));
    await assertSucceeds(getDoc(doc(comoAdmin(), 'notificaciones/r1')));
    await assertFails(getDoc(doc(comoEstudiante(), 'notificaciones/r1')));
    await assertFails(getDoc(doc(comoEntrenador(), 'notificaciones/r1')));
  });
});

describe('Lista de avisos de la campana (RF-22)', () => {
  const campana = (db, uid, rol) => query(collection(db, 'notificaciones'),
    or(where('paraUid', '==', uid), and(where('paraUid', '==', ''), where('paraRol', '==', rol))));

  beforeEach(() => entorno.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const base = { deUid: 'x', tipo: 'reservaRecibida', titulo: 't', mensaje: 'm', ruta: '/', fecha: Timestamp.now(), leida: false };
    await setDoc(doc(db, 'notificaciones/rolAdmin'), { ...base, paraUid: '', paraRol: 'administrador' });
    await setDoc(doc(db, 'notificaciones/paraEst1'), { ...base, paraUid: 'est1', paraRol: '' });
    await setDoc(doc(db, 'notificaciones/paraEst2'), { ...base, paraUid: 'est2', paraRol: '' });
  }));

  test('cada quien lista sus avisos y los de su rol, como lo pide la app', async () => {
    const delAdmin = await assertSucceeds(getDocs(campana(comoAdmin(), 'adm1', 'administrador')));
    assert.deepEqual(delAdmin.docs.map((d) => d.id), ['rolAdmin']);
    const delEstudiante = await assertSucceeds(getDocs(campana(comoEstudiante(), 'est1', 'estudiante')));
    assert.deepEqual(delEstudiante.docs.map((d) => d.id), ['paraEst1']);
  });

  test('no se pueden listar los avisos de otra persona ni los de otro rol', async () => {
    await assertFails(getDocs(campana(comoEstudiante(), 'est2', 'estudiante')));
    await assertFails(getDocs(campana(comoEstudiante(), 'est1', 'administrador')));
    await assertFails(getDocs(collection(comoEstudiante(), 'notificaciones')));
  });
});

describe('Asistencia del entrenador (RF-14 a RF-16)', () => {
  const ID = 'FUT-01_est1_2026-11-08';
  const asistencia = (extra = {}) => ({
    inscripcionId: 'FUT-01_est1', estudianteId: 'est1', deporteCodigo: 'FUT-01',
    fecha: Timestamp.fromDate(new Date(2026, 10, 8)), estado: 'presente', observacion: '', ...extra,
  });

  beforeEach(() => entorno.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'deportes/FUT-01'), { nombre: 'Fútbol', cupoMaximo: 25, cuposOcupados: 3, activo: true, entrenadorId: 'ent1' });
    await setDoc(doc(db, 'deportes/BAS-01'), { nombre: 'Baloncesto', cupoMaximo: 15, cuposOcupados: 1, activo: true, entrenadorId: 'otro' });
    await setDoc(doc(db, 'inscripciones/FUT-01_est1'), { estudianteId: 'est1', deporteCodigo: 'FUT-01', estado: 'confirmada', motivo: '', sesiones: 0, sesionesAsistidas: 0 });
    await setDoc(doc(db, 'inscripciones/FUT-01_est2'), { estudianteId: 'est2', deporteCodigo: 'FUT-01', estado: 'enRevision', motivo: '', sesiones: 0, sesionesAsistidas: 0 });
    await setDoc(doc(db, 'inscripciones/BAS-01_est1'), { estudianteId: 'est1', deporteCodigo: 'BAS-01', estado: 'confirmada', motivo: '' });
  }));

  test('el entrenador asignado registra la asistencia de sus inscritos confirmados y actualiza los contadores', async () => {
    const db = comoEntrenador();
    await assertSucceeds(runTransaction(db, async (t) => {
      t.set(doc(db, 'asistencias', ID), asistencia());
      t.update(doc(db, 'inscripciones/FUT-01_est1'), { sesiones: 1, sesionesAsistidas: 1 });
    }));
    await assertSucceeds(setDoc(doc(db, 'asistencias', ID), asistencia({ estado: 'ausente' })));
  });

  test('no registra en una disciplina ajena, ni a quien no está confirmado, ni con datos inválidos', async () => {
    const db = comoEntrenador();
    await assertFails(setDoc(doc(db, 'asistencias/BAS-01_est1_2026-11-08'),
      asistencia({ inscripcionId: 'BAS-01_est1', deporteCodigo: 'BAS-01' })));
    await assertFails(setDoc(doc(db, 'asistencias/FUT-01_est2_2026-11-08'),
      asistencia({ inscripcionId: 'FUT-01_est2', estudianteId: 'est2' })));
    await assertFails(setDoc(doc(db, 'asistencias', ID), asistencia({ estado: 'tarde' })));
    await assertFails(setDoc(doc(db, 'asistencias/FUT-01_est1_hoy'), asistencia()));
    await assertFails(updateDoc(doc(db, 'inscripciones/FUT-01_est1'), { sesiones: 1, sesionesAsistidas: 2 }));
    await assertFails(updateDoc(doc(db, 'inscripciones/FUT-01_est1'), { estado: 'cancelada' }));
  });

  test('el estudiante y el administrador no escriben asistencias desde la app del estudiante; el estudiante lee la suya', async () => {
    await entorno.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'asistencias', ID), asistencia()));
    await assertFails(setDoc(doc(comoEstudiante(), 'asistencias/FUT-01_est1_2026-11-09'), asistencia()));
    await assertSucceeds(getDoc(doc(comoEstudiante(), 'asistencias', ID)));
    await assertFails(getDoc(doc(comoOtroEstudiante(), 'asistencias', ID)));
    await assertSucceeds(getDoc(doc(comoEntrenador(), 'asistencias', ID)));
    await assertSucceeds(getDoc(doc(comoAdmin(), 'asistencias', ID)));
    await assertFails(getDoc(doc(sinSesion(), 'asistencias', ID)));
  });
});
