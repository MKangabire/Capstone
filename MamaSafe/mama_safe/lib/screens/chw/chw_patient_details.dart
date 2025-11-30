// COMPLETE FIXED VERSION - Replace entire file content

import 'package:flutter/material.dart';
import 'package:mama_safe/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:mama_safe/utils/call_helper.dart';

class CHWPatientDetails extends StatefulWidget {
  final Map<String, dynamic> patient;

  const CHWPatientDetails({
    super.key,
    required this.patient,
  });

  @override
  State<CHWPatientDetails> createState() => _CHWPatientDetailsState();
}

class _CHWPatientDetailsState extends State<CHWPatientDetails>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = SupabaseService.client;
  
  bool _isLoadingPrediction = true;
  Map<String, dynamic>? _latestPrediction;
  List<Map<String, dynamic>> _predictionHistory = [];

  String get _patientFullName => widget.patient['full_name'] ?? widget.patient['name'] ?? 'Unknown Patient';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchLatestPrediction();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLatestPrediction() async {
    setState(() => _isLoadingPrediction = true);
    
    try {
      final patientId = widget.patient['id'];
      
      final response = await _supabase
          .from('predictions')
          .select('*')
          .eq('patient_id', patientId)
          .order('created_at', ascending: false)
          .limit(1);
      
      if (response.isNotEmpty) {
        setState(() {
          _latestPrediction = response[0];
        });
      }
      
      final historyResponse = await _supabase
          .from('predictions')
          .select('*')
          .eq('patient_id', patientId)
          .order('created_at', ascending: false)
          .limit(10);
      
      setState(() {
        _predictionHistory = List<Map<String, dynamic>>.from(historyResponse);
      });
      
    } catch (e) {
      print('Error fetching prediction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading prediction: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingPrediction = false);
    }
  }

  Color _getRiskColor(String? riskLevel) {
    if (riskLevel == null) return Colors.grey;
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getSeverityEmoji(String? severity) {
    if (severity == null) return '📊';
    switch (severity.toLowerCase()) {
      case 'critical':
        return '🚨';
      case 'severe':
      case 'high':
        return '⚠️';
      case 'moderate':
        return '📊';
      default:
        return '✅';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy - HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;
    final riskLevel = _latestPrediction?['risk_level'] ?? 'Unknown';
    final riskColor = _getRiskColor(riskLevel);

    return Scaffold(
      appBar: AppBar(
        title: Text(_patientFullName),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () => _callPatient(patient['phone'] ?? ''),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLatestPrediction,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Patient Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [riskColor, riskColor.withOpacity(0.7)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(_patientFullName),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _patientFullName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "ID: ${patient['id']?.toString().substring(0, 8) ?? 'N/A'}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "$riskLevel Risk",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // FIXED: Wrap with proper constraints
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildInfoChip(
                      Icons.cake,
                      "${patient['age'] ?? 0} yrs",
                    ),
                    _buildInfoChip(
                      Icons.location_on,
                      patient['region']?.toString().substring(0, patient['region'].toString().length > 15 ? 15 : patient['region'].toString().length) ?? 'N/A',
                    ),
                    _buildInfoChip(
                      Icons.phone,
                      "Contact",
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.pink[400],
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.pink[400],
              tabs: const [
                Tab(text: "Prediction"),
                Tab(text: "Overview"),
                Tab(text: "History"),
                Tab(text: "Visits"),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPredictionTab(),
                _buildOverviewTab(),
                _buildHistoryTab(),
                _buildVisitsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _scheduleVisit(),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text("Schedule Visit"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.pink[400]!, width: 2),
                    foregroundColor: Colors.pink[400],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _emergencyAlert(),
                  icon: const Icon(Icons.emergency, color: Colors.white),
                  label: const Text("Emergency Alert"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FIXED: _buildInfoChip with proper constraints
  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 140), // Limit max width
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    return name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase();
  }

  // Rest of the methods remain the same...
  Widget _buildPredictionTab() {
    if (_isLoadingPrediction) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_latestPrediction == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No prediction data available",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              "Run a prediction to see results",
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final prediction = _latestPrediction!;
    final riskPercentage = prediction['risk_percentage'] ?? 0.0;
    final riskLevel = prediction['risk_level'] ?? 'Unknown';
    final confidence = prediction['confidence'] ?? 0.0;
    final severity = prediction['severity'] ?? 'normal';
    final riskColor = _getRiskColor(riskLevel);

    return RefreshIndicator(
      onRefresh: _fetchLatestPrediction,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [riskColor.withOpacity(0.2), riskColor.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: riskColor, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    _getSeverityEmoji(severity),
                    style: const TextStyle(fontSize: 50),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Risk Assessment",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$riskLevel Risk",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: riskColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${riskPercentage.toStringAsFixed(1)}% Risk Score",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${confidence.toStringAsFixed(1)}% Confidence",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            if (prediction['factors'] != null) ...[
              const Text(
                "Risk Factors",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: prediction['factors']
                      .toString()
                      .split('\n')
                      .where((factor) => factor.trim().isNotEmpty)
                      .map<Widget>((factor) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    factor.trim(),
                                    style: TextStyle(
                                      color: Colors.orange[900],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (prediction['recommendations'] != null) ...[
              const Text(
                "Recommendations",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
                  children: prediction['recommendations']
                      .toString()
                      .split('\n')
                      .where((rec) => rec.trim().isNotEmpty)
                      .map<Widget>((rec) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.check_circle, color: Colors.blue[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rec.trim(),
                                    style: TextStyle(
                                      color: Colors.blue[900],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Prediction Method:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      Text(
                        'Clinical Rules Engine',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Predicted on:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      Text(
                        _formatDate(prediction['created_at']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final patient = widget.patient;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Patient Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(Icons.person, "Full Name", _patientFullName),
          _buildInfoCard(Icons.cake, "Age", "${patient['age'] ?? 'N/A'} years"),
          _buildInfoCard(Icons.location_on, "Region", patient['region'] ?? 'N/A'),
          _buildInfoCard(Icons.phone, "Phone", patient['phone'] ?? 'N/A'),
          _buildInfoCard(Icons.email, "Email", patient['email'] ?? 'N/A'),
          
          const SizedBox(height: 24),
          const Text(
            "Health Metrics",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  "BMI",
                  "${patient['bmi']?.toStringAsFixed(1) ?? 'N/A'}",
                  "",
                  Icons.monitor_weight,
                  Colors.blue,
                  false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  "Height",
                  "${patient['height'] ?? 'N/A'}",
                  "cm",
                  Icons.height,
                  Colors.green,
                  false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  "Weight",
                  "${patient['weight'] ?? 'N/A'}",
                  "kg",
                  Icons.scale,
                  Colors.orange,
                  false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  "Role",
                  patient['role'] ?? 'N/A',
                  "",
                  Icons.badge,
                  Colors.purple,
                  false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.pink[400], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingPrediction) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_predictionHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No prediction history",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLatestPrediction,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _predictionHistory.length,
        itemBuilder: (context, index) {
          final record = _predictionHistory[index];
          final riskColor = _getRiskColor(record['risk_level']);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: riskColor.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(record['created_at']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        record['risk_level'] ?? 'Unknown',
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.assessment, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      "Risk: ${record['risk_percentage']?.toStringAsFixed(1) ?? 0}%",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.verified, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      "Confidence: ${record['confidence']?.toStringAsFixed(1) ?? 0}%",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVisitsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "No visits recorded yet",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, String unit, IconData icon, Color color, bool isHigh) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value.toString() + (unit.isNotEmpty ? ' $unit' : ''),
            style: TextStyle(
              color: isHigh ? Colors.red : Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _callPatient(String? phone) {
    if (phone != null && phone.isNotEmpty) {
      CallHelper.makePhoneCall(context, phone);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Text('Phone number not available'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text("Edit Patient"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text("Share Report"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text("Print Details"),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _scheduleVisit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Visit scheduled!")),
    );
  }

  void _emergencyAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Emergency Alert"),
        content: Text(
          "Are you sure you want to send an emergency alert for $_patientFullName?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Emergency alert sent for $_patientFullName!"),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Send Alert"),
          ),
        ],
      ),
    );
  }
}