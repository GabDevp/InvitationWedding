import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// ...

class CarruselConDots extends StatefulWidget {
  const CarruselConDots({super.key});

  @override
  State<CarruselConDots> createState() => _CarruselConDotsState();
}

class _CarruselConDotsState extends State<CarruselConDots> {
  final CarouselController _controller = CarouselController();
  int _activeIndex = 0;

  final List<Map<String, String>> items = [
    {"path": "lib/assets/1.jpeg"},
    {"path": "lib/assets/2.jpeg"},
    {"path": "lib/assets/4.jpeg"},
    {"path": "lib/assets/fondo1.jpg"},
    {"path": "lib/assets/fondo1.jpg"},
    {"path": "lib/assets/fondo1.jpg"},
    {"path": "lib/assets/fondo1.jpg"},
    {"path": "lib/assets/fondo1.jpg"},
    // {"path": "lib/assets/pareja6.jpg", "caption": "Un amor eterno ❤️"},
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🔲 Carrusel principal
        SizedBox(
          height: size.width > 600 ? size.height * 0.75 : size.height * 0.6,
          width: size.width > 600 ? size.width * 0.8 : size.width * 1.1,
          child: CarouselSlider(
            carouselController: _controller,
            items: items.map((item) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 📸 Imagen
                    Expanded(
                      flex: 8,
                      child: ClipRRect(
                        child: Image.asset(
                          item["path"]!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            options: CarouselOptions(
              height: size.height * 0.80,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 2),
              autoPlayAnimationDuration: const Duration(milliseconds: 600),
              viewportFraction: 0.65,
              enlargeCenterPage: true,
              enableInfiniteScroll: true,
              onPageChanged: (index, reason) {
                setState(() => _activeIndex = index);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 🔵 Dots indicator
        AnimatedSmoothIndicator(
          activeIndex: _activeIndex,
          count: items.length,
          effect: ExpandingDotsEffect(
            dotHeight: 10,
            dotWidth: 10,
            spacing: 8,
            activeDotColor: Colors.pinkAccent,
            dotColor: Colors.grey.shade400,
          ),
          onDotClicked: (index) => _controller.animateToPage(index),
        ),
      ],
    );
  }
}
