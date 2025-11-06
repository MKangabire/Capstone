import 'package:flutter/material.dart';
import 'package:mama_safe/services/supabase_service.dart';

class CHWReports extends StatefulWidget {
  const CHWReports({super.key});

  @override
  State<CHWReports> createState() => _CHWReportsState();
}

class _CHWReportsState extends State<CHWReports> {
  final _supabase = SupabaseService.client;
  String _selectedPeriod = 'This Month';
  final List<String> _periods = ['This Week', 'This Month', 'Last 3 Months', 'Custom'];
  
  bool _isLoading = true;
  
  // Real data from Supabase
  int totalPatients = 0;
  int highRiskPatients = 0;
  int mediumRiskPatients = 0;
  int lowRiskPatients = 0;
  int visitsCompleted = 0;
  int visitsPending = 0;
  double complianceRate = 0;
  List<Map<String, dynamic>> recentActivities = [];

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      final chwId = _supabase.auth.currentUser?.id;
      if (chwId == null) throw 'No user logged in';

      // Get total patients
      final patientsResponse = await _supabase
          .from('profiles')
          .select('id, full_name, created_at')
          .eq('chw_id', chwId)
          .eq('role', 'patient');
      
      totalPatients = patientsResponse.length;

      // Get patient IDs
      final patientIds = patientsResponse.map((p) => p['id'] as String).toList();

      if (patientIds.isNotEmpty) {
        // Get all predictions for risk distribution
        final predictionsResponse = await _supabase
            .from('predictions')
            .select('patient_id, risk_level, created_at')
            .inFilter('patient_id', patientIds)
            .order('created_at', ascending: false);
        
        // Get latest prediction per patient
        final Map<String, String> latestPredictions = {};
        for (var pred in predictionsResponse) {
          final patientId = pred['patient_id'];
          if (!latestPredictions.containsKey(patientId)) {
            latestPredictions[patientId] = 
                pred['risk_level']?.toString().toLowerCase() ?? 'low';
          }
        }
        
        // Count risk levels
        highRiskPatients = latestPredictions.values
            .where((risk) => risk.contains('high'))
            .length;
        
        lowRiskPatients = latestPredictions.values
            .where((risk) => risk.contains('low'))
            .length;
        
        mediumRiskPatients = totalPatients - highRiskPatients - lowRiskPatients;
      }

      // Get visits data (if appointments table exists)
      try {
        final visitsResponse = await _supabase
            .from('appointments')
            .select('id, status, scheduled_date')
            .eq('chw_id', chwId);
        
        visitsCompleted = visitsResponse
            .where((v) => v['status'] == 'completed')
            .length;
        
        visitsPending = visitsResponse
            .where((v) => v['status'] == 'pending')
            .length;
        
        // Calculate compliance rate
        final totalVisits = visitsCompleted + visitsPending;
        if (totalVisits > 0) {
          complianceRate = (visitsCompleted / totalVisits * 100);
        }
      } catch (e) {
        print('ℹ️ Appointments table not available: $e');
        visitsCompleted = 0;
        visitsPending = 0;
        complianceRate = 0;
      }

      // Get recent activities from notifications
      try {
        final activitiesResponse = await _supabase
            .from('notifications')
            .select('''
              id,
              title,
              message,
              created_at,
              type,
              profiles!notifications_patient_id_fkey(full_name)
            ''')
            .eq('chw_id', chwId)
            .order('created_at', ascending: false)
            .limit(5);
        
        recentActivities = activitiesResponse.map<Map<String, dynamic>>((n) {
          String patientName = 'Unknown Patient';
          if (n['profiles'] != null && n['profiles']['full_name'] != null) {
            patientName = n['profiles']['full_name'];
          }
          
          return {
            'title': n['title'] ?? 'Activity',
            'subtitle': '${patientName} - ${n['message']}',
            'time': _formatTimestamp(n['created_at']),
            'type': n['type'] ?? 'info',
          };
        }).toList();
      } catch (e) {
        print('ℹ️ Could not fetch activities: $e');
        recentActivities = [];
      }

      setState(() {});
    } catch (e) {
      print('❌ Error fetching report data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return "Recently";
    try {
      final now = DateTime.now();
      final dateTime = DateTime.parse(timestamp);
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return "Just now";
      if (difference.inMinutes < 60) return "${difference.inMinutes} min ago";
      if (difference.inHours < 24) return "${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago";
      if (difference.inDays < 7) return "${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago";
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    } catch (e) {
      return "Recently";
    }
  }

  IconData _getActivityIcon(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('high') || lowerType.contains('urgent') || lowerType.contains('risk')) {
      return Icons.warning;
    } else if (lowerType.contains('visit') || lowerType.contains('appointment')) {
      return Icons.calendar_today;
    } else if (lowerType.contains('completed') || lowerType.contains('success')) {
      return Icons.check_circle;
    }
    return Icons.notifications;
  }

  Color _getActivityColor(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('high') || lowerType.contains('urgent') || lowerType.contains('risk')) {
      return Colors.red;
    } else if (lowerType.contains('visit') || lowerType.contains('appointment')) {
      return Colors.blue;
    } else if (lowerType.contains('completed') || lowerType.contains('success')) {
      return Colors.green;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports & Analytics"),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReportData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchReportData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: _periods.map((period) {
                          final isSelected = _selectedPeriod == period;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedPeriod = period);
                                if (period == 'Custom') {
                                  _showDateRangePicker();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  period,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.blue[700] : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Summary Cards
                    const Text(
                      "Overview",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildSummaryCard(
                          "Total Patients",
                          totalPatients.toString(),
                          Icons.people,
                          Colors.blue,
                          "Under your care",
                        ),
                        _buildSummaryCard(
                          "High Risk",
                          highRiskPatients.toString(),
                          Icons.warning,
                          Colors.red,
                          highRiskPatients > 0 ? "Needs attention" : "All good",
                        ),
                        _buildSummaryCard(
                          "Visits Done",
                          visitsCompleted.toString(),
                          Icons.check_circle,
                          Colors.green,
                          "Out of ${visitsCompleted + visitsPending}",
                        ),
                        _buildSummaryCard(
                          "Compliance",
                          "${complianceRate.toStringAsFixed(0)}%",
                          Icons.trending_up,
                          Colors.purple,
                          "Visit completion rate",
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Performance Metrics
                    if (visitsCompleted > 0 || visitsPending > 0) ...[
                      const Text(
                        "Performance Metrics",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      _buildMetricBar(
                        "Visit Completion Rate",
                        visitsCompleted,
                        visitsCompleted + visitsPending,
                        Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildMetricBar(
                        "Patient Compliance",
                        complianceRate.round(),
                        100,
                        Colors.blue,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Risk Distribution
                    const Text(
                      "Risk Distribution",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: totalPatients > 0
                          ? Column(
                              children: [
                                _buildRiskRow("High Risk", highRiskPatients, totalPatients, Colors.red),
                                const SizedBox(height: 16),
                                _buildRiskRow("Medium Risk", mediumRiskPatients, totalPatients, Colors.orange),
                                const SizedBox(height: 16),
                                _buildRiskRow("Low Risk", lowRiskPatients, totalPatients, Colors.green),
                              ],
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(
                                  'No patient data available',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Recent Activities
                    const Text(
                      "Recent Activities",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    if (recentActivities.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No recent activities',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...recentActivities.map((activity) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildActivityItem(
                            activity['title'],
                            activity['subtitle'],
                            activity['time'],
                            _getActivityIcon(activity['type']),
                            _getActivityColor(activity['type']),
                          ),
                        );
                      }).toList(),
                    
                    const SizedBox(height: 24),

                    // Generate Full Report Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _generateFullReport,
                        icon: const Icon(Icons.description),
                        label: const Text("Generate Full Report"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBar(String title, int current, int total, Color color) {
    final percentage = total > 0 ? (current / total * 100).round() : 0;
    
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(
                "$current/$total ($percentage%)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: total > 0 ? current / total : 0,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskRow(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100).round() : 0;
    
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: total > 0 ? count / total : 0,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          "$count ($percentage%)",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    String time,
    IconData icon,
    Color color,
  ) {
    return Container(
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
          Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue[700]!),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      // TODO: Filter data by date range
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Date range: ${picked.start} to ${picked.end}')),
      );
    }
  }

  void _exportReport() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text("Export as PDF"),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF export coming soon')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text("Export as Excel"),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Excel export coming soon')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.email, color: Colors.blue),
                title: const Text("Email Report"),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email feature coming soon')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _generateFullReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Generate Full Report"),
        content: Text(
          "Report Summary:\n\n"
          "Total Patients: $totalPatients\n"
          "High Risk: $highRiskPatients\n"
          "Visits Completed: $visitsCompleted\n"
          "Compliance Rate: ${complianceRate.toStringAsFixed(1)}%\n\n"
          "This will generate a comprehensive PDF report.",
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
                const SnackBar(content: Text('Report generation coming soon')),
              );
            },
            child: const Text("Generate"),
          ),
        ],
      ),
    );
  }
}