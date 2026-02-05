import 'package:flutter/material.dart';
import 'package:invitacion_boda/pages/pages.dart';

class RouteGenerator {
    static Route<dynamic> generateRoute(RouteSettings settings) {
     final path = settings.name ?? '';
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
 
    if (segments.isNotEmpty && segments[0] == 'sobre' && segments.length > 1) {
      // Maneja ambos formatos:
      // - /sobre/nombre
      // - /sobre/nombre1 y nombre2
      final nombre = segments.sublist(1).join('/');
      final nombreInvitado = nombre.replaceAll('%20%', '');
      
      return GeneratePageRoute(
        widget: EnvelopeScreen(nombreInvitado: nombreInvitado),
        routeName: 'sobre',
      );
    }
 
    switch (path) {
      case 'sobre':
        return GeneratePageRoute(
          widget: const EnvelopeScreen(),
          routeName: 'sobre',
        );
      case 'presentacion':
        return GeneratePageRoute(
          widget: const InvitacionPage(),
          routeName: 'presentacion',
        );
      default:
        return GeneratePageRoute(
          widget: const EnvelopeScreen(),
          routeName: 'home',
        );
    }
  }
}

class GeneratePageRoute extends PageRouteBuilder{
  final Widget? widget;
  final String? routeName;

  GeneratePageRoute({this.widget, this.routeName})
  : super(
    settings: RouteSettings(name: routeName),
    pageBuilder: (BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation) {
      return widget!;
    },
    transitionDuration: const Duration(milliseconds: 800),
    transitionsBuilder: (BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    }
  );
}