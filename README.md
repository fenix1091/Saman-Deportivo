<p align="center"><img width="883" height="408" alt="dasdsdasdsad" src="https://github.com/user-attachments/assets/3aa91aea-9f1e-4c2a-ba14-108b54efddbd" />

# Samán Deportivo

Plataforma web y móvil (PWA) para la gestión de clubes deportivos de la comunidad de la
Universidad Metropolitana (UNIMET). Permite consultar la oferta de disciplinas, ver los cupos
en tiempo real, inscribirse con validación de solvencia y pago en línea, tomar asistencia y
administrar deportes, entrenadores y horarios.

Proyecto Final 2627-1 · Sistemas de Información (FPTSP04) · Prof. Franklin Sandoval.

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
- **Firebase**: Authentication, Cloud Firestore, Cloud Storage, Cloud Functions y Hosting.
- **PayPal** (sandbox) para la reserva de cupos.
- **Figma** para el prototipo: [prototipo en Figma](https://www.figma.com/proto/NnL18RHGqI9u4ddKXQUGnE/Sam%C3%A1n-Deportivo)
- **Ejemplo de la interfaz de figma:**
<img width="543" height="378" alt="image" src="https://github.com/user-attachments/assets/93ba85c3-d422-4f18-9f6e-3536b26eec20" />


## Estructura

```
lib/
  core/          rutas, tema (colores y tipografía), constantes
  models/        Persona, Estudiante, Entrenador, Deporte, Horario, Inscripcion, Pago, Asistencia, Resena
  repositories/  acceso a Firestore, Auth, Storage y Cloud Functions
  viewmodels/    estado de cada pantalla (ChangeNotifier)
  views/         pantallas por rol: publico, estudiante, entrenador, admin
  widgets/       componentes reutilizables
functions/       Cloud Functions (validar solvencia, confirmar pago, estadísticas)
docs/            documentos de OpenUP (docs/hito1) y diagramas UML en PlantUML (docs/uml)
design/          logo y capturas del prototipo en Figma (fundamentos y pantallas)
test/            pruebas unitarias y de widgets
```

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
flutter test                       # modelos, validaciones, ViewModels, rutas y pantallas
cd pruebas_reglas && npm install && npm test   # reglas de Firestore (necesita Java 21)
```

### Reglas de seguridad

Las reglas de Firestore están en `firestore.rules`. Después de cambiarlas hay que publicarlas:

```bash
firebase deploy --only firestore:rules
```

(o copiarlas en la consola de Firebase, en Firestore Database → Reglas).

## Flujo de trabajo

- `main`: versión estable, se actualiza al cerrar cada hito.
- `develop`: integración de funcionalidades terminadas.
- `feature/<nombre>`: una rama por funcionalidad; se integra a `develop` con un pull request
  revisado por otro integrante.
- Mensajes de commit con prefijo: `feat`, `fix`, `docs`, `style`, `refactor`, `test`.

Más detalle en [CONTRIBUTING.md](CONTRIBUTING.md).

## Hitos (OpenUP)

- [x] **Hito 1 · Concepción**: visión, requisitos, UML, marca, prototipo y repositorio ([documento en Word](docs/hito1/Hito1_Saman_Deportivo.docx)).
- [ ] **Hito 2 · Elaboración**: arquitectura, Firebase, registro, inicio de sesión y perfil.
- [ ] **Hito 3 · Construcción**: catálogo, inscripciones, entrenadores, administración, pagos y reseñas.
- [ ] **Hito 4 · Transición**: pruebas, PWA, despliegue en Firebase Hosting y manuales.
