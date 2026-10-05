// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

class EnvelopeScreen extends StatefulWidget {
  final String? nombreInvitado;
  const EnvelopeScreen({super.key, this.nombreInvitado});

  @override
  State<EnvelopeScreen> createState() => _EnvelopeScreenState();
}

class _EnvelopeScreenState extends State<EnvelopeScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  late ScrollController _scrollController;
  
  // Animation Controllers para cada sección
  late AnimationController _section1Controller;
  late AnimationController _section2Controller;
  late AnimationController _section3Controller;
  late AnimationController _section4Controller;
  late AnimationController _section5Controller;
  
  // Animaciones de deslizamiento
  late Animation<Offset> _section1Animation;
  late Animation<Offset> _section2Animation;
  late Animation<Offset> _section3Animation;
  late Animation<Offset> _section4Animation;
  late Animation<Offset> _section5Animation;
  
  bool _videoLoaded = false;
  String _nombreInvitado = '';

  @override
  void initState() {
    super.initState();

    _nombreInvitado = widget.nombreInvitado ?? '';

    _scrollController = ScrollController();

    // Inicializar AnimationControllers
    _section1Controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _section2Controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _section3Controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _section4Controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _section5Controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Crear animaciones de deslizamiento
    // Sección 1: Sin animación (estática)
    _section1Animation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _section1Controller,
      curve: Curves.easeOutCubic,
    ));
    
    // Sección 2: Desde la derecha
    _section2Animation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _section2Controller,
      curve: Curves.easeOutCubic,
    ));
    
    // Sección 3: Desde la derecha
    _section3Animation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _section3Controller,
      curve: Curves.easeOutCubic,
    ));
    
    // Sección 4: Desde la derecha
    _section4Animation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _section4Controller,
      curve: Curves.easeOutCubic,
    ));
    
    _section5Animation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _section5Controller,
      curve: Curves.easeOutCubic,
    ));

    // Listener del scroll para controlar animaciones
    _scrollController.addListener(() {
      final scrollPosition = _scrollController.offset;
      final section2Trigger = 10.0;
      final section3Trigger = 160.0;
      final section4Trigger = 380.0;
      final section5Trigger = 530.0;

      // Sección 1: Sin animación (estática)

      // Controlar animación de sección 2
      if (scrollPosition > section2Trigger && !_section2Controller.isCompleted) {
        _section2Controller.forward();
      } else if (scrollPosition <= section2Trigger && _section2Controller.isCompleted) {
        _section2Controller.reverse();
      }

      // Controlar animación de sección 3
      if (scrollPosition > section3Trigger && !_section3Controller.isCompleted) {
        _section3Controller.forward();
      } else if (scrollPosition <= section3Trigger && _section3Controller.isCompleted) {
        _section3Controller.reverse();
      }

      // Controlar animación de sección 4
      if (scrollPosition > section4Trigger && !_section4Controller.isCompleted) {
        _section4Controller.forward();
      } else if (scrollPosition <= section4Trigger && _section4Controller.isCompleted) {
        _section4Controller.reverse();
      }

      // Controlar animación de sección 5
      if (scrollPosition > section5Trigger && !_section5Controller.isCompleted) {
        _section5Controller.forward();
      } else if (scrollPosition <= section5Trigger && _section5Controller.isCompleted) {
        _section5Controller.reverse();
      }
    });

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
    _scrollController.dispose();
    _section1Controller.dispose();
    _section2Controller.dispose();
    _section3Controller.dispose();
    _section4Controller.dispose();
    _section5Controller.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Widget _buildSectionWithOffset({
    required Widget child,
    required Animation<Offset> animation,
  }) {
    return SlideTransition(
      position: animation,
      child: child,
    );
  }

  void _showDressCodeDialog(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: isMobile ? size.width * 0.9 : size.width * 0.6,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFB08D57),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Código de Vestimenta',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Image.asset(
                            'lib/assets/hombres.png',
                            height: isMobile ? 100 : 150,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hombres',
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          Image.asset(
                            'lib/assets/mujeres.png',
                            height: isMobile ? 100 : 150,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Mujeres',
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB08D57),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600 && size.width < 1024;
    final isDesktop = size.width >= 1024;

    return Scaffold(
      backgroundColor: Colors.black54,
      body: Stack(
        children: [
          // Fondo con video o fallback a gradiente
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: _videoLoaded && _videoController.value.isInitialized
                ? VideoPlayer(_videoController)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                      ),
                    ),
                  ),
          ),

          // Overlay oscuro sutil
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),

          // Contenido principal - Scrollable
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                // Sección 1: Nombre de invitado + fecha (sin animación)
                Container(
                  padding: EdgeInsets.only(
                    top: isDesktop ? 60 : 40,
                    bottom: isDesktop ? 30 : 20,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _nombreInvitado.isNotEmpty ? _nombreInvitado : 'Invitado Especial',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: isDesktop ? 32 : isTablet ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '18 de Julio 2026',
                        style: GoogleFonts.roboto(
                          fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Separador floral
                Container(
                  height: size.height * 0.1,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('lib/assets/flores.png'),
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      repeat: ImageRepeat.repeatX,
                      scale: 1,
                    ),
                  ),
                ),

                // Sección 2: Foto personal grande de la quinceañera
                _buildSectionWithOffset(
                  animation: _section2Animation,
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 100 : isTablet ? 50 : 10,
                      vertical: isDesktop ? 5 : 2,
                    ),
                    height: isDesktop ? 500 : isTablet ? 700 : 500,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFB08D57),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: const Color(0xFFB08D57).withValues(alpha: 0.3),
                        child: Center(
                          child: Text(
                            'Foto de la Quinceañera',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: isDesktop ? 24 : 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Separador floral
                Container(
                  height: size.height * 0.1,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('lib/assets/flores.png'),
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      repeat: ImageRepeat.repeatX,
                      scale: 1,
                    ),
                  ),
                ),

                // Sección 3: Lugar + nombre del evento
                _buildSectionWithOffset(
                  animation: _section3Animation,
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 100 : isTablet ? 50 : 20,
                      vertical: isDesktop ? 5 : 2,
                    ),
                    padding: EdgeInsets.all(isDesktop ? 30 : 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB08D57).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFB08D57),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Mis XV Años',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isDesktop ? 36 : isTablet ? 30 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Salón de Eventos El Jardín',
                          style: GoogleFonts.roboto(
                            fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Calle Principal #123, Tuluá, Valle',
                          style: GoogleFonts.roboto(
                            fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                // Separador floral
                Container(
                  height: size.height * 0.1,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('lib/assets/flores.png'),
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      repeat: ImageRepeat.repeatX,
                      scale: 1,
                    ),
                  ),
                ),

                // Sección 4: Código de vestimenta
                _buildSectionWithOffset(
                  animation: _section4Animation,
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 100 : isTablet ? 50 : 20,
                      vertical: isDesktop ? 5 : 2,
                    ),
                    child: ElevatedButton(
                      onPressed: () => _showDressCodeDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB08D57),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 40 : 30,
                          vertical: isDesktop ? 20 : 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Ver Código de Vestimenta',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                // Separador floral
                Container(
                  height: size.height * 0.1,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('lib/assets/flores.png'),
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      repeat: ImageRepeat.repeatX,
                      scale: 1,
                    ),
                  ),
                ),

                // Sección 5: Nota de agradecimiento con efecto de resaltar
                _buildSectionWithOffset(
                  animation: _section5Animation,
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 100 : isTablet ? 50 : 20,
                      vertical: isDesktop ? 15 : 10,
                    ),
                    padding: EdgeInsets.all(isDesktop ? 30 : 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB08D57),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Nota de Agradecimiento',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isDesktop ? 28 : isTablet ? 24 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Gracias por ser parte de este momento tan especial en mi vida. '
                          'Su presencia hace este día aún más memorable.',
                          style: GoogleFonts.roboto(
                            fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                            color: Colors.white,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Con cariño,',
                          style: GoogleFonts.dancingScript(
                            fontSize: isDesktop ? 24 : isTablet ? 20 : 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _nombreInvitado.isNotEmpty ? _nombreInvitado : 'La Quinceañera',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isDesktop ? 22 : isTablet ? 18 : 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Espacio al final
                SizedBox(height: isDesktop ? 80 : 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

