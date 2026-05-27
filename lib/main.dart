import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const GameCounterApp());
}

class GameCounterApp extends StatelessWidget {
  const GameCounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameCounter',
      theme: ThemeData.dark(), 
      home: const HomeScreen(),
    );
  }
}

