// Carga en Firestore un catálogo de ejemplo para probar la app (deportes con sus horarios).
// Entra con la cuenta del administrador, porque las reglas solo le dejan escribir a él.
//
//   PowerShell:  $env:ADMIN_CORREO="..."; $env:ADMIN_CLAVE="..."; node sembrar_catalogo.mjs
//   Git Bash:    ADMIN_CORREO=... ADMIN_CLAVE=... node sembrar_catalogo.mjs
//
// Los deportes que ya existen no se tocan, así que se puede ejecutar varias veces.
import { readFileSync } from 'node:fs';
import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { collection, doc, getDoc, getDocs, getFirestore, query, where, writeBatch } from 'firebase/firestore';

const CORREO_ENTRENADOR = 'entrenador.prueba@unimet.edu.ve';

const DEPORTES = [
  {
    codigo: 'FUT-01', nombre: 'Fútbol', categoria: 'Colectivo', cupoMaximo: 25, costoReserva: 5,
    descripcion: 'Entrenamientos de fútbol campo para la selección de la UNIMET.',
    horarios: [['martes', '16:00', '18:00', 'Cancha de fútbol'], ['jueves', '16:00', '18:00', 'Cancha de fútbol']],
  },
  {
    codigo: 'BAS-01', nombre: 'Baloncesto', categoria: 'Colectivo', cupoMaximo: 15, costoReserva: 5,
    descripcion: 'Fundamentos, táctica y partidos de práctica.',
    horarios: [['lunes', '18:30', '20:00', 'Gimnasio cubierto'], ['miercoles', '18:30', '20:00', 'Gimnasio cubierto']],
  },
  {
    codigo: 'VOL-01', nombre: 'Voleibol', categoria: 'Colectivo', cupoMaximo: 18, costoReserva: 4,
    descripcion: 'Voleibol de sala, nivel inicial e intermedio.',
    horarios: [['martes', '07:00', '09:00', 'Gimnasio cubierto'], ['viernes', '07:00', '09:00', 'Gimnasio cubierto']],
  },
  {
    codigo: 'TEN-01', nombre: 'Tenis', categoria: 'Raqueta', cupoMaximo: 8, costoReserva: 8,
    descripcion: 'Clases por grupos pequeños; se presta la raqueta.',
    horarios: [['sabado', '09:00', '11:00', 'Canchas de tenis']],
  },
  {
    codigo: 'NAT-01', nombre: 'Natación', categoria: 'Acuático', cupoMaximo: 12, costoReserva: 6,
    descripcion: 'Técnica de los cuatro estilos y resistencia.',
    horarios: [['lunes', '06:30', '08:00', 'Piscina'], ['miercoles', '06:30', '08:00', 'Piscina']],
  },
  {
    codigo: 'AJE-01', nombre: 'Ajedrez', categoria: 'Mental', cupoMaximo: 20, costoReserva: 0,
    descripcion: 'Aperturas, finales y torneos internos.',
    horarios: [['jueves', '12:30', '14:00', 'Sala de usos múltiples']],
  },
];

/** Lee la configuración web de Firebase desde lib/firebase_options.dart. */
function configuracionWeb() {
  const dart = readFileSync(new URL('../lib/firebase_options.dart', import.meta.url), 'utf8');
  const bloque = dart.split('static const FirebaseOptions web = FirebaseOptions(')[1].split(');')[0];
  const valor = (campo) => bloque.match(new RegExp(`${campo}: '([^']+)'`))?.[1];
  return {
    apiKey: valor('apiKey'), appId: valor('appId'), projectId: valor('projectId'),
    authDomain: valor('authDomain'), messagingSenderId: valor('messagingSenderId'),
  };
}

const { ADMIN_CORREO, ADMIN_CLAVE } = process.env;
if (!ADMIN_CORREO || !ADMIN_CLAVE) {
  console.error('Faltan ADMIN_CORREO y ADMIN_CLAVE (la cuenta del administrador).');
  process.exit(1);
}

const app = initializeApp(configuracionWeb());
const auth = getAuth(app);
const db = getFirestore(app);
await signInWithEmailAndPassword(auth, ADMIN_CORREO, ADMIN_CLAVE);

// Datos públicos del entrenador de prueba (ver EntrenadorAsignado en lib/models/deporte.dart).
const encontrados = await getDocs(query(collection(db, 'usuarios'), where('correo', '==', CORREO_ENTRENADOR)));
const entrenadorDoc = encontrados.docs[0];
if (!entrenadorDoc) console.warn(`No existe ${CORREO_ENTRENADOR}; los deportes quedan sin entrenador.`);
const e = entrenadorDoc?.data();

let creados = 0;
for (const d of DEPORTES) {
  const ref = doc(db, 'deportes', d.codigo);
  if ((await getDoc(ref)).exists()) {
    console.log(`${d.codigo} ya existe, no se toca.`);
    continue;
  }
  const lote = writeBatch(db);
  lote.set(ref, {
    nombre: d.nombre, descripcion: d.descripcion, categoria: d.categoria,
    cupoMaximo: d.cupoMaximo, cuposOcupados: 0, costoReserva: d.costoReserva,
    imagenUrl: '', activo: true, vecesBuscado: 0,
    entrenadorId: entrenadorDoc?.id ?? '',
    ...(e && { entrenador: { nombre: e.nombre, especialidad: e.especialidad ?? '', aniosExperiencia: e.aniosExperiencia ?? 0 } }),
  });
  d.horarios.forEach(([dia, horaInicio, horaFin, lugar], i) => {
    lote.set(doc(db, 'deportes', d.codigo, 'horarios', `h${i + 1}`), { dia, horaInicio, horaFin, lugar });
  });
  await lote.commit();
  creados++;
  console.log(`${d.codigo} creado.`);
}

console.log(`Listo: ${creados} deporte(s) nuevo(s).`);
await signOut(auth);
process.exit(0);
