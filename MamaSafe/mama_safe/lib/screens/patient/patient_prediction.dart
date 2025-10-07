import 'package:flutter/material.dart';
import '/services/prediction_service.dart';
import '/services/health_data_provider.dart';

class PatientPrediction extends StatefulWidget {
  const PatientPrediction({super.key});

  @override
  State<PatientPrediction> createState() => _PatientPredictionState();
}

class _PatientPredictionState extends State<PatientPrediction> {
  bool _isLoading = false;
  bool _hasResult = false;
  bool _isBackendConnected = false;
  Map<String, dynamic>? _predictionResult;
  String? _errorMessage;

  final _predictionService = PredictionService();

  @override
  void initState() {
    super.initState();
    _checkBackendConnection();
  }

  Future<void> _checkBackendConnection() async {
    final isConnected = await _predictionService.checkBackendHealth();
    setState(() {
      _isBackendConnected = isConnected;
    });

    if (!isConnected) {
      _showBackendErrorDialog();
    }
  }

  void _showBackendErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 12),
            Text("Backend Not Connected"),
          ],
        ),
        content: const Text(
          "Cannot connect to the prediction server.\n\n"
          "Please make sure:\n"
          "1. FastAPI backend is running\n"
          "2. You're on the same network\n"
          "3. IP address is correct in code\n\n"
          "Run: python main.py",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkBackendConnection();
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Future<void> _runPrediction() async {
    // Get data from provider
    final age = healthDataProvider.age;
    final systolic = healthDataProvider.bloodPressureSystolic;
    final diastolic = healthDataProvider.bloodPressureDiastolic;
    final glucose = healthDataProvider.bloodGlucose;

    // Check if we have required data
    if (age == null || systolic == null || diastolic == null || glucose == null) {
      _showDataRequiredDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _hasResult = false;
      _errorMessage = null;
    });

    try {
      // Call the API with 4 features from provider
      final result = await _predictionService.predictGDMRisk(
        age: age,
        bloodPressureSystolic: systolic,
        bloodPressureDiastolic: diastolic,
        bloodGlucose: glucose,
      );

      setState(() {
        _predictionResult = result;
        _isLoading = false;
        _hasResult = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      _showErrorDialog(e.toString());
    }
  }

  void _showDataRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Data Required"),
        content: const Text(
          "Please enter your health data first:\n\n"
          "Required:\n"
          "• Age\n"
          "• Blood Pressure (Systolic/Diastolic)\n"
          "• Blood Glucose Level\n\n"
          "Go to 'Enter Health Data' to add your information.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to dashboard
            },
            child: const Text("Enter Data"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 12),
            Text("Prediction Error"),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(error),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkBackendConnection();
            },
            child: const Text("Check Connection"),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getImpactIcon(String impact) {
    switch (impact.toLowerCase()) {
      case 'positive':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning;
      case 'negative':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  Color _getImpactColor(String impact) {
    switch (impact.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'negative':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'bloodtype':
        return Icons.bloodtype;
      case 'favorite':
        return Icons.favorite;
      case 'cake':
        return Icons.cake;
      case 'monitor_weight':
        return Icons.monitor_weight;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GDM Risk Prediction"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isBackendConnected
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isBackendConnected ? Icons.cloud_done : Icons.cloud_off,
                      size: 16,
                      color: _isBackendConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isBackendConnected ? "Connected" : "Offline",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isBackendConnected ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _hasResult && _predictionResult != null
                ? _buildResultState()
                : _buildInitialState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.pink[400]!),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "Analyzing Your Data...",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Our AI model is processing your health metrics",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.pink[400]!),
              backgroundColor: Colors.pink[100],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Image
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink[300]!, Colors.pink[100]!],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  "AI-Powered Risk Assessment",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Connection Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isBackendConnected ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _isBackendConnected ? Colors.green[200]! : Colors.orange[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isBackendConnected ? Icons.check_circle : Icons.info_outline,
                  color: _isBackendConnected ? Colors.green[700] : Colors.orange[700],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isBackendConnected ? "Backend Connected" : "Backend Offline",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isBackendConnected ? Colors.green[900] : Colors.orange[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isBackendConnected
                            ? "Ready to make predictions"
                            : "Please start the FastAPI server",
                        style: TextStyle(
                          fontSize: 13,
                          color: _isBackendConnected ? Colors.green[800] : Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isBackendConnected)
                  TextButton(
                    onPressed: _checkBackendConnection,
                    child: const Text("Retry"),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    const Text(
                      "How it works",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Our machine learning model analyzes your health data including blood pressure and glucose levels to predict your risk of developing Gestational Diabetes Mellitus (GDM).",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Current Data Display
          const Text(
            "Your Current Data",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          if (healthDataProvider.hasData) ...[
            _buildDataItem(
              "Blood Pressure",
              "${healthDataProvider.bloodPressureSystolic?.toInt() ?? '-'}/${healthDataProvider.bloodPressureDiastolic?.toInt() ?? '-'} mmHg",
              Icons.favorite,
              Colors.pink,
            ),
            _buildDataItem(
              "Blood Glucose",
              "${healthDataProvider.bloodGlucose?.toInt() ?? '-'} mg/dL",
              Icons.bloodtype,
              Colors.red,
            ),
            _buildDataItem(
              "Age",
              "${healthDataProvider.age ?? '-'} years",
              Icons.cake,
              Colors.blue,
            ),
            if (healthDataProvider.bmi != null)
              _buildDataItem(
                "BMI",
                healthDataProvider.bmi!.toStringAsFixed(1),
                Icons.monitor_weight,
                Colors.purple,
              ),
            if (healthDataProvider.pregnancyWeek != null)
              _buildDataItem(
                "Pregnancy Week",
                "Week ${healthDataProvider.pregnancyWeek}",
                Icons.child_care,
                Colors.green,
              ),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber[800]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "No health data available. Please enter your data first.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 30),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, color: Colors.amber[800]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "This prediction is for informational purposes only. Always consult with your healthcare provider for medical decisions.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Run Button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isBackendConnected && healthDataProvider.hasData 
                  ? _runPrediction 
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[400],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isBackendConnected 
                        ? (healthDataProvider.hasData ? Icons.play_arrow : Icons.warning)
                        : Icons.cloud_off, 
                    size: 28
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isBackendConnected
                        ? (healthDataProvider.hasData 
                            ? "Run Risk Assessment" 
                            : "No Data Available")
                        : "Backend Offline",
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultState() {
    if (_predictionResult == null) return Container();

    final riskLevel = _predictionResult!['risk_level'] as String;
    final riskPercentage = (_predictionResult!['risk_percentage'] as num).toDouble();
    final confidence = (_predictionResult!['confidence'] as num).toDouble();
    final factors = _predictionResult!['factors'] as List;
    final recommendations = _predictionResult!['recommendations'] as List;
    final riskColor = _getRiskColor(riskLevel);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Risk Score Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [riskColor, riskColor.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: riskColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "Your GDM Risk Level",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "${riskPercentage.toInt()}%",
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    riskLevel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Model Confidence: ${confidence.toInt()}%",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Contributing Factors
          const Text(
            "Contributing Factors",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          ...factors.map((factor) {
            return _buildFactorCard(
              factor['name'],
              factor['value'],
              factor['impact'],
              _getIconData(factor['icon']),
            );
          }),

          const SizedBox(height: 30),

          // Recommendations
          const Text(
            "Recommendations",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: recommendations.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.pink[100],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            "${entry.key + 1}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.pink[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 30),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasResult = false;
                      _predictionResult = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("Run Again"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.pink[400]!, width: 2),
                    foregroundColor: Colors.pink[400],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.dashboard),
                  label: const Text("Dashboard"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataItem(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
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
                const SizedBox(height: 4),
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

  Widget _buildFactorCard(String name, String value, String impact, IconData icon) {
    final impactColor = _getImpactColor(impact);
    final impactIcon = _getImpactIcon(impact);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: impactColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: impactColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(impactIcon, color: impactColor, size: 24),
        ],
      ),
    );
  }
}