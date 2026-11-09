import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/persona.dart';
import '../viewmodels/auth_view_model.dart';
import 'acciones_sesion.dart';
import 'avatar_usuario.dart';
import 'campana_notificaciones.dart';

/// Naranja profundo de la marca (texto blanco con 5,2:1 de contraste).
const _naranjaProfundo = Color(0xFFC2410C);

/// Destino del menú lateral.
class DestinoMenu {
  const DestinoMenu({
    required this.etiqueta,
    required this.icono,
    required this.iconoActivo,
    required this.ruta,
    this.prefijos = const [],
  });

  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
  final String ruta;

  /// Otras rutas que también marcan este destino como activo.
  final List<String> prefijos;

  bool activo(String rutaActual) =>
      rutaActual == ruta || rutaActual.startsWith('$ruta/') || prefijos.any(rutaActual.startsWith);
}

/// Menú de cada rol. El visitante no tiene menú: ve la barra superior normal.
List<DestinoMenu> destinosDe(Rol rol) => switch (rol) {
      Rol.estudiante => const [
          DestinoMenu(
              etiqueta: 'Inicio',
              icono: Icons.space_dashboard_outlined,
              iconoActivo: Icons.space_dashboard,
              ruta: '/estudiante',
              prefijos: []),
          DestinoMenu(
              etiqueta: 'Catálogo',
              icono: Icons.search,
              iconoActivo: Icons.search,
              ruta: '/catalogo',
              prefijos: ['/estudiante/inscribir']),
          DestinoMenu(
              etiqueta: 'Inscripciones',
              icono: Icons.assignment_outlined,
              iconoActivo: Icons.assignment,
              ruta: '/mis-inscripciones'),
          DestinoMenu(
              etiqueta: 'Perfil',
              icono: Icons.account_circle_outlined,
              iconoActivo: Icons.account_circle,
              ruta: '/perfil'),
        ],
      Rol.entrenador => const [
          DestinoMenu(
              etiqueta: 'Inicio',
              icono: Icons.space_dashboard_outlined,
              iconoActivo: Icons.space_dashboard,
              ruta: '/entrenador/mis-deportes',
              prefijos: ['/entrenador/asistencia']),
          DestinoMenu(etiqueta: 'Catálogo', icono: Icons.search, iconoActivo: Icons.search, ruta: '/catalogo'),
          DestinoMenu(
              etiqueta: 'Perfil',
              icono: Icons.account_circle_outlined,
              iconoActivo: Icons.account_circle,
              ruta: '/perfil'),
        ],
      Rol.administrador => const [
          DestinoMenu(
              etiqueta: 'Resumen',
              icono: Icons.insights_outlined,
              iconoActivo: Icons.insights,
              ruta: '/admin/resumen',
              prefijos: ['/admin/dashboard']),
          DestinoMenu(
              etiqueta: 'Clases y horarios',
              icono: Icons.event_available_outlined,
              iconoActivo: Icons.event_available,
              ruta: '/admin/clases'),
          DestinoMenu(
              etiqueta: 'Reservas',
              icono: Icons.fact_check_outlined,
              iconoActivo: Icons.fact_check,
              ruta: '/admin/reservas'),
          DestinoMenu(
              etiqueta: 'Entrenadores',
              icono: Icons.groups_outlined,
              iconoActivo: Icons.groups,
              ruta: '/admin/entrenadores'),
          DestinoMenu(
              etiqueta: 'Usuarios',
              icono: Icons.manage_accounts_outlined,
              iconoActivo: Icons.manage_accounts,
              ruta: '/admin/usuarios'),
          DestinoMenu(etiqueta: 'Catálogo', icono: Icons.search, iconoActivo: Icons.search, ruta: '/catalogo'),
          DestinoMenu(
              etiqueta: 'Perfil',
              icono: Icons.account_circle_outlined,
              iconoActivo: Icons.account_circle,
              ruta: '/perfil'),
        ],
    };

/// Armazón de las pantallas con sesión: menú lateral con los colores y el logo
/// de Samán Deportivo a la izquierda y el contenido a la derecha.
///
/// - Escritorio (≥ 1024 px): barra lateral ancha con icono y texto.
/// - Tableta (720–1023 px): barra estrecha con icono y texto pequeño.
/// - Teléfono (< 720 px): barra inferior con los destinos principales.
/// Sin sesión se muestra un Scaffold normal con [AccionesSesion] en la barra superior.
class PanelConMenu extends StatelessWidget {
  const PanelConMenu({
    super.key,
    required this.titulo,
    required this.body,
    this.bottom,
    this.leading,
    this.acciones = const [],
    this.bottomNavigationBar,
  });

  final Widget titulo;
  final Widget body;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final List<Widget> acciones;

  /// Barra inferior propia de la pantalla (por ejemplo, el botón Inscribirme);
  /// en el teléfono se muestra encima del menú inferior.
  final Widget? bottomNavigationBar;

  static const anchoEscritorio = 1024.0;
  static const anchoTableta = 720.0;

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthViewModel>().usuario;
    if (usuario == null) {
      return Scaffold(
        appBar: AppBar(title: titulo, leading: leading, bottom: bottom, actions: const [AccionesSesion()]),
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      );
    }
    final destinos = destinosDe(usuario.rol);
    final rutaActual = GoRouterState.of(context).uri.path;
    final ancho = MediaQuery.sizeOf(context).width;

    if (ancho < anchoTableta) {
      final principales = destinos.take(5).toList();
      final indice = principales.indexWhere((d) => d.activo(rutaActual));
      return Scaffold(
        appBar: AppBar(
            title: titulo,
            leading: leading,
            bottom: bottom,
            actions: [...acciones, const CampanaNotificaciones(), const AccionesSesion()]),
        body: body,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bottomNavigationBar != null) bottomNavigationBar!,
            NavigationBar(
              selectedIndex: indice < 0 ? 0 : indice,
              indicatorColor: AppColors.naranjaClaro,
              onDestinationSelected: (i) => context.go(principales[i].ruta),
              destinations: [
                for (final d in principales)
                  NavigationDestination(
                      icon: Icon(d.icono),
                      selectedIcon: Icon(d.iconoActivo, color: _naranjaProfundo),
                      label: d.etiqueta),
              ],
            ),
          ],
        ),
      );
    }

    final extendido = ancho >= anchoEscritorio;
    return Scaffold(
      body: Row(
        children: [
          _BarraLateral(usuario: usuario, destinos: destinos, rutaActual: rutaActual, extendida: extendido),
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                  title: titulo,
                  leading: leading,
                  automaticallyImplyLeading: leading != null,
                  bottom: bottom,
                  actions: [
                    ...acciones,
                    const Padding(padding: EdgeInsets.only(right: 8), child: CampanaNotificaciones())
                  ]),
              body: body,
              bottomNavigationBar: bottomNavigationBar,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraLateral extends StatelessWidget {
  const _BarraLateral(
      {required this.usuario, required this.destinos, required this.rutaActual, required this.extendida});

  final Persona usuario;
  final List<DestinoMenu> destinos;
  final String rutaActual;
  final bool extendida;

  static String _rol(Rol rol) => switch (rol) {
        Rol.estudiante => 'Estudiante',
        Rol.entrenador => 'Entrenador',
        Rol.administrador => 'Administración',
      };

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final animar = !MediaQuery.of(context).disableAnimations;
    return AnimatedContainer(
      duration: Duration(milliseconds: animar ? 220 : 0),
      curve: Curves.easeOutCubic,
      width: extendida ? 264 : 92,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE3E8EE))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(extendida ? 20 : 14, 18, extendida ? 20 : 14, 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.go('/'),
                child: extendida
                    ? Image.asset('design/marca/logo_horizontal.png',
                        height: 54, fit: BoxFit.contain, alignment: Alignment.centerLeft)
                    : Image.asset('design/marca/logo_icono.png', height: 44),
              ),
            ),
            if (extendida)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 6),
                child: Text(_rol(usuario.rol).toUpperCase(),
                    style: textos.labelSmall
                        ?.copyWith(color: AppColors.gris, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: extendida ? 12 : 10, vertical: 4),
                children: [
                  for (final d in destinos) _Item(destino: d, activo: d.activo(rutaActual), extendido: extendida),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(extendida ? 12 : 10),
              child: extendida
                  ? Row(
                      children: [
                        AvatarUsuario(nombre: usuario.nombreCompleto, fotoUrl: usuario.fotoUrl, radio: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(usuario.nombreCompleto,
                                  style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(usuario.correo,
                                  style: textos.bodySmall?.copyWith(color: AppColors.gris),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar sesión',
                          icon: const Icon(Icons.logout),
                          onPressed: () => context.read<AuthViewModel>().cerrarSesion(),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        AvatarUsuario(nombre: usuario.nombreCompleto, fotoUrl: usuario.fotoUrl, radio: 18),
                        const SizedBox(height: 6),
                        IconButton(
                          tooltip: 'Cerrar sesión',
                          icon: const Icon(Icons.logout),
                          onPressed: () => context.read<AuthViewModel>().cerrarSesion(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatefulWidget {
  const _Item({required this.destino, required this.activo, required this.extendido});

  final DestinoMenu destino;
  final bool activo;
  final bool extendido;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.destino;
    final activo = widget.activo;
    final color = activo ? _naranjaProfundo : AppColors.texto;
    final fondo = activo
        ? AppColors.naranjaClaro
        : _encima
            ? const Color(0xFFF4F6F4)
            : Colors.transparent;
    final hijo = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: EdgeInsets.symmetric(horizontal: widget.extendido ? 14 : 0, vertical: widget.extendido ? 12 : 10),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: activo ? AppColors.naranja : Colors.transparent, width: 3)),
      ),
      child: widget.extendido
          ? Row(
              children: [
                Icon(activo ? d.iconoActivo : d.icono, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    d.etiqueta,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: color, fontWeight: activo ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Icon(activo ? d.iconoActivo : d.icono, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  d.etiqueta,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: color, fontWeight: activo ? FontWeight.w700 : FontWeight.w500, height: 1.1),
                ),
              ],
            ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: Semantics(
        button: true,
        selected: activo,
        label: d.etiqueta,
        child: Tooltip(
          message: widget.extendido ? '' : d.etiqueta,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.go(d.ruta),
            child: hijo,
          ),
        ),
      ),
    );
  }
}
