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

class _EnvelopeScreenState extends State<EnvelopeScreen>
    with TickerProviderStateMixin {
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  bool opened = false;
  bool _dataLoaded = false;
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
    if (_nombreInvitado.isEmpty) {
      setState(() => _dataLoaded = true);
      return;
    }

    try {
      final raw = await SheetsService.getGuest(_nombreInvitado);
      if (raw != null) {
        // 🔥 Conversión segura
        final guestData = Map<String, dynamic>.from(raw);
        setState(() {
          _guestName = guestData['key_normalized'] ?? _nombreInvitado;
          _guestDisplayName = guestData['display'] ?? _nombreInvitado;
          _guestPasses = int.tryParse(guestData['passesRemaining'].toString()) ?? 0;
          _guestPassesConfirmed = int.tryParse(guestData['confirmedCount'].toString()) ?? 0;
          _dataLoaded = true;
        });
      } else {
        setState(() => _dataLoaded = true);
      }
    } catch (e) {
      debugPrint('Error obteniendo invitado: $e');

      setState(() => _dataLoaded = true);
    }
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  void _toggleEnvelope() async {
    if (opened) return;

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (_, animation, __) => InvitacionPage(
          guestName: _guestName,
          guestDisplayName: _guestDisplayName,
          guestPasses: _guestPasses,
          guestConfirmedCount: _guestPassesConfirmed,
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
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/gif.gif'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black12,
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          if (!opened && _dataLoaded && _guestDisplayName != null)
          Positioned(
            bottom: size.height * 0.52,
            left: 0,
            right: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("¡Hola ${_guestDisplayName ?? _nombreInvitado}!",
                  style: GoogleFonts.baloo2(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    shadows: [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  )
                ),
                Text("Nuestro pequeño",
                  style: GoogleFonts.parisienne(
                    fontWeight: FontWeight.bold,
                    fontSize: 50,
                    color: Colors.green[900],
                    shadows: [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                Text("Príncipe",
                  style: GoogleFonts.baloo2(
                    fontSize: 40,
                    color: Colors.brown[700],
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                Text("Esta en camino",
                  style: GoogleFonts.parisienne(
                    fontWeight: FontWeight.bold,
                    fontSize: 50,
                    color: Colors.brown[700],
                    shadows: [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          if (!opened && _dataLoaded && _guestDisplayName != null)
          Positioned(
            top: size.height * 0.50,
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
        ],
      ),
    );
  }
}