// ignore_for_file: unused_field

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invitacion_boda/pages/pages.dart';
import 'package:video_player/video_player.dart';
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
  late VideoPlayerController _videoController;

  bool opened = false;
  bool _dataLoaded = true; // Siempre true ya que no necesitamos cargar datos
  bool _videoLoaded = false;
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

    // Inicializar el controller del video
    _videoController = VideoPlayerController.asset('lib/assets/video/invitacion.mp4')
      ..initialize().then((_) {
        setState(() {
          _videoLoaded = true;
        });
        _videoController.setLooping(true);
        _videoController.setVolume(0.0); // Silenciar video para fondo
        _videoController.play();
      }).catchError((error) {
        print('Error al cargar video: $error');
        setState(() {
          _videoLoaded = false;
        });
      });
  }

  @override
  void dispose() {
    _arrowController.dispose();
    _videoController.dispose();
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
      backgroundColor: Colors.black54,
      body: Stack(
        children: [
          // Fondo principal con video o fallback a imagen
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: _videoLoaded && _videoController.value.isInitialized
                ? VideoPlayer(_videoController)
                : Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('lib/assets/fondo1.jpg'),
                        fit: BoxFit.cover,
                      ),
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
          ),
          
          // Overlay oscuro sutil para mejorar legibilidad
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
            ),
          ),

          // Encabezado
          if (!opened && _dataLoaded)
            Positioned(
              top: size.height * 0.01,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Invitado",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                      decorationThickness: 2,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Nuevas noticias",
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "JULIO 2026",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.w300,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                      decorationThickness: 2,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                      decorationStyle: TextDecorationStyle.solid,
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              top: size.height * 0.05,
              left: 0,
              right: 0,
              child: Divider(color: Colors.white, thickness: 3, height: 20),
            ),

          // Contenido central - Nombres y frase
          if (!opened && _dataLoaded)
            Positioned(
              top: size.height * 0.15,
              left: 0,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Nombres principales
                  Column(
                    children: [
                      Divider(color: Colors.white, thickness: 2, height: 20, endIndent: 80, indent: 80),
                      Text(
                        "Gabriel",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 6,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFB08D57),
                      borderRadius: BorderRadius.circular(45),
                    ),
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
                    child: Text(
                      "&",
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 38,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.7),
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    children: [
                      Text(
                        "Daniela",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 6,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      Divider(color: Colors.white, thickness: 2, height: 20, endIndent: 50, indent: 50),
                    ],
                  ),
                  Text(
                    "¡Nuestra Boda!",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isMobile ? 32 : 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.7),
                          blurRadius: 6,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "Te elijo hoy y por el resto de mi vida",
                    style: GoogleFonts.dancingScript(
                      fontSize: isMobile ? 24 : 32,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.7),
                          blurRadius: 6,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

          // Borde floral inferior con PNG
          if (!opened && _dataLoaded)
            Positioned(
              bottom: -15,
              left: 0,
              right: 0,
              child: Container(
                height: size.height * 0.15,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('lib/assets/flores.png'),
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    repeat: ImageRepeat.repeatX,
                    scale: 1.5,
                  ),
                ),
              ),
            ),
          // Borde floral inferior con PNG
          if (!opened && _dataLoaded)
            Positioned(
              bottom: -28,
              left: 0,
              right: 0,
              child: Container(
                height: size.height * 0.15,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('lib/assets/flores.png'),
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    repeat: ImageRepeat.repeatX,
                    scale: 1.5,
                  ),
                ),
              ),
            ),
          // Borde floral inferior con PNG
          if (!opened && _dataLoaded)
            Positioned(
              bottom: -40,
              left: 0,
              right: 0,
              child: Container(
                height: size.height * 0.15,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('lib/assets/flores.png'),
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    repeat: ImageRepeat.repeatX,
                    scale: 1.5,
                  ),
                ),
              ),
            ),

          // Botón central de abrir invitación
          if (!opened && _dataLoaded)
            Positioned(
              top: size.height * 0.65,
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
                      width: isMobile ? 100 : 120,
                      height: isMobile ? 100 : 120,
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
                          'ABRIR\nINVITACIÓN',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            color: Colors.white,
                            fontSize: isMobile ? 12 : 14,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.bold,
                          ),
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

