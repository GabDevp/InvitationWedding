import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

/// Servicio para exportar todas las pantallas del proyecto a PDF (Web)
class PdfExportService {
  
  static Future<void> exportMultipleSections(List<GlobalKey> keys) async {
    final pdf = pw.Document();

    for (var key in keys) {
      try {
        if (key.currentContext == null) {
          print("⚠️ Context null, se omite");
          continue;
        }

        // 🔥 Forzar render en pantalla
        await Scrollable.ensureVisible(
          key.currentContext!,
          duration: Duration(milliseconds: 400),
        );

        await Future.delayed(Duration(milliseconds: 400));

        final renderObject = key.currentContext!.findRenderObject();

        if (renderObject is! RenderRepaintBoundary) {
          print("⚠️ No es boundary");
          continue;
        }

        final image = await renderObject.toImage(pixelRatio: 3);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) continue;

        final pngBytes = byteData.buffer.asUint8List();

        final imagePdf = pw.MemoryImage(pngBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Center(
              child: pw.Image(imagePdf, fit: pw.BoxFit.contain),
            ),
          ),
        );
      } catch (e) {
        print("❌ Error en sección: $e");
      }
    }

    final bytes = await pdf.save();

    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute("download", "invitacion_boda.pdf")
      ..click();

    html.Url.revokeObjectUrl(url);
  }
  
}
