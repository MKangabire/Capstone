// lib/screens/patient/prediction_input_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:mama_safe/services/auth_service.dart';

class PredictionInputScreen extends StatefulWidget {
  const PredictionInputScreen({super.key});

  @override
  State<PredictionInputScreen> createState() => _PredictionInputScreenState();
}

class _PredictionInputScreenState extends State<PredictionInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _bloodGlucoseController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingProfile = true;
  Map<String, dynamic>? _predictionResult;
  String? _errorMessage;
  final String _apiUrl = 'https://capstone-kubh.onrender.com/api/predict';
  String _loadingMessage = 'Processing...';

  final AuthService _authService = AuthService();
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    HttpOverrides.global = MyHttpOverrides();
    _loadPatientData();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _bloodGlucoseController.dispose();
    super.dispose();
  }

  // ✅ NEW: Load patient data and auto-fill form
  Future<void> _loadPatientData() async {
    setState(() => _isLoadingProfile = true);
    
    try {
      // Get profile from Supabase
      _profile = await _authService.getProfile();
      print('📋 Loaded profile: $_profile');

      // Auto-fill age if available
      if (_profile['age'] != null) {
        _ageController.text = _profile['age'].toString();
        print('✅ Auto-filled age: ${_profile['age']}');
      }

      // Try to get latest health data from API
      final userId = _authService.currentUser?.id;
      if (userId != null) {
        try {
          final response = await http.get(
            Uri.parse('https://capstone-kubh.onrender.com/api/patients/$userId'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final apiProfile = data['patient'] ?? {};
            
            // Merge with existing profile
            _profile = {..._profile, ...apiProfile};
            
            // Auto-fill age from API if not already filled
            if (_ageController.text.isEmpty && apiProfile['age'] != null) {
              _ageController.text = apiProfile['age'].toString();
            }
            
            print('✅ Merged with API data');
          }
        } catch (e) {
          print('⚠️ Could not fetch API data: $e');
        }

        // Try to get latest prediction data for blood pressure and glucose
        try {
          final predResponse = await http.get(
            Uri.parse('https://capstone-kubh.onrender.com/api/predictions/$userId'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 5));

          if (predResponse.statusCode == 200) {
            final data = json.decode(predResponse.body);
            final predictions = data['predictions'] ?? [];
            
            if (predictions.isNotEmpty) {
              final latest = predictions[0];
              
              // Auto-fill from latest prediction
              if (latest['blood_pressure_systolic'] != null) {
                _bpSystolicController.text = latest['blood_pressure_systolic'].toString();
                print('✅ Auto-filled BP Systolic: ${latest['blood_pressure_systolic']}');
              }
              
              if (latest['blood_pressure_diastolic'] != null) {
                _bpDiastolicController.text = latest['blood_pressure_diastolic'].toString();
                print('✅ Auto-filled BP Diastolic: ${latest['blood_pressure_diastolic']}');
              }
              
              if (latest['blood_glucose'] != null) {
                _bloodGlucoseController.text = latest['blood_glucose'].toString();
                print('✅ Auto-filled Blood Glucose: ${latest['blood_glucose']}');
              }
            }
          }
        } catch (e) {
          print('⚠️ Could not fetch prediction history: $e');
        }
      }

      if (mounted) {
        setState(() => _isLoadingProfile = false);
        
        // Show info if data was auto-filled
        if (_ageController.text.isNotEmpty || 
            _bpSystolicController.text.isNotEmpty || 
            _bpDiastolicController.text.isNotEmpty || 
            _bloodGlucoseController.text.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📋 Form pre-filled with your latest data'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading patient data: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _submitPrediction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _predictionResult = null;
      _errorMessage = null;
      _loadingMessage = 'Connecting to server...';
    });

    try {
      final age = double.parse(_ageController.text);
      final bpSystolic = double.parse(_bpSystolicController.text);
      final bpDiastolic = double.parse(_bpDiastolicController.text);
      final bloodGlucose = double.parse(_bloodGlucoseController.text);

      final userId = _authService.currentUser?.id;
      if (userId == null) {
        throw Exception('Please login to continue');
      }

      final requestBody = {
        "age": age,
        "blood_pressure_systolic": bpSystolic,
        "blood_pressure_diastolic": bpDiastolic,
        "blood_glucose": bloodGlucose,
        "patient_id": userId,
      };

      print('📤 Sending request to: $_apiUrl');
      print('📤 Patient ID: $userId');
      print('📤 Request body: $requestBody');
      print('📤 Request timestamp: ${DateTime.now()}');

      setState(() {
        _loadingMessage = 'Analyzing your health data...\n(First request may take up to 2 minutes)';
      });

      final startTime = DateTime.now();
      
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw TimeoutException('Server took too long to respond. The server might be starting up. Please try again.');
        },
      );

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('⏱️ Request completed in: ${duration.inSeconds} seconds');
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Parsed response data: $data');
        
        setState(() {
          _predictionResult = {
            'message': data['message'] ?? 'Prediction completed',
            'risk_level': data['risk_level'] ?? 'Unknown',
            'risk_percentage': data['risk_percentage'] ?? 0,
            'confidence': data['confidence'] ?? 0,
            'recommendations': data['recommendations'] ?? '',
            'risk_factors': data['risk_factors'] ?? '',
          };
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Assessment completed successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException catch (e) {
      print('⏱️ Timeout error: $e');
      setState(() {
        _errorMessage = e.message ?? 'Request timed out';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏱️ Timeout: ${e.message}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on SocketException catch (e) {
      print('📡 Network error: $e');
      setState(() {
        _errorMessage = 'Network error. Please check your internet connection.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📡 No internet connection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error during prediction: $e');
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    String? helperText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          helperMaxLines: 2,
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.pink[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.pink[400], size: 20),
          ),
          // Show icon when field is pre-filled
          suffixIcon: controller.text.isNotEmpty 
            ? Icon(Icons.check_circle, color: Colors.green[400], size: 20)
            : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: controller.text.isNotEmpty ? Colors.green[200]! : Colors.grey[300]!,
              width: controller.text.isNotEmpty ? 2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: controller.text.isNotEmpty ? Colors.green[50] : Colors.grey[50],
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('GDM Risk Assessment', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.pink[400],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Refresh button to reload data
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload latest data',
            onPressed: _loadPatientData,
          ),
        ],
      ),
      body: _isLoadingProfile
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.pink[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your data...',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[50]!, Colors.blue[100]!],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Review and update your data',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pre-filled fields can be edited before submitting',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // Input Fields
                    _buildInputField(
                      controller: _ageController,
                      label: 'Age',
                      hint: 'Enter your age',
                      icon: Icons.cake,
                      helperText: 'Your current age in years (18-50)',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter age';
                        final num = double.tryParse(value);
                        if (num == null || num < 18 || num > 50) {
                          return 'Age must be between 18-50 years';
                        }
                        return null;
                      },
                    ),
                    
                    _buildInputField(
                      controller: _bpSystolicController,
                      label: 'Systolic Blood Pressure',
                      hint: 'e.g., 120',
                      icon: Icons.favorite,
                      helperText: 'Normal range: 90-120 mmHg (allowed: 80-200)',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter systolic BP';
                        final num = double.tryParse(value);
                        if (num == null || num < 80 || num > 200) {
                          return 'Systolic BP must be between 80-200 mmHg';
                        }
                        return null;
                      },
                    ),
                    
                    _buildInputField(
                      controller: _bpDiastolicController,
                      label: 'Diastolic Blood Pressure',
                      hint: 'e.g., 80',
                      icon: Icons.monitor_heart,
                      helperText: 'Normal range: 60-80 mmHg (allowed: 40-130)',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter diastolic BP';
                        final num = double.tryParse(value);
                        if (num == null || num < 40 || num > 130) {
                          return 'Diastolic BP must be between 40-130 mmHg';
                        }
                        return null;
                      },
                    ),
                    
                    _buildInputField(
                      controller: _bloodGlucoseController,
                      label: 'Blood Glucose Level',
                      hint: 'e.g., 100',
                      icon: Icons.water_drop,
                      helperText: 'Fasting normal: 70-100 mg/dL (allowed: 40-400)',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter blood glucose';
                        final num = double.tryParse(value);
                        if (num == null || num < 40 || num > 400) {
                          return 'Blood glucose must be between 40-400 mg/dL';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 8),

                    // Submit Button
                    if (_isLoading)
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 6,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.pink[400]!),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _loadingMessage,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                LinearProgressIndicator(
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.pink[400]!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.pink[400]!, Colors.pink[600]!],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pink.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _submitPrediction,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.analytics, color: Colors.white, size: 24),
                                  SizedBox(width: 12),
                                  Text(
                                    'Get Risk Assessment',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 24),

                    // Result Display
                    if (_predictionResult != null)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Result Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _predictionResult!['risk_level'].toString().toLowerCase().contains('high')
                                        ? Colors.red[50]
                                        : Colors.green[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _predictionResult!['risk_level'].toString().toLowerCase().contains('high')
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle,
                                    color: _predictionResult!['risk_level'].toString().toLowerCase().contains('high')
                                        ? Colors.red[700]
                                        : Colors.green[700],
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Assessment Result',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _predictionResult!['message'] ?? 'Prediction Complete',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _predictionResult!['risk_level'].toString().toLowerCase().contains('high')
                                              ? Colors.red[700]
                                              : Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            Divider(color: Colors.grey[200]),
                            const SizedBox(height: 20),

                            // Result Rows
                            _buildResultRow(
                              'Risk Level',
                              _predictionResult!['risk_level'].toString(),
                              Icons.assessment,
                              Colors.purple,
                            ),

                            _buildResultRow(
                              'Risk Percentage',
                              '${_predictionResult!['risk_percentage']}%',
                              Icons.trending_up,
                              Colors.orange,
                            ),

                            _buildResultRow(
                              'Confidence',
                              '${_predictionResult!['confidence']}%',
                              Icons.percent,
                              Colors.blue,
                            ),

                            // Risk Factors
                            if (_predictionResult!['risk_factors'] != null && _predictionResult!['risk_factors'].toString().isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Risk Factors',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _predictionResult!['risk_factors'].toString().replaceAll('\\n', '\n'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Recommendations
                            if (_predictionResult!['recommendations'] != null && _predictionResult!['recommendations'].toString().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.lightbulb, color: Colors.blue[700], size: 20),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Recommendations',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _predictionResult!['recommendations'].toString().replaceAll('\\n', '\n'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),
                            
                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _predictionResult = null;
                                        _errorMessage = null;
                                      });
                                      _loadPatientData(); // Reload data for new assessment
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('New Assessment'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(color: Colors.pink[400]!),
                                      foregroundColor: Colors.pink[400],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context, true);
                                    },
                                    icon: const Icon(Icons.arrow_back),
                                    label: const Text('Back to Dashboard'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      backgroundColor: Colors.pink[400],
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Error Display
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 28),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Error',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[900],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildResultRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// SSL Override
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        print('⚠️ Warning: Accepting certificate for $host:$port');
        return true;
      };
  }
}