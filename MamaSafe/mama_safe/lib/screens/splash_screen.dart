                              // lib/screens/splash_screen.dart
                              import 'package:flutter/material.dart';
                              import 'package:mama_safe/services/auth_service.dart';
                              import 'package:mama_safe/services/supabase_service.dart';
                              import 'package:mama_safe/screens/login_screen.dart';
                              import 'package:mama_safe/screens/patient/patient_dashboard.dart';
                              import 'package:mama_safe/screens/chw/chw_dashboard.dart';
                              import 'package:mama_safe/screens/admin/admin_dashboard.dart';
                              import 'package:mama_safe/screens/patient/profile_completion_screen.dart';
                              import 'package:mama_safe/screens/setup_admin_screen.dart';

                              class SplashScreen extends StatefulWidget {
                                const SplashScreen({super.key});

                                @override
                                State<SplashScreen> createState() => _SplashScreenState();
                              }

                              class _SplashScreenState extends State<SplashScreen> 
                                  with SingleTickerProviderStateMixin {
                                final AuthService _authService = AuthService();
                                final _supabase = SupabaseService.client;
                                late AnimationController _animationController;
                                late Animation<double> _fadeAnimation;
                                late Animation<double> _scaleAnimation;

                                @override
                                void initState() {
                                  super.initState();
                                  
                                  // Setup animations
                                  _animationController = AnimationController(
                                    vsync: this,
                                    duration: const Duration(milliseconds: 1500),
                                  );

                                  _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                                    CurvedAnimation(
                                      parent: _animationController,
                                      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
                                    ),
                                  );

                                  _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
                                    CurvedAnimation(
                                      parent: _animationController,
                                      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
                                    ),
                                  );

                                  _animationController.forward();
                                  
                                  // Check authentication and navigate
                                  _initializeApp();
                                }

                                @override
                                void dispose() {
                                  _animationController.dispose();
                                  super.dispose();
                                }

                                Future<void> _initializeApp() async {
                                  // Wait for animation to complete
                                  await Future.delayed(const Duration(seconds: 2));

                                  if (!mounted) return;

                                  try {
                                    // Check if this is first run (no admin exists)
                                    final adminCheck = await _supabase
                                        .from('profiles')
                                        .select('id')
                                        .eq('role', 'admin')
                                        .limit(1);

                                    if (adminCheck.isEmpty) {
                                      // No admin exists, go to setup
                                      if (mounted) {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (context) => const SetupAdminScreen()),
                                        );
                                      }
                                      return;
                                    }

                                    // Admin exists, check if user is logged in
                                    final isLoggedIn = await _authService.isLoggedIn;

                                    if (!mounted) return;

                                    if (isLoggedIn) {
                                      // User is logged in, get their role and navigate
                                      final profile = await _authService.getProfile();
                                      final role = profile['role'] as String;

                                      if (!mounted) return;

                                      if (role == 'patient') {
                                        // Check if profile is complete
                                        final isComplete = await _authService.isProfileComplete();

                                        if (!mounted) return;

                                        if (isComplete) {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(builder: (context) => const PatientDashboard()),
                                          );
                                        } else {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(builder: (context) => const ProfileCompletionScreen()),
                                          );
                                        }
                                      } else if (role == 'chw') {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (context) => const CHWDashboard()),
                                        );
                                      } else if (role == 'admin') {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (context) => const AdminDashboard()),
                                        );
                                      }
                                    } else {
                                      // User is not logged in, show login screen
                                      if (mounted) {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    print('Error during initialization: $e');
                                    // On error, show login screen
                                    if (mounted) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                                      );
                                    }
                                  }
                                }

                                @override
                                Widget build(BuildContext context) {
                                  return Scaffold(
                                    body: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.pink[300]!,
                                            Colors.pink[400]!,
                                            Colors.pink[500]!,
                                            Colors.purple[400]!,
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: AnimatedBuilder(
                                          animation: _animationController,
                                          builder: (context, child) {
                                            return FadeTransition(
                                              opacity: _fadeAnimation,
                                              child: ScaleTransition(
                                                scale: _scaleAnimation,
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    // App Logo
                                                    Container(
                                                      width: 140,
                                                      height: 140,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.2),
                                                            blurRadius: 30,
                                                            offset: const Offset(0, 15),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Center(
                                                        child: Icon(
                                                          Icons.pregnant_woman_rounded,
                                                          size: 80,
                                                          color: Colors.pink[400],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 32),
                                                    
                                                    // App Name
                                                    const Text(
                                                      'MamaSafe',
                                                      style: TextStyle(
                                                        fontSize: 48,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                        letterSpacing: 2,
                                                        shadows: [
                                                          Shadow(
                                                            color: Colors.black26,
                                                            offset: Offset(0, 4),
                                                            blurRadius: 8,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    
                                                    // Tagline
                                                    Text(
                                                      'Predicting GDM Risk',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        color: Colors.white.withOpacity(0.95),
                                                        fontWeight: FontWeight.w500,
                                                        letterSpacing: 1,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 60),
                                                    
                                                    // Loading Indicator
                                                    SizedBox(
                                                      width: 50,
                                                      height: 50,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 3,
                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                          Colors.white.withOpacity(0.8),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    
                                                    Text(
                                                      'Loading...',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.white.withOpacity(0.9),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }