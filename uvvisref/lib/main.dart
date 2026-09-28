import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(UVVisRefApp());
}

class UVVisRefApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UVVisRef',
      theme: ThemeData.dark(),
      home: HomeScreen(),
    );
  }
}
