import 'package:flutter/material.dart';
import '../services/pdf_export_service.dart';

/// Botón flotante para exportar pantallas a PDF
class PdfExportButton extends StatelessWidget {
  final List<GlobalKey> sections;

  const PdfExportButton({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: "pdfExportButton",
      onPressed: () => _showExportMenu(context),
      icon: Icon(Icons.picture_as_pdf),
      label: Text("Exportar PDF"),
    );
  }

  void _showExportMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return ListTile(
          title: Text("Exportar PDF"),
          onTap: () {
            Navigator.pop(context);
            PdfExportService.exportMultipleSections(sections);
          },
        );
      },
    );
  }
}
