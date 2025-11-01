// lib/screens/patient/patient_dashboard.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mama_safe/services/auth_service.dart';
import 'package:mama_safe/screens/patient/prediction_input_screen.dart.dart';
import 'package:mama_safe/screens/patient/patient_history.dart';
import 'package:mama_safe/screens/patient/profile_completion_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _predictions = [];
  bool _isLoading = false;
  int _selectedIndex = 0;

  final AuthService _authService = AuthService();
  final String _apiBaseUrl = 'https://capstone-kubh.onrender.com';
  final SupabaseClient _supabase = Supabase.instance.client; // ✅ FIXED: SUPABASE CLIENT

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchPredictions();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      _profile = await _authService.getProfile();
      print('📋 Profile from Supabase: $_profile');

      final userId = _authService.currentUser?.id;
      if (userId != null) {
        // Fetch from API
        try {
          final profileResponse = await http.get(
            Uri.parse('$_apiBaseUrl/api/patients/$userId'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 5));

          if (profileResponse.statusCode == 200) {
            final data = json.decode(profileResponse.body);
            final apiProfile = data['patient'] ?? {};
            
            if (mounted) {
              setState(() {
                _profile = {...apiProfile, ..._profile};
              });
            }
            print('✅ Profile merged with API data');
          }
        } catch (apiError) {
          print('⚠️ API fetch failed (using Supabase data only): $apiError');
        }

        // ✅ FIXED: Fetch CHW details using _supabase
        try {
          final chwId = _profile['chw_id'];
          if (chwId != null) {
            print('🔍 Fetching CHW details for ID: $chwId');
            
            final chwResponse = await _supabase
                .from('profiles')
                .select('full_name, phone, email, region')
                .eq('id', chwId)
                .single()
                .timeout(const Duration(seconds: 5));

            if (mounted) {
              setState(() {
                _profile['chw'] = chwResponse;
              });
            }
            print('✅ CHW details loaded: ${chwResponse['full_name']}');
          } else {
            print('ℹ️ No CHW assigned to this patient');
          }
        } catch (chwError) {
          print('⚠️ CHW fetch failed: $chwError');
        }
      }
      
      if (mounted) setState(() {});
    } catch (e) {
      print('❌ Profile error: $e');
      try {
        _profile = await _authService.getProfile();
      } catch (fallbackError) {
        print('❌ Fallback profile error: $fallbackError');
        _profile = {};
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPredictions() async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/predictions/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📊 Predictions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictionsList = data['predictions'] ?? [];
        
        if (mounted) {
          setState(() {
            _predictions = List<Map<String, dynamic>>.from(predictionsList);
          });
        }
      }
    } catch (e) {
      print('❌ Predictions error: $e');
    }
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  String _getRiskEmoji(String? riskLevel) {
    if (riskLevel == null) return '❓';
    final risk = riskLevel.toLowerCase();
    if (risk.contains('high')) return '🔴';
    if (risk.contains('medium') || risk.contains('moderate')) return '🟡';
    if (risk.contains('low')) return '🟢';
    return '❓';
  }

  Color _getRiskColor(String? riskLevel) {
    if (riskLevel == null) return Colors.grey;
    final risk = riskLevel.toLowerCase();
    if (risk.contains('high')) return Colors.red;
    if (risk.contains('medium') || risk.contains('moderate')) return Colors.orange;
    if (risk.contains('low')) return Colors.green;
    return Colors.grey;
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? 'Dashboard' : _selectedIndex == 1 ? 'History' : 'Profile',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.pink[400],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _fetchProfile();
                _fetchPredictions();
              },
            ),
        ],
      ),
      body: _selectedIndex == 0
          ? _buildDashboardView()
          : _selectedIndex == 1
              ? const PatientHistory()
              : _buildProfileView(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        selectedItemColor: Colors.pink[400],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PredictionInputScreen()),
                ).then((_) => _fetchPredictions());
              },
              backgroundColor: Colors.pink[400],
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('New Assessment'),
            )
          : null,
    );
  }

  Widget _buildDashboardView() {
    final latestPrediction = _predictions.isNotEmpty ? _predictions.first : null;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              await _fetchProfile();
              await _fetchPredictions();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.pink[400]!, Colors.pink[300]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome back,',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _profile['full_name'] ?? 'Patient',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Age',
                          '${_profile['age'] ?? '--'}',
                          Icons.cake,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'BMI',
                          _profile['bmi']?.toStringAsFixed(1) ?? '--',
                          Icons.monitor_weight,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Height',
                          '${_profile['height'] ?? '--'} cm',
                          Icons.height,
                          Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Weight',
                          '${_profile['weight'] ?? '--'} kg',
                          Icons.fitness_center,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAction(
                          'New Assessment',
                          Icons.add_circle_outline,
                          Colors.pink,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PredictionInputScreen(),
                              ),
                            ).then((_) => _fetchPredictions());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickAction(
                          'View History',
                          Icons.history,
                          Colors.blue,
                          () => setState(() => _selectedIndex = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (latestPrediction != null) ...[
                    Row(
                      children: [
                        const Text(
                          'Latest Assessment',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.fiber_new, color: Colors.green, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Recent',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPredictionCard(latestPrediction),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    children: [
                      const Text(
                        'Assessment History',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${_predictions.length} total',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _predictions.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _predictions.length > 3 ? 3 : _predictions.length,
                          itemBuilder: (context, index) =>
                              _buildPredictionCard(_predictions[index]),
                        ),
                  if (_predictions.length > 3)
                    TextButton(
                      onPressed: () => setState(() => _selectedIndex = 1),
                      child: const Text('View All History →'),
                    ),
                ],
              ),
            ),
          );
  }

  Widget _buildQuickAction(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.all(20),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(riskEmoji, style: const TextStyle(fontSize: 24))),
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5),
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
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.assessment_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No assessments yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to create your first GDM risk assessment',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    final hasChw = _profile['chw'] != null;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Header with Avatar
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink[400]!, Colors.pink[300]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 50, color: Colors.pink[400]),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _profile['full_name'] ?? 'Patient',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _profile['email'] ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasChw ? Icons.verified_user : Icons.person_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasChw ? 'CHW Assigned' : 'No CHW Assigned',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (hasChw) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue[50]!, Colors.blue[100]!]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.medical_services, color: Colors.blue[700], size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Your Community Health Worker',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildChwDetailRow(
                    Icons.person,
                    'Name',
                    _profile['chw']['full_name'] ?? 'Not available',
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildChwDetailRow(
                    Icons.phone,
                    'Phone',
                    _profile['chw']['phone'] ?? 'Not available',
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildChwDetailRow(
                    Icons.email,
                    'Email',
                    _profile['chw']['email'] ?? 'Not available',
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildChwDetailRow(
                    Icons.location_on,
                    'Region',
                    _profile['chw']['region'] ?? 'Not available',
                    Colors.purple,
                    isMultiline: true,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Calling ${_profile['chw']['full_name']}...'), backgroundColor: Colors.blue),
                        );
                      },
                      icon: const Icon(Icons.call, size: 20),
                      label: const Text('Contact CHW'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          _buildSectionDivider('Personal Information'),
          const SizedBox(height: 16),
          _buildProfileItem('Full Name', _profile['full_name'] ?? 'Not set', Icons.person),
          _buildProfileItem('Email', _profile['email'] ?? 'Not set', Icons.email),
          _buildProfileItem('Phone', _profile['phone'] ?? 'Not set', Icons.phone),
          const SizedBox(height: 24),
          _buildSectionDivider('Health Information'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCompactStatCard(
                  'Age',
                  '${_profile['age'] ?? '--'}',
                  Icons.cake,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactStatCard(
                  'BMI',
                  _profile['bmi']?.toStringAsFixed(1) ?? '--',
                  Icons.monitor_weight,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactStatCard(
                  'Height',
                  '${_profile['height'] ?? '--'} cm',
                  Icons.height,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactStatCard(
                  'Weight',
                  '${_profile['weight'] ?? '--'} kg',
                  Icons.fitness_center,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionDivider('Location'),
          const SizedBox(height: 16),
          _buildProfileItem('Region', _profile['region'] ?? 'Not set', Icons.location_on, isMultiline: true),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileCompletionScreen()),
                ).then((_) => _fetchProfile());
              },
              icon: const Icon(Icons.edit, size: 22),
              label: const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[400],
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: Colors.pink.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true && mounted) {
                  await _authService.logout();
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              icon: const Icon(Icons.logout, size: 22),
              label: const Text(
                'Logout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChwDetailRow(IconData icon, String label, String value, Color color, {bool isMultiline = false}) {
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: isMultiline ? null : 1,
                overflow: isMultiline ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionDivider(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(color: Colors.pink[400], borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
      ],
    );
  }

  Widget _buildCompactStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value, IconData icon, {bool isMultiline = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.pink[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.pink[400], size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: isMultiline ? null : 1,
                  overflow: isMultiline ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString.substring(0, 10);
    }
  }
}