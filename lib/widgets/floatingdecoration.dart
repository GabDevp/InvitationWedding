import 'dart:math' as math;

import 'package:flutter/material.dart';

class FloatingFloralDecoration extends StatefulWidget {
  const FloatingFloralDecoration({super.key});

  @override
  State<FloatingFloralDecoration> createState() =>
      _FloatingFloralDecorationState();
}

class _FloatingFloralDecorationState
    extends State<FloatingFloralDecoration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // final Color pastelPink = const Color(0xFFF4B6C2);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * math.pi;

          return Stack(
            children: [
              // ROSA SUPERIOR IZQUIERDA
              Positioned(
                top: size.height * 0.05 + math.sin(t) * 15,
                left: size.width * 0.04,
                child: _floatingAsset(
                  asset: 'lib/assets/rosa.png',
                  size: 108,
                  rotation: math.sin(t) * 0.08,
                  opacity: 0.45,
                ),
              ),

              // MARIPOSA SUPERIOR DERECHA
              Positioned(
                top: size.height * 0.05 + math.sin(t + 1.5) * 15,
                right: size.width * 0.07 + math.cos(t) * 8,
                child: _floatingAsset(
                  asset: 'lib/assets/mariposa.png',
                  size: 112,
                  rotation: math.sin(t * 1.3) * 0.15,
                  opacity: 0.55,
                ),
              ),

              // ROSA CENTRO DERECHA
              Positioned(
                top: size.height * 0.30 + math.cos(t + 2) * 10,
                right: size.width * 0.03,
                child: _floatingAsset(
                  asset: 'lib/assets/rosa.png',
                  size: 108,
                  rotation: -0.3 + math.sin(t) * 0.1,
                  opacity: 0.35,
                ),
              ),

              // MARIPOSA CENTRO IZQUIERDA
              Positioned(
                top: size.height * 0.30 + math.sin(t + 3) * 12,
                left: size.width * 0.05 + math.cos(t) * 6,
                child: _floatingAsset(
                  asset: 'lib/assets/mariposa.png',
                  size: 112,
                  rotation: math.sin(t) * 0.2,
                  opacity: 0.45,
                ),
              ),

              // ROSA INFERIOR IZQUIERDA
              Positioned(
                bottom: size.height * 0.20 + math.sin(t + 4) * 8,
                left: size.width * 0.03,
                child: _floatingAsset(
                  asset: 'lib/assets/rosa.png',
                  size: 108,
                  rotation: 0.25 + math.sin(t) * 0.08,
                  opacity: 0.4,
                ),
              ),

              // MARIPOSA INFERIOR DERECHA
              Positioned(
                bottom: size.height * 0.20 + math.sin(t + 5) * 18,
                right: size.width * 0.09 + math.cos(t) * 7,
                child: _floatingAsset(
                  asset: 'lib/assets/mariposa.png',
                  size: 112,
                  rotation: -0.2 + math.sin(t) * 0.18,
                  opacity: 0.5,
                ),
              ),

              // ROSA CENTRO SUPERIOR
              Positioned(
                top: size.height * 0.22 + math.sin(t + 0.5) * 10,
                left: size.width * 0.40,
                child: _floatingAsset(
                  asset: 'lib/assets/rosa.png',
                  size: 70,
                  rotation: math.sin(t) * 0.12,
                  opacity: 0.30,
                ),
              ),

              // MARIPOSA CENTRO DERECHA
              Positioned(
                top: size.height * 0.90 + math.cos(t + 1) * 15,
                right: size.width * 0.02,
                child: _floatingAsset(
                  asset: 'lib/assets/mariposa.png',
                  size: 100,
                  rotation: math.sin(t * 1.5) * 0.25,
                  opacity: 0.55,
                ),
              ),

              // ROSA CENTRO INFERIOR
              Positioned(
                top: size.height * 0.90 + math.sin(t + 2) * 12,
                left: size.width * 0.42,
                child: _floatingAsset(
                  asset: 'lib/assets/rosa.png',
                  size: 75,
                  rotation: -0.2 + math.sin(t) * 0.1,
                  opacity: 0.55,
                ),
              ),

              // MARIPOSA INFERIOR CENTRO
              Positioned(
                bottom: size.height * 0.0001 + math.cos(t + 3) * 12,
                left: size.width * 0.03,
                child: _floatingAsset(
                  asset: 'lib/assets/mariposa.png',
                  size: 108,
                  rotation: math.sin(t) * 0.20,
                  opacity: 0.55,
                ),
              ),

              // ROSA LATERAL DERECHA
              Positioned(
                top: size.height * 0.50 + math.sin(t + 4) * 10,
                right: size.width * 0.40,
                child: _floatingAsset(
                  asset: 'lib/assets/rosa.png',
                  size: 80,
                  rotation: 0.15 + math.sin(t) * 0.08,
                  opacity: 0.60,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _floatingAsset({
    required String asset,
    required double size,
    required double rotation,
    required double opacity,
  }) {
    return Transform.rotate(
      angle: rotation,
      child: Opacity(
        opacity: opacity,
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,

          // Comenta estas dos líneas si las imágenes
          // ya vienen en color rosa.
          // color: pastelPink,
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );
  }
}