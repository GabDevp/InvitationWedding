import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CountdownWidget extends StatelessWidget {
  final int d;
  final int h;
  final int m;
  final int s;
  final Size size;

  const CountdownWidget({
    super.key,
    required this.d,
    required this.h,
    required this.m,
    required this.s,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = size.width < 600;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 🔔 CONTENIDO PRINCIPAL
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              child: Text(
                "¡Abran paso que\nestoy llegando!",
                textAlign: TextAlign.center,
                style: GoogleFonts.parisienne(
                  fontSize: 45,
                  color: Colors.brown[700],
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 8, offset: Offset(2, 2)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _timeBlock('${d}:', "Días", isMobile),
                _space(isMobile),
                _timeBlock('${h.toString().padLeft(2, '0')}:', "Horas", isMobile),
                _space(isMobile),
                _timeBlock('${m.toString().padLeft(2, '0')}:', "Min", isMobile),
                _space(isMobile),
                _timeBlock('${s.toString().padLeft(2, '0')}', "Seg", isMobile),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              child: Text(
                "¡Muy prontito\nestaré con ustedes!",
                textAlign: TextAlign.center,
                style: GoogleFonts.ropaSans(
                  fontSize: 45,
                  color: Colors.green[900],
                  // fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 8, offset: Offset(2, 2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _space(bool isMobile) =>
      SizedBox(width: isMobile ? 10 : 20);

  Widget _timeBlock(String value, String label, bool isMobile) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Text(
            value,
            key: ValueKey(value),
            style: TextStyle(
              fontSize: isMobile ? 34 : 48,
              fontWeight: FontWeight.bold,
              color: Colors.brown[900],
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 14 : 18,
            color: Colors.brown[900],
          ),
        ),
      ],
    );
  }
}