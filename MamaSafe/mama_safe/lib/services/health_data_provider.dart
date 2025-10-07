import 'package:flutter/material.dart';

/// Global health data storage
/// This stores the patient's latest health data across the app
class HealthDataProvider extends ChangeNotifier {
  Map<String, dynamic>? _healthData;

  Map<String, dynamic>? get healthData => _healthData;

  bool get hasData => _healthData != null;

  // Getters for easy access
  int? get age => _healthData?['age'];
  double? get bloodPressureSystolic => _healthData?['systolic'];
  double? get bloodPressureDiastolic => _healthData?['diastolic'];
  double? get bloodGlucose => _healthData?['bloodGlucose'];
  double? get weight => _healthData?['weight'];
  double? get bmi => _healthData?['bmi'];
  int? get pregnancyWeek => _healthData?['pregnancyWeek'];
  String? get mealTime => _healthData?['mealTime'];
  DateTime? get timestamp => _healthData?['timestamp'] != null 
      ? DateTime.parse(_healthData!['timestamp']) 
      : null;

  /// Save new health data
  void saveHealthData(Map<String, dynamic> data) {
    _healthData = {
      ...data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    notifyListeners();
    print('✅ Health data saved: $_healthData');
  }

  /// Update specific field
  void updateField(String key, dynamic value) {
    if (_healthData != null) {
      _healthData![key] = value;
      notifyListeners();
    }
  }

  /// Clear all data
  void clearData() {
    _healthData = null;
    notifyListeners();
  }

  /// Get formatted display string
  String getDisplayValue(String key) {
    if (_healthData == null || !_healthData!.containsKey(key)) {
      return '-';
    }
    return _healthData![key].toString();
  }
}

// Global instance for easy access
final healthDataProvider = HealthDataProvider();