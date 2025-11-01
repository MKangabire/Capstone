// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mama_safe/services/supabase_service.dart';
import 'package:mama_safe/screens/splash_screen.dart'; // Add this import
import 'package:mama_safe/screens/setup_admin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const SplashScreen(), // This will now use the one from screens/splash_screen.dart
      debugShowCheckedModeBanner: false,
    );
  }
}

// DELETE the entire SplashScreen class that's currently here (lines 23-202)