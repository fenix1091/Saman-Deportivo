import 'package:flutter/material.dart';

import '../core/exportar/descarga.dart';
import '../core/exportar/reportes.dart';
import '../core/theme.dart';

/// Formatos en los que se descarga un reporte.
enum FormatoReporte { pdf, excel }

/// Botón "Exportar" con un menú para descargar el reporte en PDF o en Excel.
///
/// [reporte] se arma en el momento de pulsar, con los datos que se ven en pantalla.
class BotonExportar extends StatefulWidget {
  const BotonExportar({super.key, required this.reporte, this.etiqueta = 'Exportar', this.compacto = false});

  final Reporte Function() reporte;
  final String etiqueta;

  /// Solo el icono (para barras de herramientas).
  final bool compacto;

  @override
  State<BotonExportar> createState() => _BotonExportarState();
}

class _BotonExportarState extends State<BotonExportar> {
  bool _generando = false;

  Future<void> _exportar(FormatoReporte formato) async {
    setState(() => _generando = true);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final r = widget.reporte();
      if (formato == FormatoReporte.pdf) {
        await descargarArchivo(await GeneradorReportes.pdf(r), '${r.archivo}.pdf', 'application/pdf');
      } else {
        await descargarArchivo(GeneradorReportes.excel(r), '${r.archivo}.xlsx',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      }
      mensajero.showSnackBar(SnackBar(
        content: Text('Listo: se descargó ${r.archivo}.${formato == FormatoReporte.pdf ? 'pdf' : 'xlsx'}'),
        backgroundColor: AppColors.verdeHoja,
      ));
    } catch (e) {
      mensajero.showSnackBar(
          SnackBar(content: Text('No se pudo generar el archivo: $e'), backgroundColor: AppColors.rojo));
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icono = _generando
        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.download_outlined);
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.rojo),
          onPressed: () => _exportar(FormatoReporte.pdf),
          child: const Text('Descargar PDF'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.table_view_outlined, color: AppColors.verdeHoja),
          onPressed: () => _exportar(FormatoReporte.excel),
          child: const Text('Descargar Excel'),
        ),
      ],
      builder: (context, controlador, _) {
        void alternar() => controlador.isOpen ? controlador.close() : controlador.open();
        if (widget.compacto) {
          return IconButton(
            tooltip: widget.etiqueta,
            onPressed: _generando ? null : alternar,
            icon: icono,
          );
        }
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _generando ? null : alternar,
          icon: icono,
          label: Text(widget.etiqueta),
        );
      },
    );
  }
}
