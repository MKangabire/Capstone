import 'dart:convert';
import 'package:http/http.dart' as http;

class PredictionService {
  // IMPORTANT: Change this to your computer's IP address
  // To find your IP:
  // - Windows: Run 'ipconfig' in cmd, look for IPv4 Address
  // - Mac/Linux: Run 'ifconfig' or 'ip addr', look for inet
  // - Or use 'localhost' if testing on web browser
  
  static const String baseUrl = 'http://192.168.1.100:8000'; // Change this IP!
  // For Android emulator, use: http://10.0.2.2:8000
  // For iOS simulator, use: http://localhost:8000
  // For real device, use: http://YOUR_COMPUTER_IP:8000

  /// Make GDM risk prediction
  Future<Map<String, dynamic>> predictGDMRisk({
    required int age,
    required double bloodPressureSystolic,
    required double bloodPressureDiastolic,
    required double bloodGlucose,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/predict'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'age': age,
          'blood_pressure_systolic': bloodPressureSystolic,
          'blood_pressure_diastolic': bloodPressureDiastolic,
          'blood_glucose': bloodGlucose,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout. Please check if the backend server is running.');
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Invalid input data');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused')) {
        throw Exception(
          'Cannot connect to server. Please:\n'
          '1. Make sure backend is running (python main.py)\n'
          '2. Check the IP address in prediction_service.dart\n'
          '3. Make sure you\'re on the same network'
        );
      }
      rethrow;
    }
  }

  /// Check if backend is reachable
  Future<bool> checkBackendHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get backend status
  Future<Map<String, dynamic>> getBackendStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Backend not responding');
      }
    } catch (e) {
      throw Exception('Cannot connect to backend: ${e.toString()}');
    }
  }
}