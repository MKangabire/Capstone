// lib/screens/chw/chw_dashboard.dart - COMPLETE FILE

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mama_safe/services/supabase_service.dart';
import 'chw_patient_list.dart';
import 'chw_notifications.dart';
import 'chw_visit_scheduler.dart';
import 'chw_reports.dart';
import 'chw_profile.dart';

class CHWDashboard extends StatefulWidget {
  const CHWDashboard({super.key});

  @override
  State<CHWDashboard> createState() => _CHWDashboardState();
}

class _CHWDashboardState extends State<CHWDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const CHWDashboardHome(),
    const CHWPatientList(),
    const CHWNotifications(),
    const CHWProfile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue[700],
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 12,
          unselectedFontSize: 11,
          elevation: 0,
          backgroundColor: Colors.white,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Patients',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class CHWDashboardHome extends StatefulWidget {
  const CHWDashboardHome({super.key});

  @override
  State<CHWDashboardHome> createState() => _CHWDashboardHomeState();
}

class _CHWDashboardHomeState extends State<CHWDashboardHome> {
  final _supabase = SupabaseService.client;
  int totalPatients = 0;
  int highRiskPatients = 0;
  int pendingVisits = 0;
  int todayAppointments = 0;
  int newAlerts = 0;
  String chwName = 'CHW';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _setupRealtimeSubscriptions();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final chwId = _supabase.auth.currentUser?.id;
      if (chwId == null) throw 'No user logged in';

      final profile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', chwId)
          .single();
      
      setState(() {
        chwName = profile['full_name'] ?? 'CHW';
      });

      final patientsResponse = await _supabase
          .from('profiles')
          .select('id, full_name')
          .eq('chw_id', chwId)
          .eq('role', 'patient');
      
      totalPatients = patientsResponse.length;

      final patientIds = patientsResponse.map((p) => p['id'] as String).toList();

      if (patientIds.isNotEmpty) {
        final predictionsResponse = await _supabase
            .from('predictions')
            .select('patient_id, risk_level, created_at')
            .inFilter('patient_id', patientIds)
            .order('created_at', ascending: false);
        
        final Map<String, String> latestPredictions = {};
        for (var pred in predictionsResponse) {
          final patientId = pred['patient_id'];
          if (!latestPredictions.containsKey(patientId)) {
            latestPredictions[patientId] = pred['risk_level']?.toString().toLowerCase() ?? 'low';
          }
        }
        
        highRiskPatients = latestPredictions.values.where((risk) => risk.contains('high')).length;
      }

      try {
        final today = DateTime.now();
        final visitsResponse = await _supabase
            .from('appointments')
            .select('id')
            .eq('chw_id', chwId)
            .eq('status', 'pending')
            .gte('scheduled_date', today.toIso8601String());
        pendingVisits = visitsResponse.length;
      } catch (e) {
        pendingVisits = 0;
      }

      try {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        final todayVisits = await _supabase
            .from('appointments')
            .select('id')
            .eq('chw_id', chwId)
            .gte('scheduled_date', startOfDay.toIso8601String())
            .lt('scheduled_date', endOfDay.toIso8601String());
        todayAppointments = todayVisits.length;
      } catch (e) {
        todayAppointments = 0;
      }

      try {
        final alertsResponse = await _supabase
            .from('notifications')
            .select('id')
            .eq('chw_id', chwId)
            .eq('is_read', false);
        newAlerts = alertsResponse.length;
      } catch (e) {
        newAlerts = 0;
      }

      setState(() {});
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscriptions() {
    final chwId = _supabase.auth.currentUser?.id;
    if (chwId == null) return;

    SupabaseService.subscribeToTable('profiles', (payload) {
      if (payload.eventType == PostgresChangeEvent.insert ||
          payload.eventType == PostgresChangeEvent.update) {
        _fetchData();
      }
    });

    SupabaseService.subscribeToTable('predictions', (payload) {
      if (payload.eventType == PostgresChangeEvent.insert ||
          payload.eventType == PostgresChangeEvent.update) {
        _fetchData();
      }
    });

    SupabaseService.subscribeToTable('notifications', (payload) {
      if (payload.newRecord['chw_id'] == chwId) {
        _fetchData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchData,
          child: _isLoading && totalPatients == 0
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 180,
                      floating: false,
                      pinned: true,
                      backgroundColor: Colors.blue[700],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.blue[700]!, Colors.blue[500]!],
                            ),
                          ),
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            chwName.isNotEmpty ? chwName[0].toUpperCase() : 'C',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "Hello, $chwName! 👋",
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            const Text(
                                              "Community Health Worker",
                                              style: TextStyle(fontSize: 12, color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.calendar_today, color: Colors.white, size: 14),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            _formatDate(DateTime.now()),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      actions: [
                        IconButton(
                          icon: Stack(
                            children: [
                              const Icon(Icons.notifications_outlined, color: Colors.white),
                              if (newAlerts > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Text(
                                      '$newAlerts',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CHWNotifications()),
                            );
                          },
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    title: "Total Patients",
                                    value: totalPatients.toString(),
                                    icon: Icons.people,
                                    color: Colors.blue,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const CHWPatientList()),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    title: "High Risk",
                                    value: highRiskPatients.toString(),
                                    icon: Icons.warning_amber_rounded,
                                    color: Colors.red,
                                    urgent: highRiskPatients > 0,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const CHWPatientList(filterHighRisk: true),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    title: "Pending Visits",
                                    value: pendingVisits.toString(),
                                    icon: Icons.schedule,
                                    color: Colors.orange,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const CHWVisitScheduler()),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    title: "New Alerts",
                                    value: newAlerts.toString(),
                                    icon: Icons.notifications_active,
                                    color: Colors.purple,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const CHWNotifications()),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Quick Actions",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildQuickActionCard(
                              context,
                              title: "View Reports",
                              subtitle: "Generate and analyze patient reports",
                              icon: Icons.assessment,
                              color: Colors.indigo,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const CHWReports()),
                                );
                              },
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Recent Alerts",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const CHWNotifications()),
                                    );
                                  },
                                  child: const Text("View All"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: _fetchRecentAlerts(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                
                                if (snapshot.hasError) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.orange[700]),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text('Could not load alerts', style: TextStyle(color: Colors.orange[900])),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                final alerts = snapshot.data ?? [];
                                
                                if (alerts.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.notifications_none, size: 48, color: Colors.grey[400]),
                                          const SizedBox(height: 12),
                                          Text('No recent alerts', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                
                                return Column(
                                  children: alerts.map((alert) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _buildAlertCard(
                                        context,
                                        patientName: alert['patient_name'],
                                        message: alert['message'],
                                        time: _formatTimestamp(alert['timestamp']),
                                        icon: _getIconForAlert(alert['type']),
                                        color: _getColorForAlert(alert['type']),
                                        isUrgent: alert['type'] == 'urgent',
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRecentAlerts() async {
    try {
      final chwId = _supabase.auth.currentUser?.id;
      if (chwId == null) return [];

      final response = await _supabase
          .from('notifications')
          .select('id, title, message, created_at, type, is_read, patient_id, profiles!notifications_patient_id_fkey(full_name)')
          .eq('chw_id', chwId)
          .order('created_at', ascending: false)
          .limit(3);

      return response.map<Map<String, dynamic>>((n) {
        final type = (n['type'] ?? 'info').toString().toLowerCase();
        String patientName = 'Unknown Patient';
        if (n['profiles'] != null && n['profiles']['full_name'] != null) {
          patientName = n['profiles']['full_name'];
        }

        return {
          'patient_name': patientName,
          'message': n['message'] ?? 'No message',
          'timestamp': n['created_at'] ?? DateTime.now().toIso8601String(),
          'type': type.contains('high') || type.contains('urgent') || type.contains('risk') ? 'urgent' : type,
          'is_read': n['is_read'] ?? false,
        };
      }).toList();
    } catch (e) {
      print('❌ Error fetching alerts: $e');
      return [];
    }
  }

  IconData _getIconForAlert(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('urgent') || lowerType.contains('high') || lowerType.contains('risk')) {
      return Icons.warning_amber_rounded;
    } else if (lowerType.contains('reminder')) {
      return Icons.calendar_today;
    } else if (lowerType.contains('update')) {
      return Icons.info_outline;
    }
    return Icons.notifications;
  }

  Color _getColorForAlert(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('urgent') || lowerType.contains('high') || lowerType.contains('risk')) {
      return Colors.red;
    } else if (lowerType.contains('reminder')) {
      return Colors.blue;
    } else if (lowerType.contains('update')) {
      return Colors.green;
    }
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  String _formatTimestamp(String timestamp) {
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

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool urgent = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: urgent ? Border.all(color: Colors.red.withOpacity(0.3), width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: urgent ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (urgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                    child: const Text("!", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context, {
    required String patientName,
    required String message,
    required String time,
    required IconData icon,
    required Color color,
    required bool isUrgent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isUrgent ? Border.all(color: Colors.red.withOpacity(0.3), width: 2) : null,
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        patientName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                          "URGENT",
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(message, style: TextStyle(fontSize: 13, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(time, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}