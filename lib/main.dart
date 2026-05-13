import 'dart:developer';
import 'package:betterroads/python_channel.dart';
import 'package:flutter/material.dart';

import 'screens/map_screen.dart';

void main() {
  runApp(const MyApp());

    PythonChannel.exampleFunction('Text sent from Dart.').then((result) {
      log('Result: $result');
    }).catchError((error) {
      log('Error: $error');
    });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Better Roads',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MapScreen(),
    );
  }
}

