// lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  final _supabase = SupabaseService.client;

  User? get currentUser => _supabase.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // ✅ FIXED: Get role from metadata only
  Future<String?> getUserRole() async {
    if (currentUser == null) {
      print('No current user for role check');
      return null;
    }
    
    final role = currentUser!.userMetadata?['role']?.toString();
    print('Role from metadata: $role');
    return role ?? 'patient';
  }

  // ✅ FIXED: Check profile completion WITHOUT querying database
  Future<bool> isProfileComplete() async {
    if (currentUser == null) {
      print('No current user for profile check');
      return false;
    }
    
    try {
      print('Checking profile completion for user: ${currentUser!.id}');
      
      // Get from metadata first
      final metadata = currentUser!.userMetadata;
      if (metadata != null) {
        final hasAge = metadata['age'] != null;
        final hasHeight = metadata['height'] != null;
        final hasWeight = metadata['weight'] != null;
        
        if (hasAge && hasHeight && hasWeight) {
          print('Profile complete from metadata');
          return true;
        }
      }
      
      // If not in metadata, need to query database
      // Use a service role or accept that it might fail
      print('Metadata incomplete, assuming profile needs completion');
      return false;
    } catch (e) {
      print('Error checking profile: $e');
      // On error, assume profile needs completion
      return false;
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    int? age,
    double? height,
    double? weight,
    double? bmi,
    String? region,
    String? phone,
  }) async {
    try {
      final user = currentUser;
      if (user == null) return {'success': false, 'error': 'No user logged in'};

      print('🔍 Updating profile for user: ${user.id}');
      
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (age != null) updates['age'] = age;
      if (height != null) updates['height'] = height;
      if (weight != null) updates['weight'] = weight;
      if (bmi != null) updates['bmi'] = bmi;
      if (region != null) updates['region'] = region;
      if (phone != null) updates['phone'] = phone;
      
      updates['updated_at'] = DateTime.now().toIso8601String();

      print('🔍 Updates being saved: $updates');

      await _supabase.from('profiles').update(updates).eq('id', user.id);
      
      // ✅ ALSO UPDATE USER METADATA
      final metadataUpdates = <String, dynamic>{};
      if (fullName != null) metadataUpdates['full_name'] = fullName;
      if (age != null) metadataUpdates['age'] = age;
      if (height != null) metadataUpdates['height'] = height;
      if (weight != null) metadataUpdates['weight'] = weight;
      if (phone != null) metadataUpdates['phone'] = phone;
      
      if (metadataUpdates.isNotEmpty) {
        await _supabase.auth.updateUser(
          UserAttributes(data: metadataUpdates),
        );
        print('✅ Metadata also updated');
      }
      
      print('✅ Profile updated successfully');
      return {'success': true};
    } catch (e) {
      print('❌ Error updating profile: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ✅ FIXED: Get profile with fallback
  Future<Map<String, dynamic>> getProfile() async {
    if (currentUser == null) {
      print('No current user for profile fetch');
      return {};
    }
    
    try {
      print('Fetching full profile for user: ${currentUser!.id}');
      
      final response = await _supabase
          .from('profiles')
          .select('full_name, email, phone, age, height, weight, bmi, region, role, chw_id')
          .eq('id', currentUser!.id)
          .maybeSingle();
      
      if (response != null) {
        print('✅ Full profile fetched from database');
        return response;
      } else {
        print('⚠️ No profile in database, using metadata');
        return _getProfileFromMetadata();
      }
    } catch (e) {
      print('❌ Error fetching profile: $e');
      return _getProfileFromMetadata();
    }
  }

  // ✅ Helper method to get profile from metadata
  Map<String, dynamic> _getProfileFromMetadata() {
    if (currentUser == null) return {};
    
    final metadata = currentUser!.userMetadata ?? {};
    return {
      'id': currentUser!.id,
      'email': currentUser!.email ?? '',
      'full_name': metadata['full_name'] ?? '',
      'phone': metadata['phone'] ?? '',
      'age': metadata['age'],
      'height': metadata['height'],
      'weight': metadata['weight'],
      'bmi': metadata['bmi'],
      'region': metadata['region'],
      'role': metadata['role'] ?? 'patient',
    };
  }

  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    try {
      if (!['patient', 'chw', 'admin'].contains(role)) {
        throw 'Invalid role: must be patient, chw, or admin';
      }
      
      print('Registering user: $email, role: $role');
      
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': role,
        },
      );
      
      if (response.user == null) {
        throw 'Registration failed';
      }
      
      print('User registered: ${response.user!.id}');
      
      // Insert into profiles table
      try {
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'email': email,
          'full_name': fullName,
          'phone': phone,
          'role': role,
          'created_at': DateTime.now().toIso8601String(),
        });
        print('✅ Profile record created');
      } catch (profileError) {
        print('⚠️ Profile insert error: $profileError');
      }
      
      return {'success': true, 'user': response.user};
    } catch (e) {
      print('Registration error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔍 Attempting login for: $email');
      
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.user == null) {
        throw 'Login failed';
      }
      
      print('✅ User logged in: ${response.user!.id}');

      // Get role from metadata (no database query)
      String role = response.user!.userMetadata?['role']?.toString() ?? 'patient';
      print('✅ Role from metadata: $role');
      
      return {'success': true, 'user': response.user, 'role': role};
    } on AuthApiException catch (e) {
      print('❌ Auth API Error: ${e.message}');
      return {'success': false, 'error': 'Invalid email or password'};
    } catch (e) {
      print('❌ Login error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> logout() async {
    print('Logging out');
    await _supabase.auth.signOut();
    print('Logout successful');
  }

  Future<Map<String, dynamic>> resetPassword({required String email}) async {
    try {
      print('Sending password reset for: $email');
      await _supabase.auth.resetPasswordForEmail(email);
      print('Password reset email sent');
      return {'success': true};
    } catch (e) {
      print('Password reset error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}