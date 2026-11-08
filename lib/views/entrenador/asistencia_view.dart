import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/deporte.dart';
import '../../repositories/deporte_repository.dart';
import '../../viewmodels/asistencia_view_model.dart';
import '../../widgets/acciones_sesion.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/formulario_centrado.dart';

/// Toma de asistencia e historial de una disciplina (CU-14, CU-15).
class AsistenciaView extends StatelessWidget {
  const AsistenciaView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AsistenciaViewModel>();
    return StreamBuilder<Deporte?>(
      stream: context.read<DeporteRepository>().deporte(vm.codigo),
      builder: (context, snap) {
        final deporte = snap.data;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(deporte?.nombre ?? vm.codigo),
              leading: BackButton(
                onPressed: () => context.canPop() ? context.pop() : context.go('/entrenador/mis-deportes'),
              ),
              actions: const [AccionesSesion()],
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.fact_check_outlined), text: 'Tomar asistencia'),
                  Tab(icon: Icon(Icons.insights_outlined), text: 'Historial'),
                ],
              ),
            ),
            body: vm.cargando
                ? const Esqueleto(filas: 4, alto: 64)
                : TabBarView(children: [_TomarAsistencia(vm: vm), _Historial(vm: vm)]),
          ),
        );
      },
    );
  }
}

String _fecha(DateTime f) => '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

class _TomarAsistencia extends StatelessWidget {
  const _TomarAsistencia({required this.vm});

  final AsistenciaViewModel vm;

  Future<void> _elegirFecha(BuildContext context) async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: vm.fecha,
      firstDate: DateTime(2026),
      lastDate: DateTime.now(),
      helpText: 'Fecha del entrenamiento',
    );
    if (elegida != null) vm.cambiarFecha(elegida);
  }

  Future<void> _guardar(BuildContext context) async {
    final ok = await vm.guardar();
    if (!context.mounted) return;
    final mensaje = ok ? vm.tomarAviso() : vm.error;
    if (mensaje != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mensaje),
        backgroundColor: ok ? AppColors.verdeHoja : AppColors.rojo,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    if (vm.nomina.isEmpty) {
      return EstadoVacio(
        icono: Icons.group_off_outlined,
        mensaje: vm.error ?? 'Todavía no hay estudiantes con inscripción confirmada en esta disciplina.',
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Entrenamiento del ${_fecha(vm.fecha)}',
                            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          vm.fechaRegistrada
                              ? 'Ya registrada: puedes corregirla y volver a guardar.'
                              : '${vm.totalPresentes} de ${vm.nomina.length} marcados presentes',
                          style: textos.bodySmall?.copyWith(color: AppColors.gris),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => _elegirFecha(context),
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: const Text('Cambiar fecha'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  TextButton(onPressed: () => vm.marcarTodos(true), child: const Text('Marcar todos')),
                  TextButton(onPressed: () => vm.marcarTodos(false), child: const Text('Desmarcar todos')),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                itemCount: vm.nomina.length,
                itemBuilder: (context, i) {
                  final e = vm.nomina[i];
                  final presente = vm.presente(e.uid);
                  return Revelar(
                    key: ValueKey(e.uid),
                    orden: i.clamp(0, 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: presente ? AppColors.verdeClaro : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: presente ? AppColors.verdeHoja.withValues(alpha: 0.5) : const Color(0xFFE3E8EE)),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        borderRadius: BorderRadius.circular(12),
                        child: CheckboxListTile(
                          value: presente,
                          onChanged: (v) => vm.marcar(e.uid, v ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.verdeHoja,
                          title: Text(e.nombreCompleto, style: textos.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [if (e.cedulaTexto.isNotEmpty) e.cedulaTexto, if (e.carnet.isNotEmpty) 'carnet ${e.carnet}']
                                .join(' · '),
                          ),
                          secondary: EtiquetaEstado(presente ? 'Presente' : 'Ausente',
                              color: presente ? AppColors.verdeHoja : AppColors.gris),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (vm.error != null)
              Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: MensajeError(vm.error!)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: vm.puedeGuardar ? () => _guardar(context) : null,
                icon: vm.guardando
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(vm.fechaRegistrada ? 'Actualizar asistencia' : 'Guardar asistencia'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Historial extends StatelessWidget {
  const _Historial({required this.vm});

  final AsistenciaViewModel vm;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final sesiones = vm.sesiones;
    if (sesiones.isEmpty) {
      return const EstadoVacio(
        icono: Icons.insights_outlined,
        mensaje: 'Aún no hay sesiones registradas. Toma la asistencia del primer entrenamiento para ver el historial.',
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Revelar(
              child: Row(
                children: [
                  _Cifra(valor: '${sesiones.length}', etiqueta: sesiones.length == 1 ? 'sesión' : 'sesiones'),
                  const SizedBox(width: 12),
                  _Cifra(valor: '${vm.promedio.round()} %', etiqueta: 'asistencia promedio'),
                  const SizedBox(width: 12),
                  _Cifra(valor: '${vm.nomina.length}', etiqueta: 'inscritos'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Revelar(
                orden: 1,
                child: Text('Por estudiante', style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(height: 8),
            for (var i = 0; i < vm.nomina.length; i++)
              Revelar(
                key: ValueKey('e-${vm.nomina[i].uid}'),
                orden: (i + 2).clamp(0, 6),
                child: _FilaEstudiante(
                  nombre: vm.nomina[i].nombreCompleto,
                  porcentaje: vm.porcentaje(vm.nomina[i].uid),
                  asistidas: vm.asistidasDe(vm.nomina[i].uid),
                  sesiones: vm.sesionesDe(vm.nomina[i].uid),
                ),
              ),
            const SizedBox(height: 20),
            Text('Sesiones', style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final s in sesiones)
              ListTile(
                key: ValueKey('s-${s.fecha}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined, color: AppColors.naranja),
                title: Text(_fecha(s.fecha)),
                trailing: Text('${s.presentes} de ${s.total} presentes',
                    style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                onTap: () {
                  vm.cambiarFecha(s.fecha);
                  DefaultTabController.of(context).animateTo(0);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.verdeClaro,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(valor,
                style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.verdeSaman)),
            Text(etiqueta, style: textos.bodySmall?.copyWith(color: AppColors.gris), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _FilaEstudiante extends StatelessWidget {
  const _FilaEstudiante(
      {required this.nombre, required this.porcentaje, required this.asistidas, required this.sesiones});

  final String nombre;
  final double porcentaje;
  final int asistidas;
  final int sesiones;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final color = sesiones == 0
        ? AppColors.gris
        : porcentaje >= 75
            ? AppColors.verdeHoja
            : porcentaje >= 50
                ? AppColors.naranja
                : AppColors.rojo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(nombre, style: textos.bodyLarge)),
              Text(
                sesiones == 0 ? 'Sin sesiones' : '$asistidas de $sesiones · ${porcentaje.round()} %',
                style: textos.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: porcentaje / 100),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: color,
                backgroundColor: const Color(0xFFEDF1EE),
                semanticsLabel: 'Asistencia de $nombre',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
