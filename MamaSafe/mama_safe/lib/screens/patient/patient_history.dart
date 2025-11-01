// lib/screens/patient/patient_history.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mama_safe/services/auth_service.dart';

class PatientHistory extends StatefulWidget {
  const PatientHistory({super.key});

  @override
  State<PatientHistory> createState() => _PatientHistoryState();
}

class _PatientHistoryState extends State<PatientHistory> {
  final AuthService _authService = AuthService();
  final String _apiBaseUrl = 'https://capstone-kubh.onrender.com';
  
  List<Map<String, dynamic>> _predictions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPredictions();
  }

  Future<void> _fetchPredictions() async {
    setState(() => _isLoading = true);
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/predictions/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _predictions = List<Map<String, dynamic>>.from(data['predictions'] ?? []);
        });
      }
    } catch (e) {
      print('Error fetching predictions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getRiskColor(String? riskLevel) {
    if (riskLevel == null) return Colors.grey;
    final risk = riskLevel.toLowerCase();
    if (risk.contains('high')) return Colors.red;
    if (risk.contains('medium') || risk.contains('moderate')) return Colors.orange;
    if (risk.contains('low')) return Colors.green;
    return Colors.grey;
  }

  String _getRiskEmoji(String? riskLevel) {
    if (riskLevel == null) return '❓';
    final risk = riskLevel.toLowerCase();
    if (risk.contains('high')) return '🔴';
    if (risk.contains('medium')) return '🟡';
    if (risk.contains('low')) return '🟢';
    return '❓';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Assessment History', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.pink[400],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPredictions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchPredictions,
              child: _predictions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _predictions.length,
                      itemBuilder: (context, index) {
                        return _buildPredictionCard(_predictions[index]);
                      },
                    ),
            ),
      floatingActionButton: _predictions.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                _showExportDialog(context);
              },
              icon: const Icon(Icons.download),
              label: const Text("Export"),
              backgroundColor: Colors.pink[400],
            )
          : null,
    );
  }

  Widget _buildPredictionCard(Map<String, dynamic> prediction) {
    final riskLevel = prediction['risk_level'] ?? 'Unknown';
    final riskPercentage = prediction['risk_percentage']?.toString() ?? '0';
    final confidence = prediction['confidence']?.toString() ?? '0';
    final createdAt = prediction['created_at']?.toString() ?? '';
    final factors = prediction['factors'];
    final recommendations = prediction['recommendations'];

    final riskColor = _getRiskColor(riskLevel);
    final riskEmoji = _getRiskEmoji(riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          childrenPadding: const EdgeInsets.all(20),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(riskEmoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                riskLevel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: riskColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Risk: $riskPercentage% • Confidence: $confidence%',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Risk Factors
                  if (factors != null && factors.toString().isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Risk Factors',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Text(
                        factors.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Recommendations
                  if (recommendations != null && recommendations.toString().isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Recommendations',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        recommendations.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.pink[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                size: 80,
                color: Colors.pink[300],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Assessment History',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your GDM risk assessments will appear here once you complete your first prediction.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Go back to dashboard
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create Assessment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[400],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.pink[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.download, color: Colors.pink[400], size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Export History', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Export your assessment history as:',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red[400]),
              title: const Text('PDF Document'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF export coming soon!')),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.table_chart, color: Colors.green[400]),
              title: const Text('Excel Spreadsheet'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Excel export coming soon!')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays == 0) {
        return 'Today';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString.substring(0, 10);
    }
  }
}