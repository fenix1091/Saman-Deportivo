// RNF-02: guarda la aplicación en el navegador para poder abrirla sin conexión.
//
// Siempre se pide primero a la red (así nunca se queda una versión vieja después
// de publicar) y solo si no hay conexión se usa la copia guardada. Los datos del
// catálogo los guarda aparte Firestore (persistencia en el navegador).
const CACHE = 'saman-sin-conexion-v1';

// Lo mínimo para arrancar; el resto se guarda la primera vez que se descarga.
const INICIALES = ['./', 'index.html', 'flutter_bootstrap.js', 'main.dart.js', 'manifest.json',
  'favicon.png', 'icons/Icon-192.png'];

// Orígenes externos que la app necesita para pintarse (motor de Flutter y fuentes).
const EXTERNOS = ['https://www.gstatic.com/flutter-canvaskit/', 'https://fonts.gstatic.com/',
  'https://fonts.googleapis.com/'];

function sePuedeGuardar(url) {
  if (url.origin === self.location.origin) return true;
  return EXTERNOS.some((prefijo) => url.href.startsWith(prefijo));
}

self.addEventListener('install', (evento) => {
  evento.waitUntil(caches.open(CACHE).then((c) => c.addAll(INICIALES)).catch(() => {}));
  self.skipWaiting();
});

self.addEventListener('activate', (evento) => {
  evento.waitUntil((async () => {
    for (const nombre of await caches.keys()) {
      if (nombre !== CACHE) await caches.delete(nombre);
    }
    await self.clients.claim();
  })());
});

// La página avisa qué archivos ya descargó antes de que este guardián tomara el
// control, para guardarlos también desde la primera visita.
self.addEventListener('message', (evento) => {
  const datos = evento.data || {};
  if (datos.tipo !== 'guardar' || !Array.isArray(datos.urls)) return;
  evento.waitUntil(caches.open(CACHE).then((c) => Promise.all(datos.urls.map(async (texto) => {
    try {
      const url = new URL(texto);
      if (!sePuedeGuardar(url) || (await c.match(url.href))) return;
      const respuesta = await fetch(url.href, { mode: url.origin === self.location.origin ? 'same-origin' : 'no-cors' });
      if (respuesta.ok || respuesta.type === 'opaque') await c.put(url.href, respuesta);
    } catch (_) {}
  }))));
});

self.addEventListener('fetch', (evento) => {
  const pedido = evento.request;
  if (pedido.method !== 'GET') return;
  const url = new URL(pedido.url);
  const esPagina = pedido.mode === 'navigate';
  if (!esPagina && !sePuedeGuardar(url)) return;
  evento.respondWith((async () => {
    const cache = await caches.open(CACHE);
    try {
      const respuesta = await fetch(pedido);
      // Una ruta de la app que el servidor no conoce abre la app guardada.
      if (esPagina && respuesta.status === 404) {
        const app = await cache.match('index.html');
        if (app) return app;
      }
      if (respuesta.ok || respuesta.type === 'opaque') {
        cache.put(esPagina ? 'index.html' : pedido, respuesta.clone()).catch(() => {});
      }
      return respuesta;
    } catch (error) {
      // Sin conexión: cualquier ruta de la app (/catalogo, /catalogo/FUT-01...) abre index.html.
      const guardada = esPagina
        ? (await cache.match('index.html')) || (await cache.match('./'))
        : await cache.match(pedido, { ignoreSearch: url.origin === self.location.origin });
      if (guardada) return guardada;
      throw error;
    }
  })());
});
