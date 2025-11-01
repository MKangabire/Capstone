// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://capstone-kubh.onrender.com';
  static const Duration timeoutDuration = Duration(seconds: 120);

  // Initialize SSL override
  static void initialize() {
    HttpOverrides.global = _MyHttpOverrides();
  }

  // ==================== PREDICTION ENDPOINTS ====================

  /// Make a GDM prediction and save to database
  static Future<Map<String, dynamic>> createPrediction({
    required String patientId,
    required double age,
    required double bloodPressureSystolic,
    required double bloodPressureDiastolic,
    required double bloodGlucose,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/predict'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'patient_id': patientId,
              'age': age,
              'blood_pressure_systolic': bloodPressureSystolic,
              'blood_pressure_diastolic': bloodPressureDiastolic,
              'blood_glucose': bloodGlucose,
            }),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create prediction: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating prediction: $e');
    }
  }

  /// Get all predictions for a patient
  static Future<List<Map<String, dynamic>>> getPatientPredictions(
    String patientId, {
    int limit = 10,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/predictions/$patientId?limit=$limit'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['predictions'] ?? []);
      } else {
        throw Exception('Failed to fetch predictions: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching predictions: $e');
    }
  }

  /// Get latest prediction for a patient
  static Future<Map<String, dynamic>?> getLatestPrediction(
      String patientId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/predictions/latest/$patientId'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['prediction'];
      } else if (response.statusCode == 404) {
        return null; // No predictions found
      } else {
        throw Exception('Failed to fetch latest prediction: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching latest prediction: $e');
    }
  }

  // ==================== PATIENT ENDPOINTS ====================

  /// Get patient details
  static Future<Map<String, dynamic>> getPatient(String patientId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/patients/$patientId'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['patient'];
      } else {
        throw Exception('Failed to fetch patient: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching patient: $e');
    }
  }

  /// Update patient profile
  static Future<Map<String, dynamic>> updatePatient(
    String patientId, {
    String? fullName,
    int? age,
    double? height,
    double? weight,
    String? phone,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (fullName != null) updateData['full_name'] = fullName;
      if (age != null) updateData['age'] = age;
      if (height != null) updateData['height'] = height;
      if (weight != null) updateData['weight'] = weight;
      if (phone != null) updateData['phone'] = phone;

      final response = await http
          .put(
            Uri.parse('$baseUrl/api/patients/$patientId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(updateData),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update patient: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating patient: $e');
    }
  }

  /// Get patient health data history
  static Future<List<Map<String, dynamic>>> getPatientHealthData(
      String patientId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/patients/$patientId/health-data'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['health_data'] ?? []);
      } else {
        throw Exception('Failed to fetch health data: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching health data: $e');
    }
  }

  // ==================== CHW ENDPOINTS ====================

  /// Get CHW details
  static Future<Map<String, dynamic>> getCHW(String chwId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/chw/$chwId'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['chw'];
      } else {
        throw Exception('Failed to fetch CHW: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching CHW: $e');
    }
  }

  /// Get all patients assigned to a CHW
  static Future<List<Map<String, dynamic>>> getCHWPatients(
      String chwId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/chw/patients/$chwId'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['patients'] ?? []);
      } else {
        throw Exception('Failed to fetch CHW patients: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching CHW patients: $e');
    }
  }

  /// Assign a patient to a CHW
  static Future<Map<String, dynamic>> assignPatientToCHW(
    String chwId,
    String patientId,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/chw/$chwId/assign-patient?patient_id=$patientId'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to assign patient: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error assigning patient: $e');
    }
  }

  // ==================== NOTIFICATION ENDPOINTS ====================

  /// Send notification to CHW
  static Future<Map<String, dynamic>> sendNotification({
    required String chwId,
    required String patientId,
    required String title,
    required String message,
    String notificationType = 'general',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/notifications/send'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'chw_id': chwId,
              'patient_id': patientId,
              'title': title,
              'message': message,
              'notification_type': notificationType,
            }),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending notification: $e');
    }
  }

  /// Get all notifications for a CHW
  static Future<List<Map<String, dynamic>>> getCHWNotifications(
    String chwId, {
    bool unreadOnly = false,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/notifications/$chwId?unread_only=$unreadOnly'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
      } else {
        throw Exception('Failed to fetch notifications: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  /// Mark notification as read
  static Future<Map<String, dynamic>> markNotificationRead(
      String notificationId) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/notifications/$notificationId/mark-read'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to mark notification as read: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error marking notification as read: $e');
    }
  }

  // ==================== HEALTH CHECK ====================

  /// Check API health status
  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/health'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Health check failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error checking health: $e');
    }
  }
}

// SSL Certificate override for development
class _MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return true;
      };
  }
}