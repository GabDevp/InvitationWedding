// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invitacion_boda/widgets/floatingdecoration.dart';

class EnvelopeScreen extends StatefulWidget {
  final String? nombreInvitado;
  const EnvelopeScreen({super.key, this.nombreInvitado});

  @override
  State<EnvelopeScreen> createState() => _EnvelopeScreenState();
}

class _EnvelopeScreenState extends State<EnvelopeScreen>
    with TickerProviderStateMixin {
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
      final section2Trigger = 08.0;
      final section3Trigger = 145.0;
      final section4Trigger = 300.0;
      final section5Trigger = 450.0;

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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _section1Controller.dispose();
    _section2Controller.dispose();
    _section3Controller.dispose();
    _section4Controller.dispose();
    _section5Controller.dispose();
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
            child: Image.asset(
              'lib/assets/PHOTO-2.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Overlay oscuro sutil
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.pinkAccent.withValues(alpha: 0.1),
            ),
          ),

          const FloatingFloralDecoration(),

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
                          fontSize: isDesktop ? 48 : isTablet ? 40 : 34,
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
                        '14 de Noviembre',
                        style: GoogleFonts.roboto(
                          fontSize: isDesktop ? 30 : isTablet ? 26 : 22,
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

                // Separador
                SizedBox(
                  height: size.height * 0.008,
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
                        color: const Color(0xFFF4B6C2),
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
                        color: const Color(0xFFF4B6C2).withValues(alpha: 0.3),
                        child: Center(
                          child: Image.asset(
                            'lib/assets/PHOTO.jpg',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Separador
                SizedBox(
                  height: size.height * 0.008,
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
                      color: const Color(0xFFF4B6C2).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF4B6C2),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Mis XV Años',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isDesktop ? 56 : isTablet ? 48 : 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Finca Villa Palmas',
                          style: GoogleFonts.roboto(
                            fontSize: isDesktop ? 30 : isTablet ? 26 : 22,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Vía a San Carlos, entrada por Nariño',
                          style: GoogleFonts.roboto(
                            fontSize: isDesktop ? 24 : isTablet ? 20 : 16,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                // Separador
                SizedBox(
                  height: size.height * 0.008,
                ),

                // Sección 4: Código de vestimenta y Lluvia de Sobres (en 2 columnas)
                _buildSectionWithOffset(
                  animation: _section4Animation,
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 100 : isTablet ? 50 : 20,
                      vertical: isDesktop ? 5 : 2,
                    ),
                    padding: EdgeInsets.all(isDesktop ? 30 : 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4B6C2).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF4B6C2),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Columna 1: Código de vestimenta
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Código de Vestimenta',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: isDesktop ? 38 : isTablet ? 32 : 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 15),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Image.asset(
                                          'lib/assets/hombres.png',
                                          height: isDesktop ? 120 : isTablet ? 100 : 80,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Hombres',
                                          style: GoogleFonts.roboto(
                                            fontSize: isDesktop ? 24 : isTablet ? 20 : 18,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Image.asset(
                                          'lib/assets/mujeres.png',
                                          height: isDesktop ? 120 : isTablet ? 100 : 80,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Mujeres',
                                          style: GoogleFonts.roboto(
                                            fontSize: isDesktop ? 24 : isTablet ? 20 : 18,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Divider vertical
                        if (isDesktop || isTablet)
                          VerticalDivider(
                            thickness: 2,
                            color: Colors.white.withValues(alpha: 0.3),
                            indent: 10,
                            endIndent: 10,
                          ),
                        if (!isDesktop)
                          Divider(
                            thickness: 5,
                            color: Colors.white.withValues(alpha: 0.3),
                            height: 100,
                          ),
                        // Columna 2: Lluvia de Sobres
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                "Lluvia de Sobres 💌",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: isDesktop ? 38 : isTablet ? 32 : 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Si deseas honrarme con un detalle, una lluvia de sobres sería muy especial.",
                                style: GoogleFonts.nunito(
                                  fontSize: isDesktop ? 22 : isTablet ? 18 : 16,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Separador
                SizedBox(
                  height: size.height * 0.008,
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
                      color: const Color(0xFFF4B6C2),
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
                          'Hay momentos inolvidables que se atesoran en el corazón '
                          'para siempre, por esa razón quiero que compartas '
                          'conmigo este día tan especial.',
                          style: GoogleFonts.roboto(
                            fontSize: isDesktop ? 30 : isTablet ? 26 : 22,
                            color: Colors.white,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Con cariño,',
                          style: GoogleFonts.dancingScript(
                            fontSize: isDesktop ? 40 : isTablet ? 34 : 30,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _nombreInvitado.isNotEmpty ? _nombreInvitado : 'Belén',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isDesktop ? 38 : isTablet ? 32 : 26,
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

