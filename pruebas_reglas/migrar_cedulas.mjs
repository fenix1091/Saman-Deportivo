// Pasa la cédula de los usuarios que ya existen de texto ("V-31985476") a número
// (cedula: 31985476, nacionalidad: 'V'), para que se pueda ordenar y filtrar por rangos.
// Entra con la cuenta del administrador, porque las reglas solo le dejan editar perfiles ajenos.
//
//   PowerShell:  $env:ADMIN_CORREO="..."; $env:ADMIN_CLAVE="..."; node migrar_cedulas.mjs
//   Git Bash:    ADMIN_CORREO=... ADMIN_CLAVE=... node migrar_cedulas.mjs
//
// Los usuarios que ya tienen la cédula como número no se tocan, así que se puede ejecutar varias veces.
// Los índices cedulas/{V-31985476} no cambian: su id sigue siendo la letra y el número.
import { readFileSync } from 'node:fs';
import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { collection, getDocs, getFirestore, writeBatch } from 'firebase/firestore';

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

const usuarios = await getDocs(collection(db, 'usuarios'));
let lote = writeBatch(db);
let enLote = 0;
let cambiados = 0;
for (const usuario of usuarios.docs) {
  const { cedula, nacionalidad } = usuario.data();
  if (typeof cedula === 'number' && nacionalidad) continue;
  const texto = String(cedula ?? '').toUpperCase();
  const numero = Number.parseInt(texto.replace(/\D/g, ''), 10);
  if (!Number.isInteger(numero) || numero <= 0) {
    console.warn(`${usuario.id}: cédula "${cedula}" no se pudo leer, se deja como está.`);
    continue;
  }
  const letra = nacionalidad ?? (texto.startsWith('E') ? 'E' : 'V');
  lote.update(usuario.ref, { cedula: numero, nacionalidad: letra });
  console.log(`${usuario.id}: "${cedula}" -> ${letra} ${numero}`);
  cambiados++;
  if (++enLote === 400) {
    await lote.commit();
    lote = writeBatch(db);
    enLote = 0;
  }
}
if (enLote > 0) await lote.commit();

console.log(`Listo: ${cambiados} de ${usuarios.size} usuario(s) actualizados.`);
await signOut(auth);
process.exit(0);
