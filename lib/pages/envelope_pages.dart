// ignore_for_file: unused_field

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
class EnvelopeScreen extends StatefulWidget {
  final String? nombreInvitado;
  const EnvelopeScreen({super.key, this.nombreInvitado});

  @override
  State<EnvelopeScreen> createState() => _EnvelopeScreenState();
}

class CircuitBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFD4AF37).withOpacity(0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final random = math.Random(42);
    
    // Dibujar líneas de circuito
    for (int i = 0; i < 30; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      
      final path = Path();
      path.moveTo(startX, startY);
      
      // Crear patrón de circuito
      for (int j = 0; j < 4; j++) {
        final direction = random.nextInt(4);
        final length = 30 + random.nextDouble() * 50;
        
        switch (direction) {
          case 0:
            path.relativeLineTo(length, 0);
            break;
          case 1:
            path.relativeLineTo(0, length);
            break;
          case 2:
            path.relativeLineTo(-length, 0);
            break;
          case 3:
            path.relativeLineTo(0, -length);
            break;
        }
      }
      
      canvas.drawPath(path, paint);
    }
    
    // Dibujar puntos de conexión
    final dotPaint = Paint()
      ..color = Color(0xFFD4AF37).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _EnvelopeScreenState extends State<EnvelopeScreen>
    with TickerProviderStateMixin {
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  bool opened = false;
  bool _dataLoaded = true; // Siempre true ya que no necesitamos cargar datos
  String _nombreInvitado = '';

  @override
  void initState() {
    super.initState();

    _nombreInvitado = widget.nombreInvitado ?? '';

    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
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

  Widget _buildInfoRow(String text, IconData icon, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: Color(0xFFD4AF37),
          size: isMobile ? 22 : 26,
        ),
        SizedBox(width: 12),
        Text(
          text,
          style: GoogleFonts.roboto(
            fontSize: isMobile ? 18 : 22,
            fontWeight: FontWeight.w300,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fondo oscuro con patrón de circuito
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0A0A),
                  Color(0xFF1A1A1A),
                  Color(0xFF0D0D0D),
                ],
              ),
            ),
            child: CustomPaint(
              painter: CircuitBoardPainter(),
              size: Size.infinite,
            ),
          ),


          // Contenido central - Invitación de Graduación
          if (!opened && _dataLoaded)
            Positioned(
              top: size.height * 0.12,
              left: 0,
              right: 0,
              child: Center(
                child: Stack(
                  children: [
                    Container(
                      width: isMobile ? size.width * 0.92 : size.width * 0.75,
                      padding: EdgeInsets.all(isMobile ? 32 : 50),
                      decoration: BoxDecoration(
                        color: Color(0xFF0D0D0D),
                        border: Border.all(
                          color: Color(0xFFD4AF37),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFD4AF37).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Decoración superior
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Color(0xFFD4AF37)],
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(
                            Icons.star,
                            color: Color(0xFFD4AF37),
                            size: isMobile ? 24 : 28,
                          ),
                          SizedBox(width: 10),
                          Container(
                            width: 40,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFD4AF37), Colors.transparent],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 20 : 30),
                      
                      // Título principal
                      Text(
                        "CENA POR MOTIVO DE GRADO",
                        style: GoogleFonts.cinzel(
                          fontSize: isMobile ? 30 : 40,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD4AF37),
                          shadows: [
                            Shadow(
                              color: Color(0xFFD4AF37).withOpacity(0.5),
                              blurRadius: 10,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isMobile ? 15 : 20),
                      
                      // Carrera
                      Text(
                        "Ingeniero Electrónico",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: isMobile ? 26 : 32,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: isMobile ? 10 : 15),
                      
                      // Nombre del graduando
                      Text(
                        "Juan Esteban Lopez",
                        style: GoogleFonts.roboto(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.w300,
                          color: Colors.white70,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: isMobile ? 20 : 25),
                      
                      // Línea dorada
                      Container(
                        height: 2,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFFD4AF37),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 25 : 30),
                      
                      // Información del evento
                      _buildInfoRow(
                        "Fecha: 30 / 05 / 2026",
                        Icons.calendar_today,
                        isMobile,
                      ),
                      SizedBox(height: isMobile ? 20 : 25),
                      _buildInfoRow(
                        "Hora: 07:00 PM",
                        Icons.access_time,
                        isMobile,
                      ),
                      SizedBox(height: isMobile ? 20 : 25),
                      _buildInfoRow(
                        "Lugar: Calle 32 #35-33",
                        Icons.location_on,
                        isMobile,
                      ),
                      
                      SizedBox(height: isMobile ? 20 : 25),
                      
                      // Decoración inferior
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Color(0xFFD4AF37)],
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.star,
                            color: Color(0xFFD4AF37),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 30,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFD4AF37), Colors.transparent],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                  // Birrete en esquina superior izquierda
                  Positioned(
                    top: -25,
                    left: -15,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF0D0D0D),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Color(0xFFD4AF37),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFD4AF37).withOpacity(0.5),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Text(
                        '🎓',
                        style: TextStyle(
                          fontSize: isMobile ? 65 : 75,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

