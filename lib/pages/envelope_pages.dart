// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EnvelopeScreen extends StatefulWidget {
  const EnvelopeScreen({super.key});

  @override
  State<EnvelopeScreen> createState() => _EnvelopeScreenState();
}

class _EnvelopeScreenState extends State<EnvelopeScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool opened = false;
  bool showText = false;
  // Controlador para animar la flecha (en tu State)
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _animation = Tween<double>(begin: 0, end: -3.14 / 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true); // sube y baja en loop

    _arrowAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          showText = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  void _toggleEnvelope() async {
    setState(() => opened = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('presentacion');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;

        // ---------- Breakpoints ----------
        double envelopeWidth;
        double envelopeHeight;
        double titleFont;
        double logoSize;
        double buttonFont;
        double borderWidth;
        double shadowBlur;
        double shadowDy;

        // Posiciones relativas (dentro del sobre)
        double textTop;
        double textLeft;

        // Solapa (flap)
        double flapHeightFactor; // altura de la solapa respecto al sobre
        double flapLift;         // cuánto se eleva al abrirse

        if (maxW < 400) {
          // Teléfonos pequeños
          envelopeWidth = maxW * 0.92;
          envelopeHeight = 180;
          titleFont = 18;
          logoSize = 80;
          buttonFont = 14;
          borderWidth = 1.2;
          shadowBlur = 8;
          shadowDy = 4;

          textTop = envelopeHeight * 0.08;
          textLeft = envelopeWidth * 0.2+0.08;

          flapHeightFactor = 0.78;
          flapLift = envelopeHeight * 0.62;
        } else if (maxW < 800) {
          // Móviles grandes / tablets vertical
          envelopeWidth = 400;
          envelopeHeight = 220;
          titleFont = 26;
          logoSize = 110;
          buttonFont = 16;
          borderWidth = 1.05;
          shadowBlur = 10;
          shadowDy = 5;

          textTop = envelopeHeight * 0.10;
          textLeft = envelopeWidth * 0.08;

          flapHeightFactor = 0.80;
          flapLift = envelopeHeight * 0.60;
        } else {
          // Escritorio / tablets grandes
          envelopeWidth = 600;
          envelopeHeight = 300;
          titleFont = 36;
          logoSize = 200;
          buttonFont = 20;
          borderWidth = 0.8;
          shadowBlur = 12;
          shadowDy = 6;

          textTop = envelopeHeight * 0.10;
          textLeft = envelopeWidth * 0.19; // similar a tu 115 px sobre 600

          flapHeightFactor = 0.83;
          flapLift = envelopeHeight * 0.60; // ~180px sobre 300
        }

        return Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("lib/assets/fondo1.jpg"), // asegúrate de usar assets/
              fit: BoxFit.cover,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: AnimatedScale(
                    scale: opened ? 2.5 : 1.0,
                    duration: const Duration(seconds: 1),
                    curve: Curves.easeInOut,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 600,
                        maxHeight: 350,
                      ),
                      child: SizedBox(
                        width: envelopeWidth,
                        height: envelopeHeight,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Cuerpo del sobre
                            Container(
                              width: envelopeWidth,
                              height: envelopeHeight,
                              decoration: BoxDecoration(
                                color: Color.fromARGB(255, 248, 237, 203), // dorado claro
                                border: Border.all(
                                  color: Color(0xFF001F54), // Azul navy
                                  width: borderWidth,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: shadowBlur,
                                    offset: Offset(0, shadowDy),
                                  ),
                                ],
                              ),
                            ),
                
                            // Solapa animada que sube
                            AnimatedPositioned(
                              duration: const Duration(seconds: 1),
                              curve: Curves.easeInOut,
                              top: opened ? -flapLift : 0,
                              child: ClipPath(
                                clipper: EnvelopeFlapClipper(),
                                child: Container(
                                  width: envelopeWidth,
                                  height: envelopeHeight * flapHeightFactor,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFA7C7E7), // Azul celeste
                                        Color(0xFF001F54), // Azul navy
                                        Color(0xFF0A0A23), // Azul oscuro
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                
                            // Logo (posicionado relativo al sobre)
                            if (!opened)
                            Positioned(
                              bottom: envelopeHeight * 0.08,  // un poco afuera de la carta
                              right: envelopeWidth * 0.5 - (logoSize / 3), // centrado en la punta
                              child: CircleAvatar(
                                radius: logoSize / 3,
                                backgroundImage: AssetImage("lib/assets/Ad3.png"),
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                            const SizedBox(height: 50),
                            // Flecha animada justo debajo del logo
                            if (!opened)
                            Positioned(
                              bottom: envelopeHeight * 0.000000000000000000000000000000000000000000000000000000000001 - 0.5, // muy cerca de la punta
                              right: envelopeWidth * 0.5 - 25, // centrado horizontalmente
                              child: AnimatedBuilder(
                                animation: _arrowAnimation,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(0, _arrowAnimation.value),
                                    child: GestureDetector(
                                      onTap: _toggleEnvelope, // la flecha también abre la carta
                                      child: Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 50,
                                        color: const Color(0xFF001F54), // azul navy
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          // Texto superior (posicionado relativo al sobre)
                          if (!opened)
                            Positioned(
                              top: textTop,
                              left: textLeft,
                              child: AnimatedOpacity(
                                opacity: showText ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeInOut,
                                child: Text(
                                  "Estas invitado a nuestra boda",
                                  style: GoogleFonts.parisienne(
                                    fontSize: titleFont + 2,
                                    fontWeight: FontWeight.w400,
                                    color: Color.fromARGB(255, 248, 237, 203),
                                    // shadows: const [
                                    //   Shadow(
                                    //     color: Colors.white,
                                    //     blurRadius: 4,
                                    //     offset: Offset(2, 2),
                                    //   )
                                    // ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Botón central (solo visible si no está abierto)
                if (!opened)
                ElevatedButton(
                  onPressed: _toggleEnvelope,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF001F54), // Azul navy
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    "Oprime para abrir",
                    style: TextStyle(
                      fontSize: buttonFont,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class EnvelopeFlapClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
