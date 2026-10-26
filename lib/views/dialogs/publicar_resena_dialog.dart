import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/mis_inscripciones_view_model.dart';

class PublicarResenaDialog extends StatefulWidget {
  const PublicarResenaDialog({super.key, required this.deporteCodigo});

  final String deporteCodigo;

  @override
  State<PublicarResenaDialog> createState() => _PublicarResenaDialogState();
}

class _PublicarResenaDialogState extends State<PublicarResenaDialog> {
  int _calificacion = 5;
  final TextEditingController _comentarioController = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Opinar sobre ${widget.deporteCodigo}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Selecciona tu calificación:'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final estrellaIndex = index + 1;
                return IconButton(
                  icon: Icon(
                    estrellaIndex <= _calificacion
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      _calificacion = estrellaIndex;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _comentarioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                border: OutlineInputBorder(),
                hintText: '¿Qué te pareció la actividad?',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _enviando ? null : _enviarResena,
          child: _enviando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Publicar'),
        ),
      ],
    );
  }

  Future<void> _enviarResena() async {
    final authVM = context.read<AuthViewModel>();
    final usuario = authVM.usuario ?? authVM.usuario;

    if (usuario == null) return;

    setState(() => _enviando = true);

    final vm = context.read<MisInscripcionesViewModel>();
    final exito = await vm.publicarResena(
      deporteCodigo: widget.deporteCodigo,
      estudianteId: usuario.uid,
      calificacion: _calificacion,
      comentario: _comentarioController.text.trim(),
      autor: usuario.nombre,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exito
                ? '¡Reseña publicada con éxito!'
                : vm.error ?? 'Error al publicar la reseña',
          ),
        ),
      );
    }
  }
}
