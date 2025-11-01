// lib/screens/chw/chw_patient_list.dart
import 'package:flutter/material.dart';
import 'package:mama_safe/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ ADDED
import 'chw_patient_details.dart';

class CHWPatientList extends StatefulWidget {
  final bool filterHighRisk;
  
  const CHWPatientList({
    super.key,
    this.filterHighRisk = false,
  });

  @override
  State<CHWPatientList> createState() => _CHWPatientListState();
}

class _CHWPatientListState extends State<CHWPatientList> {
  final TextEditingController _searchController = TextEditingController();
  final _supabase = SupabaseService.client;
  
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _patients = [];

  final List<String> _filterOptions = ['All', 'High Risk', 'Medium Risk', 'Low Risk'];

  @override
  void initState() {
    super.initState();
    if (widget.filterHighRisk) {
      _selectedFilter = 'High Risk';
    }
    _fetchPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPatients() async {
    setState(() => _isLoading = true);
    
    try {
      final chwId = _supabase.auth.currentUser?.id;
      if (chwId == null) {
        print('❌ No CHW user logged in');
        return;
      }

      print('🔍 Fetching patients for CHW: $chwId');

      // Fetch patients assigned to this CHW
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, email, phone, age, height, weight, bmi, region, created_at')
          .eq('role', 'patient')
          .eq('chw_id', chwId)
          .order('created_at', ascending: false);

      print('✅ Found ${(response as List).length} patients');

      // For each patient, get their latest prediction
      List<Map<String, dynamic>> patientsWithRisk = [];
      
      for (var patient in response) {
        try {
          // Get latest prediction for this patient
          final predictionResponse = await _supabase
              .from('predictions')
              .select('risk_level, risk_percentage, confidence, created_at')
              .eq('patient_id', patient['id'])
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          patientsWithRisk.add({
            'id': patient['id'],
            'name': patient['full_name'] ?? 'Unknown',
            'age': patient['age'] ?? 0,
            'phone': patient['phone'] ?? 'No phone',
            'region': patient['region'] ?? 'Unknown',
            'riskLevel': predictionResponse?['risk_level'] ?? 'No Assessment',
            'riskPercentage': predictionResponse?['risk_percentage'] ?? 0,
            'bloodGlucose': 0,
            'bloodPressure': 'N/A',
            'lastVisit': _formatDate(patient['created_at']),
            'nextVisit': 'Not scheduled',
            'bmi': patient['bmi']?.toDouble() ?? 0.0,
            'height': patient['height'] ?? 0,
            'weight': patient['weight'] ?? 0,
          });
          
          print('✅ Loaded patient: ${patient['full_name']} - Risk: ${predictionResponse?['risk_level']}');
        } catch (e) {
          print('⚠️ Error loading prediction for patient ${patient['id']}: $e');
          // Still add patient even without prediction
          patientsWithRisk.add({
            'id': patient['id'],
            'name': patient['full_name'] ?? 'Unknown',
            'age': patient['age'] ?? 0,
            'phone': patient['phone'] ?? 'No phone',
            'region': patient['region'] ?? 'Unknown',
            'riskLevel': 'No Assessment',
            'riskPercentage': 0,
            'bloodGlucose': 0,
            'bloodPressure': 'N/A',
            'lastVisit': _formatDate(patient['created_at']),
            'nextVisit': 'Not scheduled',
            'bmi': patient['bmi']?.toDouble() ?? 0.0,
            'height': patient['height'] ?? 0,
            'weight': patient['weight'] ?? 0,
          });
        }
      }

      if (mounted) {
        setState(() {
          _patients = patientsWithRisk;
        });
      }

      print('✅ Loaded ${_patients.length} patients with risk data');
    } on PostgrestException catch (e) { // ✅ FIXED
      print('❌ Supabase error fetching patients: ${e.message}');
      print('❌ Details: ${e.details}');
      print('❌ Hint: ${e.hint}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching patients: $e');
      print('❌ Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading patients: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ... rest of your code stays the same until the _buildPatientCard method

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final riskColor = _getRiskColor(patient['riskLevel']);
    final isHighRisk = patient['riskLevel'].toString().contains('High');

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CHWPatientDetails(patient: patient),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: isHighRisk ? Border.all(color: Colors.red, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2), // ✅ FIXED
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.1), // ✅ FIXED
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        patient['name'].toString().split(' ').map((n) => n[0]).take(2).join(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: riskColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Patient Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                patient['name'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: riskColor.withValues(alpha: 0.1), // ✅ FIXED
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                patient['riskLevel'],
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
                            Icon(Icons.cake, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              "${patient['age']} years",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                patient['phone'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
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
            
            // Additional Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetric(
                      "Risk",
                      "${patient['riskPercentage']}%",
                      Icons.trending_up,
                      riskColor,
                    ),
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: _buildMetric(
                      "BMI",
                      patient['bmi'].toStringAsFixed(1),
                      Icons.monitor_weight,
                      Colors.blue,
                    ),
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "Region",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          patient['region'].toString().split(',').first,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  // ... rest of the code remains the same
  
  List<Map<String, dynamic>> get _filteredPatients {
    return _patients.where((patient) {
      final matchesSearch = patient['name']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      
      final matchesFilter = _selectedFilter == 'All' ||
          patient['riskLevel'].toString().contains(_selectedFilter.replaceAll(' Risk', ''));
      
      return matchesSearch && matchesFilter;
    }).toList();
  }

  Color _getRiskColor(String riskLevel) {
    final risk = riskLevel.toLowerCase();
    if (risk.contains('high')) return Colors.red;
    if (risk.contains('medium') || risk.contains('moderate')) return Colors.orange;
    if (risk.contains('low')) return Colors.green;
    return Colors.grey;
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Patients", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPatients,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search and Filter Section
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search patients...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filterOptions.map((filter) {
                            final isSelected = _selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(filter),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilter = filter;
                                  });
                                },
                                backgroundColor: Colors.grey[200],
                                selectedColor: Colors.blue[100],
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.blue[700] : Colors.grey[700],
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Patient Count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey[100],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_filteredPatients.length} patients found",
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "${_patients.where((p) => p['riskLevel'].toString().contains('High')).length} high risk",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Patient List
                Expanded(
                  child: _filteredPatients.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _fetchPatients,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredPatients.length,
                            itemBuilder: (context, index) {
                              final patient = _filteredPatients[index];
                              return _buildPatientCard(patient);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? "No patients found" : "No patients assigned yet",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? "Try adjusting your search or filters"
                : "Patients will appear here when they register in your region",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}