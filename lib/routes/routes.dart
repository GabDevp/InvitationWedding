import 'package:flutter/material.dart';
import 'package:invitacion_boda/pages/pages.dart';

class RouteGenerator {
    static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case 'sobre':
        return GeneratePageRoute(
          widget: const EnvelopeScreen(),
          routeName: settings.name!,
        );
      case 'presentacion':
        return GeneratePageRoute(
          widget: const InvitacionPage(), // Aquí pones tu página de invitación
          routeName: settings.name!,
        );
      default:
        return GeneratePageRoute(
          widget: const EnvelopeScreen(),
          routeName: settings.name!,
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