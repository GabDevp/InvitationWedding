// ignore_for_file: unused_field

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invitacion_boda/pages/pages.dart';

class EnvelopeScreen extends StatefulWidget {
  final String? nombreInvitado;
  const EnvelopeScreen({super.key, this.nombreInvitado});

  @override
  State<EnvelopeScreen> createState() => _EnvelopeScreenState();
}

class _EnvelopeScreenState extends State<EnvelopeScreen>
    with TickerProviderStateMixin {
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  bool opened = false;
  String _nombreInvitado = '';

  @override
  void initState() {
    super.initState();

    _nombreInvitado = widget.nombreInvitado ?? '';

    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _arrowAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(
        parent: _arrowController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  void _toggleEnvelope() async {
    if (opened) return;

    setState(() => opened = true);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (_, animation, __) => const InvitacionPage(),
        transitionsBuilder: (_, animation, __, child) {
          final blur = Tween<double>(begin: 25, end: 0).animate(animation);
          return AnimatedBuilder(
            animation: animation,
            builder: (_, __) {
              return BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: blur.value,
                  sigmaY: blur.value,
                ),
                child: Opacity(
                  opacity: animation.value,
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      body: Stack(
        children: [
          /// 🖼️ FONDO (PAREJA)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/fondo1.jpg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black12,
                  BlendMode.darken,
                ),
              ),
            ),
          ),

          /// ✨ SOLAPA DORADA
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            top: opened ? -size.height * 0.45 : 0,
            left: 0,
            right: 0,
            child: PhysicalShape(
              clipper: EnvelopeFlapClipper(),
              elevation: 20,
              shadowColor: Colors.black.withOpacity(1.0),
              color: Colors.black,
              child: ClipPath(
                clipper: EnvelopeFlapClipper(),
                child: Container(
                  height: size.height * 0.45,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('lib/assets/sobre1.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),

          /// 🟡 SELLO DORADO
          if (!opened)
            Positioned(
              top: size.height * 0.37,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _toggleEnvelope,
                  child: AnimatedBuilder(
                    animation: _arrowAnimation,
                    builder: (_, child) {
                      return Transform.translate(
                        offset: Offset(0, _arrowAnimation.value),
                        child: child,
                      );
                    },
                    child: Container(
                      width: isMobile ? 80 : 95,
                      height: isMobile ? 80 : 95,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFB08D57),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'ABRA\nAQUÍ',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            color: Colors.white,
                            fontSize: isMobile ? 14 : 16,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          /// 💬 TEXTO INFERIOR
          if (!opened && _nombreInvitado.isNotEmpty)
            Positioned(
              bottom: size.height * 0.12,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Text(
                    "Hola ${_nombreInvitado.trim()} ${_nombreInvitado.contains(' y ') ? '\nEstán invitados a nuestra boda\nel 18 de julio de 2026' : '\nEstás invitado a nuestra boda\nel 18 de julio de 2026'},",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.parisienne(
                      fontSize: isMobile ? 30 : 34,
                      color: Colors.white,
                      decorationColor: Colors.black,
                      decorationThickness: 2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// ✂️ CLIPPER SOLAPA
class EnvelopeFlapClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Esquina superior izquierda
    path.moveTo(0, 0);

    // Borde izquierdo
    path.lineTo(0, size.height * 0.55);

    // Punta central del sobre
    path.lineTo(size.width / 2, size.height);

    // Borde derecho
    path.lineTo(size.width, size.height * 0.55);

    // Esquina superior derecha
    path.lineTo(size.width, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(_) => false;
}
