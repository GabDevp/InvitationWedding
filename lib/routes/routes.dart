
import 'package:flutter/material.dart';
import 'package:invitacion_boda/pages/envelope_pages.dart';
class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final path = settings.name ?? '';

    // Separamos la ruta en segmentos.
    final segments = path
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();

    if (segments.isNotEmpty &&
        segments[0] == 'sobre' &&
        segments.length > 1) {

      // Recuperamos el nombre completo de la URL.
      final nombreCodificado = segments.sublist(1).join('/');

      String nombreInvitado;

      try {
        // Decodificamos los caracteres UTF-8 de la URL.
        nombreInvitado = Uri.decodeComponent(nombreCodificado);
      } on FormatException {
        // Conservamos el valor original si la codificación es inválida.
        nombreInvitado = nombreCodificado;
      }

      // Convertimos los guiones en espacios.
      nombreInvitado = nombreInvitado.replaceAll('-', ' ');

      return GeneratePageRoute(
        widget: EnvelopeScreen(
          nombreInvitado: nombreInvitado,
        ),
        routeName: 'sobre',
      );
    }

    switch (path) {
      case 'sobre':
      case '/sobre':
        return GeneratePageRoute(
          widget: const EnvelopeScreen(),
          routeName: 'sobre',
        );

      default:
        return GeneratePageRoute(
          widget: const EnvelopeScreen(),
          routeName: 'sobre',
        );
    }
  }
}
class GeneratePageRoute extends PageRouteBuilder {
  final Widget? widget;
  final String? routeName;

  GeneratePageRoute({
    this.widget,
    this.routeName,
  }) : super(
          settings: RouteSettings(name: routeName),
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return widget!;
          },
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
}
