import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/deporte.dart';
import '../../repositories/deporte_repository.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/mis_inscripciones_view_model.dart';

/// Reseña de una disciplina y, si tiene profesor asignado, de su profesor.
class PublicarResenaDialog extends StatefulWidget {
  const PublicarResenaDialog({super.key, required this.deporteCodigo, this.nombreDeporte = ''});

  final String deporteCodigo;
  final String nombreDeporte;

  @override
  State<PublicarResenaDialog> createState() => _PublicarResenaDialogState();
}

class _PublicarResenaDialogState extends State<PublicarResenaDialog> {
  int _calificacion = 5;
  int _calificacionProfesor = 5;
  final TextEditingController _comentarioController = TextEditingController();
  final TextEditingController _comentarioProfesor = TextEditingController();
  bool _enviando = false;
  late final Future<Deporte?> _deporte = context.read<DeporteRepository>().deporte(widget.deporteCodigo).first;

  @override
  void dispose() {
    _comentarioController.dispose();
    _comentarioProfesor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.nombreDeporte.isEmpty ? widget.deporteCodigo : widget.nombreDeporte;
    return FutureBuilder<Deporte?>(
      future: _deporte,
      builder: (context, snap) {
        final deporte = snap.data;
        final profesor = deporte == null || deporte.entrenadorId.isEmpty ? null : deporte;
        return AlertDialog(
          title: Text('Opinar sobre $nombre'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('¿Cómo fue la disciplina?', textAlign: TextAlign.center),
                  _SelectorEstrellas(
                    valor: _calificacion,
                    etiqueta: 'la disciplina',
                    alCambiar: (v) => setState(() => _calificacion = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _comentarioController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Comentario (opcional)',
                      hintText: '¿Qué te pareció la actividad?',
                    ),
                  ),
                  if (profesor != null) ...[
                    const Divider(height: 32),
                    Text(
                      '¿Cómo fue el profesor${_nombreProfesor(profesor)}?',
                      textAlign: TextAlign.center,
                    ),
                    _SelectorEstrellas(
                      valor: _calificacionProfesor,
                      etiqueta: 'el profesor',
                      alCambiar: (v) => setState(() => _calificacionProfesor = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _comentarioProfesor,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Comentario sobre el profesor (opcional)',
                        hintText: '¿Cómo explica, corrige y trata al grupo?',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _enviando ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: _enviando || snap.connectionState != ConnectionState.done ? null : () => _enviarResena(profesor),
              child: _enviando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Publicar'),
            ),
          ],
        );
      },
    );
  }

  String _nombreProfesor(Deporte d) {
    final n = d.entrenador?.nombre ?? '';
    return n.isEmpty ? '' : ' $n';
  }

  Future<void> _enviarResena(Deporte? profesor) async {
    final usuario = context.read<AuthViewModel>().usuario;
    if (usuario == null) return;

    setState(() => _enviando = true);

    final vm = context.read<MisInscripcionesViewModel>();
    final exito = await vm.publicarResena(
      deporteCodigo: widget.deporteCodigo,
      estudianteId: usuario.uid,
      calificacion: _calificacion,
      comentario: _comentarioController.text.trim(),
      autor: usuario.nombreCompleto,
      entrenadorId: profesor?.entrenadorId ?? '',
      calificacionEntrenador: profesor == null ? null : _calificacionProfesor,
      comentarioEntrenador: _comentarioProfesor.text.trim(),
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(exito ? '¡Reseña publicada con éxito!' : vm.error ?? 'Error al publicar la reseña')),
      );
    }
  }
}

class _SelectorEstrellas extends StatelessWidget {
  const _SelectorEstrellas({required this.valor, required this.etiqueta, required this.alCambiar});

  final int valor;
  final String etiqueta;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i ${i == 1 ? 'estrella' : 'estrellas'} para $etiqueta',
            icon: Icon(i <= valor ? Icons.star : Icons.star_border, color: Colors.amber),
            onPressed: () => alCambiar(i),
          ),
      ],
    );
  }
}
