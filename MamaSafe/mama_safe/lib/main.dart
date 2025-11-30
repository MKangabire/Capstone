// lib/main.dart
import 'package:flutter/material.dart';
import 'package:mama_safe/services/supabase_service.dart';
import 'package:mama_safe/screens/splash_screen.dart';
import 'package:mama_safe/screens/setup_admin_screen.dart';
import 'package:mama_safe/screens/login_screen.dart';
import 'package:mama_safe/screens/patient/patient_dashboard.dart';
import 'package:mama_safe/screens/chw/chw_dashboard.dart';
import 'package:mama_safe/screens/admin/admin_dashboard.dart';
import 'package:mama_safe/screens/patient/profile_completion_screen.dart';

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
      title: 'MamaSafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      // Start with splash screen (which will handle auth checking)
      home: const SplashScreen(),
      // Define named routes for easy navigation
      routes: {
        '/login': (context) => const LoginScreen(),
        '/patient-dashboard': (context) => const PatientDashboard(),
        '/chw-dashboard': (context) => const CHWDashboard(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/profile-completion': (context) => const ProfileCompletionScreen(),
        '/setup-admin': (context) => const SetupAdminScreen(),
      },
    );
  }
}