import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  runApp(const EcoNexusApp());
}

class EcoNexusApp extends StatelessWidget {
  const EcoNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '永續之森 EcoNexus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // 現代森林綠
          background: const Color(0xFFF5F7F5), // 帶有一點點綠意的低飽和灰白背景
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}