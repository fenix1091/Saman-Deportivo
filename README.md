# Samán Deportivo

Plataforma web y móvil (PWA) para la gestión de clubes deportivos de la comunidad de la
Universidad Metropolitana (UNIMET). Permite consultar la oferta de disciplinas, ver los cupos
en tiempo real, inscribirse con validación de solvencia y pago en línea, tomar asistencia y
administrar deportes, entrenadores y horarios.

Proyecto Final 2627-1 · Sistemas de Información (FPTSP04) · Prof. Franklin Sandoval.

**Aplicación publicada:** https://saman-deportivo-7b59f.web.app

## Equipo

| Integrante | Cédula | Rol |
|---|---|---|
| Vincenzo Gallo | V-31.985.476 | Líder de proyecto / Analista |
| Armando Suárez | V-31.623.487 | Desarrollador Flutter (Administrador) / Arquitecto |
| Daniel Da Silva | V-32.560.909 | Desarrollador Flutter (Estudiante y Entrenador) |
| Adriana Julian | V-28.424.728 | Diseñadora UX/UI |
| José Martínez | V-32.504.707 | Desarrollador Firebase |
| Samuel Djekki | V-27.703.521 | Diseñador UX/UI |

Las pruebas y la documentación las comparte todo el equipo.

## Tecnologías

- **Flutter** (web PWA, Android, iOS) con arquitectura MVVM, `provider` y `go_router`.
- **Firebase**: Authentication, Cloud Firestore y Hosting (plan gratuito: sin Storage ni Functions; las
  reglas de seguridad y las transacciones de Firestore hacen de capa de control en el servidor).
- **PayPal** simulado (sandbox) para la reserva de cupos, detrás de la interfaz `PasarelaPago`.
- **Figma** para el prototipo: [prototipo en Figma](https://www.figma.com/proto/NnL18RHGqI9u4ddKXQUGnE/Sam%C3%A1n-Deportivo)
- **Ejemplo de la interfaz de figma:**
<img width="543" height="378" alt="image" src="https://github.com/user-attachments/assets/93ba85c3-d422-4f18-9f6e-3536b26eec20" />


## Estructura

```
lib/
  core/          rutas y guardia por rol (router.dart), tema, validadores de formularios,
                 reglas de negocio de la inscripción (validacion_inscripcion.dart) y del panel (validacion_admin.dart)
  models/        Persona, Estudiante, Entrenador, Administrador, Deporte, Horario, Inscripcion, Pago, Asistencia, Resena
  repositories/  interfaces de acceso a datos y sus implementaciones con Firebase
                 (auth, deportes, inscripciones y pagos, asistencia, administración, pasarela de pago)
  viewmodels/    estado y lógica de cada pantalla (ChangeNotifier)
  views/         pantallas por rol: publico (landing, catálogo, login, registro), comun (perfil),
                 estudiante (panel, inscripción), entrenador (disciplinas, asistencia), admin (resumen, clases,
                 reservas, entrenadores, usuarios) y mis_inscripciones
  widgets/       componentes reutilizables: animaciones (revelado, tarjetas elevables, esqueletos), gráfico de barras,
                 barra de cupos, avatar, acciones de sesión
firestore.rules  reglas de seguridad por rol y por campo
pruebas_reglas/  pruebas de las reglas contra el emulador de Firestore
docs/            documentos de OpenUP (hito1, hito2, hito3) y diagramas UML en PlantUML (docs/uml)
design/          logo y capturas del prototipo en Figma
test/            pruebas unitarias, de ViewModels y de pantallas (con repositorios falsos en test/falsos)
```

## Qué hace la aplicación

- **Visitante**: landing, catálogo con cupos en tiempo real, búsqueda sin acentos y filtros por deporte, categoría,
  día, franja y disponibilidad; detalle de cada disciplina con entrenador, horarios y reseñas.
- **Estudiante**: registro con cédula numérica (V/E) y correo UNIMET, panel con sus reservas y asistencia,
  inscripción con validación de estado y solvencia, control estricto de cupos y pago con PayPal simulado. La reserva
  queda **en revisión** hasta que la Coordinación valida el pago; puede cancelar (libera el cupo) y reseñar una
  disciplina solo después de haber asistido a un entrenamiento.
- **Entrenador**: sus disciplinas asignadas, nómina de inscritos confirmados, toma de asistencia por fecha (corrige
  sin duplicar) e historial con porcentaje por estudiante.
- **Administrador**: resumen con gráficos (deportes más buscados, ocupación, reservas por estado, asistencia),
  disciplinas (crear con código único, editar, dar de baja o eliminar con validación), horarios sin solapamiento,
  revisión de reservas (confirmar o rechazar liberando el cupo), inscritos de cada disciplina (inscribir y retirar),
  entrenadores y usuarios (buscar, solvencia, editar, eliminar con validación).

Los estados de una inscripción son: pendiente de pago → en revisión → confirmada, o rechazada; cancelada y expirada.
Una reserva pendiente vence a los 15 minutos; el cupo se ocupa al recibir el pago y se libera al cancelar o rechazar.

## Cómo ejecutar

```bash
flutter pub get
flutter run -d chrome
```

La app está conectada al proyecto de Firebase `saman-deportivo-7b59f` (web, Android, iOS y
Windows). La configuración está en `lib/firebase_options.dart` y `firebase.json`; si se agrega
otra plataforma, se vuelve a ejecutar `flutterfire configure`.

### Pruebas

```bash
flutter analyze
flutter test                       # modelos, validaciones, ViewModels, rutas y pantallas (con repositorios falsos)
cd pruebas_reglas && npm install && npm test   # reglas de Firestore en el emulador (necesita Java 21)
```

El Plan de Pruebas del Hito 3, con los casos de prueba y su trazabilidad a estas pruebas automáticas, está en
`docs/hito3/`.

### Publicar

La versión web se publica en Firebase Hosting (https://saman-deportivo-7b59f.web.app). Las reglas y el hosting se
publican juntos, para que la app y la base de datos no queden desfasadas:

```bash
flutter build web --release
firebase deploy --only hosting,firestore:rules --project saman-deportivo-7b59f
```

### Reglas de seguridad

Las reglas de Firestore están en `firestore.rules`. Después de cambiarlas hay que publicarlas:

```bash
firebase deploy --only firestore:rules
```

(o copiarlas en la consola de Firebase, en Firestore Database → Reglas).

Desde el panel de administración se pueden crear clases, editar cupos y horarios,
asignar entrenadores y registrar cuentas de entrenador. Firebase envía a cada entrenador
un enlace de restablecimiento para que configure su contraseña; si no llega, el panel
permite reenviarlo. Verifica que la plantilla de restablecimiento esté habilitada en
Firebase Authentication → Plantillas.

## Flujo de trabajo

- `main`: versión estable; es la que se publica en Firebase Hosting.
- `feature/<nombre>`: una rama por funcionalidad; se integra a `main` con un pull request
  revisado por otro integrante.
- Mensajes de commit con prefijo: `feat`, `fix`, `docs`, `style`, `refactor`, `test`.

Más detalle en [CONTRIBUTING.md](CONTRIBUTING.md).

## Hitos (OpenUP)

- [x] **Hito 1 · Concepción**: visión, requisitos, UML, marca, prototipo y repositorio ([documento](docs/hito1/)).
- [x] **Hito 2 · Elaboración**: arquitectura, patrones, Firebase, registro, inicio de sesión y perfil ([documento](docs/hito2/)).
- [x] **Hito 3 · Construcción**: catálogo, inscripciones con revisión del pago, entrenadores, administración completa,
  reseñas y dashboards ([Plan de Pruebas](docs/hito3/)).
- [ ] **Hito 4 · Transición**: pruebas, PWA, despliegue en Firebase Hosting y manuales.
