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
  String chwName = 'Sarah';
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

    // Fetch CHW profile
    final profile = await _supabase
        .from('profiles')
        .select('full_name')
        .eq('id', chwId)
        .single();
    chwName = profile['full_name'] ?? 'CHW';

    // Total patients assigned to this CHW
    final patientsResponse = await _supabase
        .from('profiles')
        .select('id')
        .eq('chw_id', chwId)
        .eq('role', 'patient');
    totalPatients = patientsResponse.length;

    // Get patient IDs for further queries
    final patientIds = patientsResponse.map((p) => p['id']).toList();

    if (patientIds.isNotEmpty) {
      // High-risk patients (from predictions)
      final highRiskResponse = await _supabase
          .from('predictions')
          .select('patient_id')
          .inFilter('patient_id', patientIds)
          .ilike('risk_level', '%high%');
      
      // Count unique patients with high risk
      final uniqueHighRisk = highRiskResponse
          .map((p) => p['patient_id'])
          .toSet()
          .length;
      highRiskPatients = uniqueHighRisk;
    }

    // Pending visits (if you have visits table)
    try {
      final visitsResponse = await _supabase
          .from('visits')
          .select('id')
          .eq('chw_id', chwId)
          .eq('status', 'pending');
      pendingVisits = visitsResponse.length;
    } catch (e) {
      print('Visits table not available: $e');
      pendingVisits = 0;
    }

    // Today's appointments
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final todayVisits = await _supabase
          .from('visits')
          .select('id')
          .eq('chw_id', chwId)
          .gte('scheduled_date', startOfDay.toIso8601String())
          .lt('scheduled_date', endOfDay.toIso8601String());
      todayAppointments = todayVisits.length;
    } catch (e) {
      print('Visits query error: $e');
      todayAppointments = 0;
    }

    // New alerts/notifications
    try {
      final alertsResponse = await _supabase
          .from('notifications')
          .select('id')
          .eq('chw_id', chwId)
          .eq('is_read', false);
      newAlerts = alertsResponse.length;
    } catch (e) {
      print('Notifications table not available: $e');
      newAlerts = 0;
    }

    setState(() {});
    } catch (e) {
      print('Error fetching data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscriptions() {
    final chwId = _supabase.auth.currentUser?.id;
    if (chwId == null) return;

    // Subscribe to profiles for patient count
    SupabaseService.subscribeToTable('profiles', (payload) {
      if (payload.eventType == PostgresChangeEvent.insert ||
          payload.eventType == PostgresChangeEvent.update) {
        if (payload.newRecord['chw_id'] == chwId &&
            payload.newRecord['role'] == 'patient') {
          _fetchData();
        }
      }
    });

    // Subscribe to predictions for high-risk patients
    SupabaseService.subscribeToTable('predictions', (payload) {
      if (payload.eventType == PostgresChangeEvent.insert ||
          payload.eventType == PostgresChangeEvent.update) {
        _fetchData();
      }
    });

    // Subscribe to visits for pending visits and appointments
    SupabaseService.subscribeToTable('visits', (payload) {
      if (payload.eventType == PostgresChangeEvent.insert ||
          payload.eventType == PostgresChangeEvent.update) {
        if (payload.newRecord['chw_id'] == chwId) {
          _fetchData();
        }
      }
    });

    // Subscribe to notifications for new alerts
    SupabaseService.subscribeToTable('notifications', (payload) {
      if (payload.eventType == PostgresChangeEvent.insert ||
          payload.eventType == PostgresChangeEvent.update) {
        if (payload.newRecord['chw_id'] == chwId) {
          _fetchData();
        }
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 200,
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
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          chwName.isNotEmpty
                                              ? chwName[0].toUpperCase()
                                              : 'SN',
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Hello, $chwName! 👋",
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            "Community Health Worker",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(DateTime.now()),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.event_available,
                                              color: Colors.blue[700],
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "$todayAppointments visits today",
                                              style: TextStyle(
                                                color: Colors.blue[700],
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
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
                      ),
                      actions: [
                        IconButton(
                          icon: Stack(
                            children: [
                              const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                              ),
                              if (newAlerts > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
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
                              MaterialPageRoute(
                                builder: (context) => const CHWNotifications(),
                              ),
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
                                    trend: null,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const CHWPatientList(),
                                        ),
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
                                    trend: null,
                                    urgent: true,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const CHWPatientList(
                                                filterHighRisk: true,
                                              ),
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
                                    trend: null,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const CHWVisitScheduler(),
                                        ),
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
                                    trend: null,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const CHWNotifications(),
                                        ),
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
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.more_horiz, size: 18),
                                  label: const Text("More"),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildQuickActionCard(
                              context,
                              title: "Schedule Visit",
                              subtitle: "Plan home visits for your patients",
                              icon: Icons.calendar_today,
                              color: Colors.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CHWVisitScheduler(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildQuickActionCard(
                              context,
                              title: "View Reports",
                              subtitle: "Generate and analyze patient reports",
                              icon: Icons.assessment,
                              color: Colors.indigo,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CHWReports(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildQuickActionCard(
                              context,
                              title: "Emergency Contact",
                              subtitle: "Quick access to healthcare facility",
                              icon: Icons.emergency,
                              color: Colors.red,
                              urgent: true,
                              onTap: () => _showEmergencyDialog(context),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Recent Alerts",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const CHWNotifications(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blue[700],
                                  ),
                                  child: const Text("View All"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Recent alerts fetched dynamically
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: _fetchRecentAlerts(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                }
                                final alerts = snapshot.data ?? [];
                                return Column(
                                  children: alerts.isEmpty
                                      ? [const Text('No recent alerts')]
                                      : alerts.take(3).map((alert) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: _buildAlertCard(
                                              context,
                                              patientName:
                                                  alert['patient_name'],
                                              message: alert['message'],
                                              time: _formatTimestamp(
                                                alert['timestamp'],
                                              ),
                                              icon: _getIconForAlert(
                                                alert['type'],
                                              ),
                                              color: _getColorForAlert(
                                                alert['type'],
                                              ),
                                              isUrgent:
                                                  alert['type'] == 'urgent',
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
    final chwId = _supabase.auth.currentUser?.id;
    if (chwId == null) return [];

    final response = await _supabase
        .from('notifications')
        .select('''
          id, title, message, timestamp, type, is_read,
          profiles!notifications_patient_id_fkey(full_name)
        ''')
        .eq('chw_id', chwId)
        .order('timestamp', ascending: false)
        .limit(3);

    return response
        .map(
          (n) => {
            'patient_name': n['profiles']['full_name'],
            'message': n['message'],
            'timestamp': n['timestamp'],
            'type': n['type'],
            'is_read': n['is_read'],
          },
        )
        .toList();
  }

  IconData _getIconForAlert(String type) {
    switch (type) {
      case 'urgent':
        return Icons.bloodtype;
      case 'reminder':
        return Icons.calendar_today;
      case 'update':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForAlert(String type) {
    switch (type) {
      case 'urgent':
        return Colors.red;
      case 'reminder':
        return Colors.blue;
      case 'update':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  String _formatTimestamp(String timestamp) {
    final now = DateTime.now();
    final dateTime = DateTime.parse(timestamp.replaceAll(' ', 'T'));
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago";
    } else {
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    }
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            const Text("Emergency Contact", style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Call the healthcare facility emergency line?",
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  const Text(
                    "+250 123 456 789",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement call functionality
            },
            icon: const Icon(Icons.phone),
            label: const Text("Call Now"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? trend,
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
          border: urgent
              ? Border.all(color: Colors.red.withOpacity(0.3), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: urgent
                  ? Colors.red.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.08),
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
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trend,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (urgent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "!",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
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
          border: urgent
              ? Border.all(color: color.withOpacity(0.3), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
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
        border: isUrgent
            ? Border.all(color: Colors.red.withOpacity(0.3), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "URGENT",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
