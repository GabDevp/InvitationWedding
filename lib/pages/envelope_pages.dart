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

    // Verificar si el invitado tiene pases disponibles
    if ((_guestPasses == null || _guestPasses == 0 && _guestPassesConfirmed == 0) && 
    !(_nombreInvitado.toLowerCase().contains('carolinal')) &&
      !(_nombreInvitado.toLowerCase().contains('cata')) &&
      !(_nombreInvitado.toLowerCase().contains('asesoria')) &&
      !(_nombreInvitado.toLowerCase().contains('edwin')) &&
      !(_nombreInvitado.toLowerCase().contains('luistafur')) &&
      !(_nombreInvitado.toLowerCase().contains('valentina')) &&
      !(_nombreInvitado.toLowerCase().contains('sanjose')) &&
      !(_nombreInvitado.toLowerCase().contains('promotora')) &&
      !(_nombreInvitado.toLowerCase().contains('elsy')) && _guestDisplayName != null ) {
      // Mostrar mensaje especial para invitados sin pases
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Gracias por estar en nuestros corazones 💝',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              color: Colors.pink[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: 
          Text(
            'Sabemos que en esta oportunidad no puedes estar,\npero igualmente estás presente en nuestra mente y corazón.\n\nTe enviamos todo nuestro cariño y agradecemos\ntu presencia espiritual en este día tan especial.\n\nPuedes ver toda nuestra invitación a continuación.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // Cerrar diálogo
                  // Continuar navegación a la invitación
                  Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 900),
                      pageBuilder: (_, animation, __) => InvitacionPage(
                        guestName: _guestName,
                        guestDisplayName: _guestDisplayName,
                        guestPasses: _guestPasses, // Pasar null o 0
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
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text('Ver invitación'),
              ),
            ),
          ],
        ),
      );
      return;
    }

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
          !opened && _guestDisplayName != null ?
          Positioned(
            bottom: size.height * 0.12,
            left: 20,
            right: 20,
            child: Column(
              children: [
                !(_nombreInvitado.toLowerCase().contains('carolinal')) &&
                !(_nombreInvitado.toLowerCase().contains('cata')) &&
                !(_nombreInvitado.toLowerCase().contains('asesoria')) &&
                !(_nombreInvitado.toLowerCase().contains('edwin')) &&
                !(_nombreInvitado.toLowerCase().contains('luistafur')) &&
                !(_nombreInvitado.toLowerCase().contains('valentina')) &&
                !(_nombreInvitado.toLowerCase().contains('sanjose')) &&
                !(_nombreInvitado.toLowerCase().contains('promotora')) &&
                !(_nombreInvitado.toLowerCase().contains('elsy')) ?
                Text("Hola ${_guestDisplayName?.trim() ?? _nombreInvitado} ${_nombreInvitado.contains(' y ') ? '\nEstán invitados a nuestra boda\nel 21 de Marzo de 2026' : '\nEstás invitado a nuestra boda\nel 21 de Marzo de 2026'}",
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
                ):Text("Hola ${_guestDisplayName?.trim() ?? _nombreInvitado} ${_nombreInvitado.contains(' y ') ? '\nQueremos que conozcan sobre nuestro matrimonio\nel 21 de Marzo de 2026' : '\nQueremos que conozcas sobre nuestro matrimonio\nel 21 de Marzo de 2026'}",
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
          ):
          const SizedBox.shrink(),
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
