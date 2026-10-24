# Cómo contribuir

## Antes de empezar una tarea

1. Toma la tarea en Trello y muévela a "En progreso".
2. Actualiza `develop`: `git checkout develop && git pull`.
3. Crea tu rama: `git checkout -b feature/nombre-corto` (por ejemplo `feature/catalogo-filtros`).

## Commits

Mensajes cortos, en español y con prefijo:

| Prefijo | Uso |
|---|---|
| `feat:` | nueva funcionalidad |
| `fix:` | corrección de un error |
| `docs:` | documentación o diagramas |
| `style:` | formato, sin cambios de lógica |
| `refactor:` | reorganización del código sin cambiar su comportamiento |
| `test:` | pruebas |

Ejemplo: `feat: filtro por disponibilidad de cupos en el catálogo`

## Pull requests

1. Antes de subir: `flutter analyze` sin errores y `flutter test` en verde.
2. Sube tu rama y abre el pull request hacia `develop`.
3. Otro integrante lo revisa y lo aprueba antes de integrarlo.
4. Enlaza el pull request en la tarjeta de Trello.

## Convenciones de código

- Patrón MVVM: las vistas no acceden a Firebase directamente; usan su ViewModel, y este un repositorio.
- Archivos en `snake_case.dart`, clases en `PascalCase`, variables en `camelCase`.
- Documenta las clases y los métodos públicos con `///`.
- Los colores y textos de estilo se toman de `lib/core/theme.dart`, nunca se escriben a mano en las vistas.
