import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/validadores.dart';

/// Campo de correo que propone terminar la dirección con los dominios de la
/// UNIMET: al escribir "vgallo" ofrece "vgallo@correo.unimet.edu.ve" y
/// "vgallo@unimet.edu.ve". Se elige con un clic o con Enter.
class CampoCorreo extends StatefulWidget {
  const CampoCorreo({
    super.key,
    required this.controller,
    this.etiqueta = 'Correo',
    this.ayuda,
    this.sugerencia,
    this.validator,
    this.alEnviar,
    this.autocompletarNavegador = true,
    this.accion,
  });

  final TextEditingController controller;
  final String etiqueta;
  final String? ayuda;

  /// Texto de ejemplo dentro del campo vacío.
  final String? sugerencia;
  final FormFieldValidator<String>? validator;

  /// Se llama con Enter cuando no hay ninguna propuesta que elegir.
  final VoidCallback? alEnviar;

  /// Deja que el navegador proponga correos guardados (en el registro se apaga).
  final bool autocompletarNavegador;
  final TextInputAction? accion;

  @override
  State<CampoCorreo> createState() => _CampoCorreoState();
}

class _CampoCorreoState extends State<CampoCorreo> {
  final _foco = FocusNode();

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _foco,
        optionsBuilder: (valor) => Validadores.sugerenciasCorreo(valor.text),
        fieldViewBuilder: (context, controlador, foco, elegirResaltada) => TextFormField(
          controller: controlador,
          focusNode: foco,
          decoration: InputDecoration(
            labelText: widget.etiqueta,
            helperText: widget.ayuda,
            hintText: widget.sugerencia,
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: widget.accion,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: widget.autocompletarNavegador ? const [AutofillHints.email] : null,
          validator: widget.validator,
          onFieldSubmitted: (texto) {
            if (Validadores.sugerenciasCorreo(texto).isEmpty) {
              widget.alEnviar?.call();
            } else {
              elegirResaltada();
            }
          },
        ),
        optionsViewBuilder: (context, alElegir, opciones) => Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              elevation: 8,
              shadowColor: Colors.black38,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadios.campo),
                side: const BorderSide(color: AppColors.borde),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: caja.maxWidth),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  children: [
                    for (final (i, opcion) in opciones.indexed)
                      _Propuesta(
                        correo: opcion,
                        resaltada: AutocompleteHighlightedOption.of(context) == i,
                        alElegir: () => alElegir(opcion),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Propuesta extends StatelessWidget {
  const _Propuesta({required this.correo, required this.resaltada, required this.alElegir});

  final String correo;
  final bool resaltada;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final arroba = correo.indexOf('@');
    return InkWell(
      onTap: alElegir,
      child: Container(
        color: resaltada ? AppColors.naranjaClaro : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.alternate_email, size: 18, color: AppColors.naranjaProfundo),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                        text: correo.substring(0, arroba),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.texto)),
                    TextSpan(text: correo.substring(arroba), style: const TextStyle(color: AppColors.gris)),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: correo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
