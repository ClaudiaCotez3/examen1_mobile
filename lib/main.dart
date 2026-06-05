import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'theme.dart';

/// Portal móvil del CLIENTE.
///
/// Un cliente que ya abrió un trámite en atención al cliente se identifica
/// con su correo + CI (los datos que dio en el formulario inicial) y puede:
///   - ver sus trámites y en qué parte del flujo están (Dashboard), y
///   - iniciar un trámite nuevo describiendo su necesidad en lenguaje
///     natural — la IA identifica el trámite adecuado y carga su
///     formulario (Módulo 3).
void main() {
  runApp(const ClientePortalApp());
}

class ClientePortalApp extends StatelessWidget {
  const ClientePortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mis Trámites',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LoginScreen(),
    );
  }
}
