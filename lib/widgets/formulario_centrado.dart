import 'package:flutter/material.dart';

/// Contenedor de los formularios de autenticación.
///
/// En el teléfono ocupa todo el ancho; desde tableta (600 px) se muestra como una
/// tarjeta centrada de 440 px (RNF-01).
class FormularioCentrado extends StatelessWidget {
  const FormularioCentrado({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final contenido = Padding(padding: const EdgeInsets.all(24), child: child);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: ancho >= 600 ? 24 : 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ancho >= 600 ? Card(child: contenido) : contenido,
        ),
      ),
    );
  }
}

/// Mensaje de error en un recuadro, para los errores que no son de un campo.
class MensajeError extends StatelessWidget {
  const MensajeError(this.mensaje, {super.key, this.acciones = const []});

  final String mensaje;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: esquema.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: esquema.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(child: Text(mensaje, style: TextStyle(color: esquema.onErrorContainer))),
            ],
          ),
          if (acciones.isNotEmpty) Wrap(spacing: 8, children: acciones),
        ],
      ),
    );
  }
}
