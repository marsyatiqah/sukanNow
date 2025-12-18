// welcome.dart

import 'package:flutter/material.dart';
import 'package:concentric_transition/concentric_transition.dart';
import 'auth_gate.dart'; // Import to access PageData

class ConcentricAnimationOnboarding extends StatelessWidget {
  final List<PageData> pages; // Add pages parameter
  final VoidCallback onFinished;

  const ConcentricAnimationOnboarding({
    super.key,
    required this.pages, // Make pages required
    required this.onFinished,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ConcentricPageView( // Use ConcentricPageView here
          colors: pages.map((e) => e.bgColor).toList(),
          itemCount: pages.length,
          itemBuilder: (int index) { 
            return _Page(page: pages[index], onFinished: onFinished);
          },
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final PageData page;
  final VoidCallback onFinished;

  const _Page({required this.page, required this.onFinished});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          page.icon,
          size: screenHeight * 0.1,
          color: page.titleColor,
        ),
        const SizedBox(height: 20),
        Text(
          page.title!, // Use ! since title is nullable
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: screenHeight * 0.05,
            fontWeight: FontWeight.bold,
            color: page.titleColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          page.subtitle!, // Use ! since subtitle is nullable
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: screenHeight * 0.022,
            color: page.subtitleColor,
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: onFinished,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
          ),
          child: const Text("Get Started", style: TextStyle(fontSize: 20)),
        )
      ],
    );
  }
}