import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dialogs/publicar_resena_dialog.dart';

import '../models/inscripcion.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/mis_inscripciones_view_model.dart';

class MisInscripcionesView extends StatefulWidget {
  const MisInscripcionesView({super.key});

  @override
  State<MisInscripcionesView> createState() => _MisInscripcionesViewState();
}

class _MisInscripcionesViewState extends State<MisInscripcionesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = context.read<AuthViewModel>();
      if (authVM.usuario != null) {
        context
            .read<MisInscripcionesViewModel>()
            .escucharInscripciones(authVM.usuario!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MisInscripcionesViewModel>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Inscripciones'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Vigentes'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: vm.cargando
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _ListaInscripciones(
                    inscripciones: vm.vigentes,
                    esVigente: true,
                  ),
                  _ListaInscripciones(
                    inscripciones: vm.historial,
                    esVigente: false,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ListaInscripciones extends StatelessWidget {
  const _ListaInscripciones({
    required this.inscripciones,
    required this.esVigente,
  });

  final List<Inscripcion> inscripciones;
  final bool esVigente;

  @override
  Widget build(BuildContext context) {
    if (inscripciones.isEmpty) {
      return const Center(
        child: Text('No tienes inscripciones en esta sección.'),
      );
    }

    return ListView.builder(
      itemCount: inscripciones.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final inscripcion = inscripciones[index];
        return Card(
          child: ListTile(
            title: Text('Deporte: ${inscripcion.deporteCodigo}'),
            subtitle: Text('Estado: ${inscripcion.estado.name.toUpperCase()}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón para publicar reseña (CU-12)
                IconButton(
                  icon: const Icon(Icons.rate_review, color: Colors.orange),
                  tooltip: 'Dejar reseña',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => PublicarResenaDialog(
                        deporteCodigo: inscripcion.deporteCodigo,
                      ),
                    );
                  },
                ),
                // Botón para cancelar inscripción (CU-10)
                if (esVigente && inscripcion.estaVigente())
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () =>
                        _confirmarCancelacion(context, inscripcion),
                    child: const Text('Cancelar'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmarCancelacion(BuildContext context, Inscripcion inscripcion) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar Inscripción'),
        content: Text(
          '¿Estás seguro de que deseas cancelar tu inscripción a ${inscripcion.deporteCodigo}? Esta acción liberará tu cupo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Atrás'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final vm = context.read<MisInscripcionesViewModel>();
              final exito = await vm.cancelarInscripcion(
                inscripcion.id,
                inscripcion.deporteCodigo,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      exito
                          ? 'Inscripción cancelada exitosamente'
                          : vm.error ?? 'Error al cancelar',
                    ),
                  ),
                );
              }
            },
            child: const Text('Confirmar Cancelación'),
          ),
        ],
      ),
    );
  }
}
