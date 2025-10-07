// patient_dashboard.dart - UPDATED to pass data to prediction

import 'package:flutter/material.dart';
import 'patient_data_entry.dart';
import 'patient_history.dart';
import 'patient_prediction.dart';
import '/services/health_data_provider.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  
  @override
  void initState() {
    super.initState();
    // Listen to health data changes
    healthDataProvider.addListener(_onHealthDataChanged);
  }

  @override
  void dispose() {
    healthDataProvider.removeListener(_onHealthDataChanged);
    super.dispose();
  }

  void _onHealthDataChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasData = healthDataProvider.hasData;
    final healthData = healthDataProvider.healthData;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              // TODO: Implement profile
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.pink[400]!, Colors.pink[300]!],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome Back!",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Let's monitor your health today",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    if (hasData && healthData != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatItem("Glucose", "${healthData['bloodGlucose']?.toInt() ?? '-'}", Icons.bloodtype),
                          const SizedBox(width: 24),
                          _buildStatItem("BP", "${healthData['systolic']?.toInt() ?? '-'}/${healthData['diastolic']?.toInt() ?? '-'}", Icons.favorite),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),
              
              // Quick Actions Title
              const Text(
                "Quick Actions",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              
              // Action Cards Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildActionCard(
                    context,
                    title: "Enter Health Data",
                    icon: Icons.add_circle_outline,
                    color: Colors.blue[400]!,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PatientDataEntry(),
                        ),
                      );
                      
                      // Data is already saved in provider, just update UI
                      if (result != null) {
                        setState(() {});
                      }
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: "View History",
                    icon: Icons.history,
                    color: Colors.green[400]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PatientHistory(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: "Risk Prediction",
                    icon: Icons.analytics_outlined,
                    color: Colors.orange[400]!,
                    badge: !hasData ? "⚠️" : null,
                    onTap: () {
                      if (!hasData) {
                        // Show dialog to enter data first
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("No Health Data"),
                            content: const Text(
                              "Please enter your health data first before running prediction.\n\nRequired data:\n• Age\n• Blood Pressure\n• Blood Glucose",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PatientDataEntry(),
                                    ),
                                  );
                                  setState(() {});
                                },
                                child: const Text("Enter Data"),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // Navigate to prediction - it will read from provider
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PatientPrediction(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: "Health Tips",
                    icon: Icons.tips_and_updates_outlined,
                    color: Colors.purple[400]!,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Health tips coming soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 30),
              
              // Data Status Card
              if (!hasData)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Enter your health data to enable risk prediction",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Health data recorded. You can now run risk prediction!",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (healthData != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildDataChip("Age", "${healthData['age']} yrs", Icons.cake),
                            _buildDataChip("Glucose", "${healthData['bloodGlucose']?.toInt()} mg/dL", Icons.bloodtype),
                            _buildDataChip("BP", "${healthData['systolic']?.toInt()}/${healthData['diastolic']?.toInt()}", Icons.favorite),
                            if (healthData['bmi'] != null)
                              _buildDataChip("BMI", "${healthData['bmi']?.toStringAsFixed(1)}", Icons.monitor_weight),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.green[700]),
          const SizedBox(width: 6),
          Text(
            "$label: $value",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.green[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: color,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}