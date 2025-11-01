// lib/screens/chw/chw_profile.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mama_safe/services/supabase_service.dart';

class CHWProfile extends StatefulWidget {
  const CHWProfile({super.key});

  @override
  State<CHWProfile> createState() => _CHWProfileState();
}

class _CHWProfileState extends State<CHWProfile> {
  final _supabase = SupabaseService.client;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _recentVisits = [];
  List<Map<String, dynamic>> _recentPredictions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
    _setupRealtimeSubscriptions();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    try {
      final chwId = _supabase.auth.currentUser?.id;
      if (chwId == null) throw 'No user logged in';

      // Fetch profile
      final profile = await _supabase
          .from('profiles')
          .select('full_name, email, phone, region')
          .eq('id', chwId)
          .single();
      _profileData = profile;

      // Fetch recent visits
      final visits = await _supabase
          .from('visits')
          .select('id, patient_id, scheduled_date, status, notes, profiles!visits_patient_id_fkey(full_name)')
          .eq('chw_id', chwId)
          .order('scheduled_date', ascending: false)
          .limit(5);
      _recentVisits = visits.map((v) => {
            'id': v['id'],
            'patient_name': v['profiles']['full_name'],
            'scheduled_date': v['scheduled_date'],
            'status': v['status'],
            'notes': v['notes'],
          }).toList();

      // Fetch recent predictions
      final predictions = await _supabase
          .from('predictions')
          .select('patient_id, is_high_risk, risk_score, timestamp, profiles!predictions_patient_id_fkey(full_name)')
          .inFilter('patient_id', await _supabase.from('profiles').select('id').eq('chw_id', chwId))
          .order('timestamp', ascending: false)
          .limit(5);
      _recentPredictions = predictions.map((p) => {
            'patient_name': p['profiles']['full_name'],
            'is_high_risk': p['is_high_risk'],
            'risk_score': p['risk_score'],
            'timestamp': p['timestamp'],
          }).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscriptions() {
    final chwId = _supabase.auth.currentUser?.id;
    if (chwId == null) return;

    SupabaseService.subscribeToTable('profiles', (payload) {
      if (payload.eventType == PostgresChangeEvent.update && payload.newRecord['id'] == chwId) {
        _fetchProfileData();
      }
    });

    SupabaseService.subscribeToTable('visits', (payload) {
      if (payload.eventType == PostgresChangeEvent.insert && payload.newRecord['chw_id'] == chwId) {
        _fetchProfileData();
      }
    });

    SupabaseService.subscribeToTable('predictions', (payload) {
      if (payload.eventType == PostgresChangeEvent.insert) {
        _fetchProfileData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Implement edit profile functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _supabase.auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profileData == null
              ? const Center(child: Text('No profile data'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue[100],
                              ),
                              child: Center(
                                child: Text(
                                  _profileData!['full_name']?.substring(0, 1).toUpperCase() ?? 'C',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _profileData!['full_name'] ?? 'Community Health Worker',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _profileData!['region'] ?? 'Unknown Region',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Contact Information
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Contact Information",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                leading: Icon(Icons.email, color: Colors.blue[700]),
                                title: Text(_profileData!['email'] ?? 'No email'),
                                subtitle: const Text("Email"),
                              ),
                              ListTile(
                                leading: Icon(Icons.phone, color: Colors.blue[700]),
                                title: Text(_profileData!['phone'] ?? 'No phone'),
                                subtitle: const Text("Phone"),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Recent Visits
                      Text(
                        "Recent Visits",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                      ),
                      const SizedBox(height: 12),
                      _recentVisits.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text("No recent visits"),
                            )
                          : Column(
                              children: _recentVisits.map((visit) {
                                return ListTile(
                                  leading: Icon(
                                    visit['status'] == 'completed' ? Icons.check_circle : Icons.schedule,
                                    color: visit['status'] == 'completed' ? Colors.green : Colors.orange,
                                  ),
                                  title: Text(visit['patient_name']),
                                  subtitle: Text(
                                    "${visit['status']} - ${_formatDate(visit['scheduled_date'])}",
                                  ),
                                  onTap: () {
                                    // Navigate to visit details if needed
                                  },
                                );
                              }).toList(),
                            ),
                      const SizedBox(height: 24),
                      // Recent Predictions
                      Text(
                        "Recent Predictions",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                      ),
                      const SizedBox(height: 12),
                      _recentPredictions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text("No recent predictions"),
                            )
                          : Column(
                              children: _recentPredictions.map((prediction) {
                                return ListTile(
                                  leading: Icon(
                                    prediction['is_high_risk'] ? Icons.warning : Icons.info,
                                    color: prediction['is_high_risk'] ? Colors.red : Colors.blue,
                                  ),
                                  title: Text(prediction['patient_name']),
                                  subtitle: Text(
                                    "Risk Score: ${prediction['risk_score']} - ${_formatDate(prediction['timestamp'])}",
                                  ),
                                  onTap: () {
                                    // Navigate to patient details if needed
                                  },
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),
    );
  }

  String _formatDate(String date) {
    final dateTime = DateTime.parse(date.replaceAll(' ', 'T'));
    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }
}