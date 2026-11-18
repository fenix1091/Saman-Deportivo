import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Una tabla de un reporte: en el PDF es una sección y en el Excel, una hoja.
class TablaReporte {
  const TablaReporte({required this.titulo, required this.columnas, required this.filas, this.nota = ''});

  final String titulo;
  final List<String> columnas;

  /// Cada fila con un valor por columna: texto o número (en Excel los números
  /// quedan como números para poder sumar o filtrar).
  final List<List<Object>> filas;

  /// Texto corto bajo el título (por ejemplo, qué significa cada columna).
  final String nota;
}

/// Un reporte completo listo para exportar (CU-13, CU-16 y CU-20).
class Reporte {
  const Reporte({required this.titulo, required this.subtitulo, required this.archivo, required this.tablas, this.fecha});

  final String titulo;
  final String subtitulo;

  /// Nombre del archivo sin extensión, por ejemplo "asistencia_FUT-01".
  final String archivo;
  final List<TablaReporte> tablas;

  /// Fecha de generación; por defecto, ahora.
  final DateTime? fecha;

  String get _fechaTexto {
    final f = fecha ?? DateTime.now();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
  }
}

/// Genera el PDF y el Excel de un [Reporte].
class GeneradorReportes {
  GeneradorReportes._();

  static const _verde = PdfColor.fromInt(0xFF1F5E3A);
  static const _verdeClaro = PdfColor.fromInt(0xFFE8F2EC);
  static const _naranja = PdfColor.fromInt(0xFFF58220);
  static const _gris = PdfColor.fromInt(0xFF6B7280);

  /// Las fuentes estándar del PDF solo cubren Latin-1: se cambian los signos que
  /// no entran (guiones largos, comillas tipográficas) por su versión simple.
  static String _latin1(String t) => t
      .replaceAll(RegExp('[–—]'), '-')
      .replaceAll(RegExp('[‘’]'), "'")
      .replaceAll(RegExp('[“”]'), '"')
      .replaceAll('…', '...')
      .replaceAll(RegExp(r'[^\u0000-ÿ]'), '');

  /// Números con coma decimal, como se escriben en español.
  static String _texto(Object v) =>
      v is double ? v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1).replaceAll('.', ',') : '$v';

  static Future<Uint8List> pdf(Reporte r) async {
    pw.MemoryImage? logo;
    try {
      logo = pw.MemoryImage((await rootBundle.load('design/marca/logo_icono.png')).buffer.asUint8List());
    } catch (_) {
      // Sin logo el reporte sale igual.
    }
    final doc = pw.Document(title: _latin1(r.titulo), author: 'Samán Deportivo');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          margin: const pw.EdgeInsets.only(bottom: 14),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _naranja, width: 2))),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[pw.Image(logo, width: 34, height: 34), pw.SizedBox(width: 10)],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_latin1(r.titulo),
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _verde)),
                    pw.Text(_latin1(r.subtitulo), style: const pw.TextStyle(fontSize: 10, color: _gris)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Samán Deportivo', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Generado el ${r._fechaTexto}', style: const pw.TextStyle(fontSize: 8, color: _gris)),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _gris)),
        ),
        build: (context) => [
          for (final t in r.tablas) ...[
            pw.Text(_latin1(t.titulo), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            if (t.nota.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(_latin1(t.nota), style: const pw.TextStyle(fontSize: 8, color: _gris)),
              ),
            pw.SizedBox(height: 6),
            if (t.filas.isEmpty)
              pw.Text('Sin datos.', style: const pw.TextStyle(fontSize: 9, color: _gris))
            else
              pw.TableHelper.fromTextArray(
                headers: [for (final c in t.columnas) _latin1(c)],
                data: [
                  for (final f in t.filas) [for (final v in f) _latin1(_texto(v))],
                ],
                headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: _verde),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                oddRowDecoration: const pw.BoxDecoration(color: _verdeClaro),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                border: null,
                cellAlignments: {
                  for (var i = 0; i < t.columnas.length; i++)
                    i: t.filas.isNotEmpty && t.filas.first[i] is num ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                },
              ),
            pw.SizedBox(height: 18),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static Uint8List excel(Reporte r) {
    final libro = xl.Excel.createExcel();
    final porDefecto = libro.getDefaultSheet();
    final usados = <String>{};
    final encabezado = xl.CellStyle(
      bold: true,
      fontColorHex: xl.ExcelColor.fromHexString('#FFFFFFFF'),
      backgroundColorHex: xl.ExcelColor.fromHexString('#FF1F5E3A'),
    );
    final tituloEstilo = xl.CellStyle(bold: true, fontSize: 14, fontColorHex: xl.ExcelColor.fromHexString('#FF1F5E3A'));
    for (final t in r.tablas) {
      final nombre = _nombreHoja(t.titulo, usados);
      final hoja = libro[nombre];
      hoja.appendRow([xl.TextCellValue(r.titulo)]);
      hoja.cell(xl.CellIndex.indexByString('A1')).cellStyle = tituloEstilo;
      hoja.appendRow([xl.TextCellValue('${r.subtitulo} · generado el ${r._fechaTexto}')]);
      if (t.nota.isNotEmpty) hoja.appendRow([xl.TextCellValue(t.nota)]);
      hoja.appendRow([]);
      final filaEncabezado = hoja.maxRows;
      hoja.appendRow([for (final c in t.columnas) xl.TextCellValue(c)]);
      for (var c = 0; c < t.columnas.length; c++) {
        hoja.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: filaEncabezado)).cellStyle = encabezado;
        hoja.setColumnWidth(c, (t.columnas[c].length + 6).clamp(12, 40).toDouble());
      }
      for (final f in t.filas) {
        hoja.appendRow([
          for (final v in f)
            v is int
                ? xl.IntCellValue(v)
                : v is double
                    ? xl.DoubleCellValue(v)
                    : xl.TextCellValue('$v'),
        ]);
      }
    }
    if (porDefecto != null && !usados.contains(porDefecto)) libro.delete(porDefecto);
    return Uint8List.fromList(libro.encode()!);
  }

  /// Excel limita los nombres de hoja a 31 caracteres, sin \ / ? * [ ] : y sin repetir.
  static String _nombreHoja(String titulo, Set<String> usados) {
    var base = titulo.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
    if (base.isEmpty) base = 'Hoja';
    if (base.length > 28) base = base.substring(0, 28).trim();
    var nombre = base;
    var n = 2;
    while (usados.contains(nombre)) {
      nombre = '$base ${n++}';
    }
    usados.add(nombre);
    return nombre;
  }
}
