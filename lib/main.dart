import 'package:flutter/material.dart';
import 'splash_screen.dart';

void main() {
  runApp(const OperatorsUnionApp());
}

class OperatorsUnionApp extends StatelessWidget {
  const OperatorsUnionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Login • Operator's Union",
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
