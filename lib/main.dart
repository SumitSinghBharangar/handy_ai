import 'package:flutter/material.dart';

import 'package:handy_ai/screens/live_tracker_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: LiveTrackerView(),
    );
  }
}
