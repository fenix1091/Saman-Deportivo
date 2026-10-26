import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/deporte.dart';
import '../../viewmodels/catalogo_view_model.dart';
import '../../widgets/acciones_sesion.dart';
import '../../widgets/barra_cupos.dart';

/// Catálogo público de disciplinas con búsqueda y filtros (CU-04, CU-05).
///
/// Lo ven visitantes y estudiantes. En el teléfono es una lista; desde tableta,
/// una cuadrícula de 2 o 3 columnas (RNF-01).
class CatalogoView extends StatefulWidget {
  const CatalogoView({super.key});

  @override
  State<CatalogoView> createState() => _CatalogoViewState();
}

class _CatalogoViewState extends State<CatalogoView> {
  final _buscador = TextEditingController();

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  void _limpiarFiltros() {
    _buscador.clear();
    context.read<CatalogoViewModel>().limpiarFiltros();
  }

  void _quitarBusqueda() {
    _buscador.clear();
    context.read<CatalogoViewModel>().buscar('');
  }

  void _abrirFiltros() {
    final vm = context.read<CatalogoViewModel>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: _HojaFiltros(onLimpiar: _limpiarFiltros)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CatalogoViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de deportes'), actions: const [AccionesSesion()]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _buscador,
                        onChanged: vm.buscar,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Buscar deporte, código o entrenador',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: vm.texto.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Borrar búsqueda',
                                  icon: const Icon(Icons.close),
                                  onPressed: _quitarBusqueda,
                                ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Filtros',
                      iconSize: 26,
                      icon: const Icon(Icons.tune),
                      onPressed: vm.cargando ? null : _abrirFiltros,
                    ),
                  ],
                ),
              ),
              _ChipsFiltros(onQuitarBusqueda: _quitarBusqueda),
              Expanded(child: _Contenido(onLimpiar: _limpiarFiltros)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filtros activos como chips removibles y la cantidad de resultados (CU-05, paso 3).
class _ChipsFiltros extends StatelessWidget {
  const _ChipsFiltros({required this.onQuitarBusqueda});

  final VoidCallback onQuitarBusqueda;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CatalogoViewModel>();
    if (vm.cargando || vm.error != null || vm.deportes.isEmpty) return const SizedBox.shrink();
    final chips = <Widget>[
      if (vm.texto.trim().isNotEmpty) _chip('"${vm.texto.trim()}"', onQuitarBusqueda),
      if (vm.deporte != null) _chip(vm.deporte!, () => vm.filtrarDeporte(null)),
      if (vm.categoria != null) _chip(vm.categoria!, () => vm.filtrarCategoria(null)),
      if (vm.dia != null) _chip(vm.dia!.etiqueta, () => vm.filtrarDia(null)),
      if (vm.franja != null) _chip(vm.franja!.etiqueta, () => vm.filtrarFranja(null)),
      if (vm.soloConCupos) _chip('Con cupos', () => vm.filtrarSoloConCupos(false)),
    ];
    final total = vm.resultados.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chips.isNotEmpty) Wrap(spacing: 8, runSpacing: 4, children: chips),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              total == 1 ? '1 disciplina' : '$total disciplinas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.gris),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String texto, VoidCallback alQuitar) =>
      InputChip(label: Text(texto), onDeleted: alQuitar, deleteButtonTooltipMessage: 'Quitar filtro');
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.onLimpiar});

  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CatalogoViewModel>();
    if (vm.cargando) return const Center(child: CircularProgressIndicator());
    if (vm.error != null) return _Aviso(icono: Icons.wifi_off, texto: vm.error!);
    if (vm.deportes.isEmpty) {
      return const _Aviso(icono: Icons.sports, texto: 'Aún no hay disciplinas disponibles para este trimestre.');
    }
    final resultados = vm.resultados;
    if (resultados.isEmpty) {
      return _Aviso(
        icono: Icons.search_off,
        texto: 'No encontramos disciplinas con esos filtros.',
        accion: OutlinedButton(onPressed: onLimpiar, child: const Text('Limpiar filtros')),
      );
    }
    return LayoutBuilder(builder: (context, medidas) {
      final columnas = medidas.maxWidth >= 1000
          ? 3
          : medidas.maxWidth >= 600
              ? 2
              : 1;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnas,
          mainAxisExtent: 210,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: resultados.length,
        itemBuilder: (_, i) => _TarjetaDeporte(deporte: resultados[i], horarios: vm.horariosDe(resultados[i].codigo)),
      );
    });
  }
}

class _TarjetaDeporte extends StatelessWidget {
  const _TarjetaDeporte({required this.deporte, required this.horarios});

  /// Horarios que se listan en la tarjeta; el resto se ve en el detalle.
  static const maxHorarios = 2;

  final Deporte deporte;
  final List<Horario> horarios;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final gris = textos.bodySmall?.copyWith(color: AppColors.gris);
    final resto = horarios.length - maxHorarios;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/catalogo/${Uri.encodeComponent(deporte.codigo)}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deporte.nombre,
                      style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(deporte.codigo, style: gris),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (deporte.categoria.isNotEmpty) deporte.categoria,
                  deporte.entrenador?.nombre ?? 'Entrenador por asignar',
                ].join(' · '),
                style: gris,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              if (horarios.isEmpty)
                Text('Horarios por publicar', style: textos.bodyMedium)
              else
                for (final h in horarios.take(maxHorarios))
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: AppColors.naranja),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(h.etiqueta, style: textos.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
              if (resto > 0) Text('y $resto horario${resto == 1 ? '' : 's'} más', style: gris),
              const Spacer(),
              BarraCupos(deporte: deporte),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja con los filtros avanzados (CU-05, paso 1).
class _HojaFiltros extends StatelessWidget {
  const _HojaFiltros({required this.onLimpiar});

  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CatalogoViewModel>();
    final textos = Theme.of(context).textTheme;
    Widget titulo(String texto) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(texto, style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtros', style: textos.titleLarge),
            titulo('Deporte'),
            DropdownButtonFormField<String?>(
              // La clave lo reconstruye cuando "Limpiar" quita el filtro.
              key: ValueKey(vm.deporte),
              initialValue: vm.deporte,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final nombre in vm.nombresDeporte) DropdownMenuItem(value: nombre, child: Text(nombre)),
              ],
              onChanged: vm.filtrarDeporte,
            ),
            if (vm.categorias.isNotEmpty) ...[
              titulo('Categoría o especialidad'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in vm.categorias)
                    ChoiceChip(
                      label: Text(c),
                      selected: vm.categoria == c,
                      onSelected: (marcado) => vm.filtrarCategoria(marcado ? c : null),
                    ),
                ],
              ),
            ],
            titulo('Día'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final d in DiaSemana.values)
                  ChoiceChip(
                    label: Text(d.etiqueta),
                    selected: vm.dia == d,
                    onSelected: (marcado) => vm.filtrarDia(marcado ? d : null),
                  ),
              ],
            ),
            titulo('Horario'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final f in FranjaHoraria.values)
                  ChoiceChip(
                    label: Text(f.etiqueta),
                    selected: vm.franja == f,
                    onSelected: (marcado) => vm.filtrarFranja(marcado ? f : null),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Solo con cupos disponibles'),
              value: vm.soloConCupos,
              onChanged: vm.filtrarSoloConCupos,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: vm.hayFiltros ? onLimpiar : null,
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Ver ${vm.resultados.length} resultados'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto, this.accion});

  final IconData icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: AppColors.gris),
            const SizedBox(height: 12),
            Text(texto, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            if (accion != null) ...[const SizedBox(height: 16), accion!],
          ],
        ),
      ),
    );
  }
}
