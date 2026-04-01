// ignore_for_file: unused_field

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invitacion_boda/pages/pages.dart';
import 'package:invitacion_boda/services/sheets_services.dart';

class EnvelopeScreen extends StatefulWidget {
  final String? nombreInvitado;
  const EnvelopeScreen({super.key, this.nombreInvitado});

  @override
  State<EnvelopeScreen> createState() => _EnvelopeScreenState();
}

class _EnvelopeScreenState extends State<EnvelopeScreen> with TickerProviderStateMixin {
  bool _alreadyConfirmed = false;
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  bool opened = false;
  String _nombreInvitado = '';
  String? _guestDisplayName;
  String? _guestName;
  int? _guestPasses;
  int? _guestPassesConfirmed;

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
    
    // Obtener datos del invitado si hay nombre
    _getGuestData();
  }
  
  Future<void> _getGuestData() async {
    if (_nombreInvitado.isNotEmpty) {
      try {
        final guestData = await SheetsService.getGuest(_nombreInvitado);
        if (guestData != null) {
          setState(() {
            _guestName = guestData['key_normalized'] ?? _nombreInvitado;
            _guestDisplayName = guestData['display'] ?? _nombreInvitado;
            _guestPasses = int.tryParse(guestData['passesRemaining'].toString()) ?? 0;
            _guestPassesConfirmed = int.tryParse(guestData['confirmedCount'].toString()) ?? 0;
          });
        }
      } catch (e) {
        print('Error obteniendo datos del invitado: $e');
      }
    }
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
        pageBuilder: (_, animation, __) => InvitacionPage(
          guestName: _guestName,
          guestDisplayName: _guestDisplayName,
          guestPasses: _guestPasses,
        ),
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
            decoration: BoxDecoration(
              image: DecorationImage(
                // image: AssetImage('lib/assets/2.png'),
                image: AssetImage('lib/assets/3.jpg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.20),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          /// 💬 TEXTO SUPERIROR
          !opened && _guestDisplayName != null ?
          Positioned(
            bottom: size.height * 0.55,
            left: 20,
            right: 20,
            child: Center(
              child: RichText(
                textAlign: TextAlign.center,

                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "¡Hola ${_guestDisplayName ?? _nombreInvitado}! 🎉",
                      style: GoogleFonts.baloo2(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decorationColor: Colors.black,
                        decorationThickness: 2,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const TextSpan(text: "\n"),
                    TextSpan(
                      text: "Estás invitado a celebrar los",
                      style: GoogleFonts.baloo2(
                        fontSize: 26,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const TextSpan(text: "\n"),
                    TextSpan(
                      text: "5",
                      style: GoogleFonts.baloo2(
                        fontSize: 35,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const TextSpan(text: "\n"),
                    TextSpan(
                      text: "años de Jerónimo",
                      style: GoogleFonts.baloo2(
                        fontSize: 26,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const TextSpan(text: "\n"),
                    TextSpan(
                      text: "Ven a divertirte con nosotros",
                      style: GoogleFonts.baloo2(
                        fontSize: 26,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ):
          const SizedBox.shrink(),
          // /// ✨ SOLAPA DORADA
          // AnimatedPositioned(
          //   duration: const Duration(milliseconds: 600),
          //   curve: Curves.easeInOut,
          //   top: opened ? -size.height * 0.45 : 0,
          //   left: 0,
          //   right: 0,
          //   child: PhysicalShape(
          //     clipper: EnvelopeFlapClipper(),
          //     elevation: 20,
          //     shadowColor: Colors.black.withOpacity(1.0),
          //     color: Colors.black,
          //     child: ClipPath(
          //       clipper: EnvelopeFlapClipper(),
          //       child: Container(
          //         height: size.height * 0.45,
          //         decoration: const BoxDecoration(
          //           gradient: LinearGradient(
          //             colors: [
          //               Color(0xFF0077FF),
          //               Color(0xFFFF7A00),
          //               Color(0xFFFFD500),
          //             ],
          //             begin: Alignment.topCenter,
          //             end: Alignment.bottomCenter,
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
          /// 🟡 SELLO DORADO
          if (!opened)
          Positioned(
            top: size.height * 0.48, // Mover más arriba
            right: size.width * 0.30, // Mover más hacia la derecha
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
                    color: Color(0xFFFF7A00),
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
                      'TOCA\nAQUÍ',
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
        ],
      ),
    );
  }
}

/// SOLAPA
// class EnvelopeFlapClipper extends CustomClipper<Path> {
//   @override
//   Path getClip(Size size) {
//     final path = Path();

//     // Esquina superior izquierda
//     path.moveTo(0, 0);

//     // Borde izquierdo
//     path.lineTo(0, size.height * 0.55);

//     // Punta central del sobre
//     path.lineTo(size.width / 2, size.height);

//     // Borde derecho
//     path.lineTo(size.width, size.height * 0.55);

//     // Esquina superior derecha
//     path.lineTo(size.width, 0);

//     path.close();
//     return path;
//   }

//   @override
//   bool shouldReclip(_) => false;
// }
