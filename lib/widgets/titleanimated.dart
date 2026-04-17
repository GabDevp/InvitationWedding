import 'package:flutter/material.dart';

class TitleAnimated extends StatefulWidget {
  const TitleAnimated({super.key});

  @override
  State<TitleAnimated> createState() => _TitleAnimatedState();
}

class _TitleAnimatedState extends State<TitleAnimated>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  final colors = [
    Color(0xFF2E7D32), // verde oscuro
    Color(0xFFA5D6A7), // verde claro
    Color(0xFF1B5E20),
    Color(0xFF81C784),
  ];

  final letters = ['B', 'A', 'B', 'Y'];

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(4, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + (i * 150)),
      )..repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(letters.length, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (_, child) {
            return Transform.translate(
              offset: Offset(0, -10 * _controllers[i].value),
              child: child,
            );
          },
          child: Container(
            // margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors[i],
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(2, 3),
                )
              ],
            ),
            child: Text(
              letters[i],
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      }),
    );
  }
}