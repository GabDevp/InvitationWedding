
import 'package:flutter/material.dart';
import 'package:invitacion_boda/routes/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WeddingInviteApp());
}

class WeddingInviteApp extends StatelessWidget {
  const WeddingInviteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi fiesta',
      debugShowCheckedModeBanner: false,
      initialRoute: 'sobre',
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}