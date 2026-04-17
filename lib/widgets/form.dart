import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InvitadosForm extends StatelessWidget {
  final Size size;
  final double fontSizeBody;

  final TextEditingController nombreCtrl;
  final TextEditingController acomp1Ctrl;
  final TextEditingController acomp2Ctrl;
  final TextEditingController acomp3Ctrl;

  final int? passes;
  final bool soldOut;
  final bool alreadyConfirmed;

  final VoidCallback onConfirm;
  final Function(String) onNameChanged;
  final VoidCallback onAskToAttend;

  const InvitadosForm({
    super.key,
    required this.size,
    required this.fontSizeBody,
    required this.nombreCtrl,
    required this.acomp1Ctrl,
    required this.acomp2Ctrl,
    required this.acomp3Ctrl,
    required this.passes,
    required this.soldOut,
    required this.alreadyConfirmed,
    required this.onConfirm,
    required this.onNameChanged,
    required this.onAskToAttend,
  });

  @override
  Widget build(BuildContext context) {
    final maxCompanions = ((passes ?? 0) - 1).clamp(0, 3);
    
    // Verificar si es el invitado especial que no debe ver botones
    final isSpecialGuest = nombreCtrl.text.trim().toLowerCase().contains('angela y jhon');

    return Column(
      children: [
        // INPUT NOMBRE
        if (!soldOut && !isSpecialGuest)
          SizedBox(
            width: size.width > 600 ? 400 : size.width * 0.75,
            child: TextField(
              controller: nombreCtrl,
              onChanged: (value) {
                if (value.length >= 2) {
                  onNameChanged(value);
                }
              },
              decoration: const InputDecoration(
                labelText: "Tu nombre",
                filled: true,
                fillColor: Colors.white70,
              ),
            ),
          ),

        const SizedBox(height: 8),

        // ACOMPAÑANTES - Solo mostrar si hay pases disponibles
        if (!soldOut && (passes ?? 0) > 0) ...[
          if (maxCompanions >= 1)
            _input(size, acomp1Ctrl, "Acompañante 1"),
          if (maxCompanions >= 2)
            _input(size, acomp2Ctrl, "Acompañante 2"),
          if (maxCompanions >= 3)
            _input(size, acomp3Ctrl, "Acompañante 3"),
        ],

        const SizedBox(height: 10),

        // MENSAJE DE PASES
        if (passes != null && !isSpecialGuest)
          SizedBox(
            width: size.width > 600 ? 400 : size.width * 0.75,
            child: Text(
              passes! > 0
                  ? passes! > 1
                      ? 'Tienes $passes pases disponibles, el tuyo y el de ${((passes ?? 1) - 1).clamp(0, 3)} acompañante.\nSi llevas niños es un pase para ellos tambien.'
                      : 'El pase es solo para ti.'
                  : 'No tienes pases asignados, pero nos encantaría que vengas.',
              style: GoogleFonts.roboto(
                color: Colors.brown[900],
                fontSize: fontSizeBody * 0.80,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        const SizedBox(height: 20),

        // BOTONES
        if (isSpecialGuest)
          Container(
            width: size.width > 600 ? 400 : size.width * 0.75,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info,
                  color: Colors.blue,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  "Información especial",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    color: Colors.brown[900],
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  "Tu asistencia ha sido confirmada\npor medios especiales.\n¡Nos vemos pronto!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    color: Colors.brown[900],
                    fontSize: fontSizeBody * 0.80,
                  ),
                ),
              ],
            ),
          )
        else if (!soldOut && (passes ?? 0) > 0)
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text("Confirmar asistencia \ud83d\udc8c", style: TextStyle(color: Colors.white),),
          )
        else if (!soldOut && (passes ?? 0) == 0)
          Column(
            children: [
              ElevatedButton(
                onPressed: onAskToAttend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text("¿Deseas asistir? \ud83c\udf89"),
              ),
              const SizedBox(height: 8),
              Text(
                'Si deseas asistir, te haremos una pregunta sobre quiénes vendrán.',
                style: GoogleFonts.roboto(
                  color: Colors.white70,
                  fontSize: fontSizeBody * 0.70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
      ],
    );
  }

  Widget _input(Size size, TextEditingController ctrl, String label) {
    return Column(
      children: [
        SizedBox(
          width: size.width > 600 ? 400 : size.width * 0.75,
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: Colors.white70,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}