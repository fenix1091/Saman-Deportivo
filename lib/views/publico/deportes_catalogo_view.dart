import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Requerido para la navegación con context.go
import '../../models/deporte.dart';
import '../../viewmodels/deporte_view_model.dart';
import 'deportes_detalle_view.dart';

class DeportesCatalogoView extends StatefulWidget {
  const DeportesCatalogoView({super.key});

  @override
  State<DeportesCatalogoView> createState() => _DeportesCatalogoViewState();
}

class _DeportesCatalogoViewState extends State<DeportesCatalogoView> {
  final DeporteViewModel _vm = DeporteViewModel();
  final TextEditingController _searchController = TextEditingController();
  bool _mostrarFiltrosAvanzados = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            // 1. Botón para regresar al Inicio
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Volver al inicio',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
            ),
            title: const Text('Catálogo de Deportes'),
            elevation: 0,
            actions: [
              // Botón para limpiar filtros
              IconButton(
                tooltip: 'Limpiar filtros',
                icon: const Icon(Icons.filter_alt_off),
                onPressed: () {
                  _searchController.clear();
                  _vm.limpiarFiltros();
                },
              ),
              IconButton(
                tooltip: 'Mis inscripciones',
                icon: const Icon(Icons.assignment_outlined),
                onPressed: () => context.push('/mis-inscripciones'),
              ),
              // 2. Icono de Perfil para editar cuenta (RF-01)
              IconButton(
                tooltip: 'Mi Perfil',
                icon: const Icon(Icons.person),
                onPressed: () => context.go('/perfil'),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barra de Búsqueda Principal
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Buscar por deporte, categoría o descripción...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _mostrarFiltrosAvanzados
                              ? Icons.tune
                              : Icons.tune_outlined,
                          color: _mostrarFiltrosAvanzados
                              ? Theme.of(context).primaryColor
                              : null,
                        ),
                        onPressed: () {
                          setState(() {
                            _mostrarFiltrosAvanzados =
                                !_mostrarFiltrosAvanzados;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) => _vm.actualizarBusqueda(val),
                  ),
                  const SizedBox(height: 10),

                  // Panel de Filtros Avanzados (RF-05)
                  if (_mostrarFiltrosAvanzados) ...[
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filtros Avanzados (RF-05)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Filtro Categoría / Especialidad
                                SizedBox(
                                  width: 170,
                                  child: DropdownButtonFormField<String>(
                                    value: _vm.categoriaFiltro,
                                    decoration: const InputDecoration(
                                      labelText: 'Categoría',
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _vm.categorias
                                        .map((cat) => DropdownMenuItem(
                                              value: cat,
                                              child: Text(cat,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ))
                                        .toList(),
                                    onChanged: (v) =>
                                        _vm.actualizarCategoria(v),
                                  ),
                                ),

                                // Filtro Día
                                SizedBox(
                                  width: 150,
                                  child: DropdownButtonFormField<String>(
                                    value: _vm.diaFiltro,
                                    decoration: const InputDecoration(
                                      labelText: 'Día',
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _vm.diasSemana
                                        .map((dia) => DropdownMenuItem(
                                              value: dia,
                                              child: Text(dia,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ))
                                        .toList(),
                                    onChanged: (v) => _vm.actualizarDia(v),
                                  ),
                                ),

                                // Filtro Horario
                                SizedBox(
                                  width: 220,
                                  child: DropdownButtonFormField<String>(
                                    value: _vm.horarioFiltro,
                                    decoration: const InputDecoration(
                                      labelText: 'Horario',
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _vm.horarios
                                        .map((hor) => DropdownMenuItem(
                                              value: hor,
                                              child: Text(hor,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ))
                                        .toList(),
                                    onChanged: (v) => _vm.actualizarHorario(v),
                                  ),
                                ),

                                // Switch Disponibilidad de Cupos
                                FilterChip(
                                  selected: _vm.soloConCupo,
                                  label: const Text('Solo con cupo disponible'),
                                  onSelected: (val) =>
                                      _vm.actualizarSoloConCupo(val),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Lista de Deportes en tiempo real (RF-04)
                  Expanded(
                    child: StreamBuilder<List<Deporte>>(
                      stream: _vm.deportesStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error al cargar: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red)),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text(
                              'No hay disciplinas deportivas registradas en la base de datos.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 15),
                            ),
                          );
                        }

                        final deportesFiltrados =
                            _vm.filtrarDeportes(snapshot.data!);

                        if (deportesFiltrados.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off,
                                    size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                const Text(
                                  'No se encontraron deportes con los filtros seleccionados.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _vm.limpiarFiltros();
                                  },
                                  child: const Text('Restablecer filtros'),
                                )
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: deportesFiltrados.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final deporte = deportesFiltrados[index];
                            final cupos = deporte.cuposDisponibles();
                            final disponible = deporte.hayCupo();

                            return Card(
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                title: Text(
                                  deporte.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Categoría: ${deporte.categoria}\nCosto: \$${deporte.costoReserva.toStringAsFixed(2)}',
                                    style:
                                        TextStyle(color: Colors.grey.shade700),
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Cupos: $cupos / ${deporte.cupoMaximo}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: disponible
                                            ? Colors.green.shade100
                                            : Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        disponible ? 'Disponible' : 'Agotado',
                                        style: TextStyle(
                                          color: disponible
                                              ? Colors.green.shade900
                                              : Colors.red.shade900,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DeportesDetalleView(deporte: deporte),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
