import 'package:flutter/material.dart';
import 'auth_gate.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          surface: const Color.fromARGB(255, 0, 0, 0),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(), 
      routes: {
        '/auth-gate': (context) => const AuthGate(), // Define the route
      },
    );
  }
}