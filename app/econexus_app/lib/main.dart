import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, 
  ));
  
  runApp(const EcoNexusApp());
}

class EcoNexusApp extends StatelessWidget {
  const EcoNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '永續之森 EcoNexus',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, 
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark, 
        
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C4B4), 
          brightness: Brightness.dark,
          primary: const Color(0xFF00C4B4),
          surface: const Color(0xFF121212), // M3 取代 background 的寫法
        ),
        
        scaffoldBackgroundColor: const Color(0xFF121212),
        
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