// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mama_safe/services/auth_service.dart';
import 'package:mama_safe/services/supabase_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final _chwFormKey = GlobalKey<FormState>();
  final _chwNameController = TextEditingController();
  final _chwEmailController = TextEditingController();
  final _chwPhoneController = TextEditingController();
  final _chwPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isLoadingRegions = true;

  // Region selection
  String? selectedDistrict, selectedSector, selectedCell, selectedVillage;
  Map<String, dynamic> rwandaData = {};

  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = SupabaseService.client;

  // Tab controller
  late TabController _tabController;

  // Statistics
  int totalPatients = 0;
  int totalCHWs = 0;
  int totalHighRisk = 0;
  int unassignedPatients = 0;

  // Lists for management
  List<Map<String, dynamic>> _allPatients = [];
  List<Map<String, dynamic>> _allCHWs = [];
  bool _isLoadingPatients = false;
  bool _isLoadingCHWs = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = SupabaseService.client.auth.currentSession;
      final role = session?.user.userMetadata?['role'];
      final userId = session?.user.id;
      debugPrint('JWT ROLE: $role');
      debugPrint('USER ID: $userId');
    });

    _loadRegionData();
    _fetchStatistics();
    _fetchAllPatients();
    _fetchAllCHWs();
  }

  @override
  void dispose() {
    _chwNameController.dispose();
    _chwEmailController.dispose();
    _chwPhoneController.dispose();
    _chwPasswordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRegionData() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'lib/data/rwanda_regions.json',
      );
      setState(() {
        rwandaData = json.decode(jsonString);
        _isLoadingRegions = false;
      });
    } catch (e) {
      setState(() {
        rwandaData = {
          "province": {
            "name": "Northern Province",
            "districts": [
              {
                "name": "Musanze District",
                "sectors": [
                  {
                    "name": "Muhoza Sector",
                    "cells": [
                      {
                        "name": "Kigombe Cell",
                        "villages": ["Byimana Village"],
                      },
                      {
                        "name": "Cyabararika Cell",
                        "villages": ["Gasanze Village", "Buhuye Village"],
                      },
                    ],
                  },
                ],
              },
            ],
          },
        };
        _isLoadingRegions = false;
      });
    }
  }

  Future<void> _fetchStatistics() async {
    try {
      final currentRole = await _authService.getUserRole();
      debugPrint('Current user role: $currentRole');

      if (currentRole != 'admin') {
        throw 'Access denied: User is not an admin';
      }

      final allProfiles = await _supabase
          .from('profiles')
          .select('id, role, chw_id')
          .timeout(const Duration(seconds: 30));

      final profilesList = allProfiles as List;

      final patientIds = profilesList
          .where((p) => p['role']?.toString().toLowerCase() == 'patient')
          .map((p) => p['id'].toString())
          .toList();

      totalPatients = patientIds.length;
      totalCHWs = profilesList
          .where((p) => p['role']?.toString().toLowerCase() == 'chw')
          .length;
      unassignedPatients = profilesList
          .where(
            (p) =>
                p['role']?.toString().toLowerCase() == 'patient' &&
                p['chw_id'] == null,
          )
          .length;

      totalHighRisk = 0;
      if (patientIds.isNotEmpty) {
        final predictions = await _supabase
            .from('predictions')
            .select('patient_id, risk_level')
            .inFilter('patient_id', patientIds);

        totalHighRisk = (predictions as List)
            .where(
              (p) =>
                  p['risk_level']?.toString().toLowerCase().contains('high') ==
                  true,
            )
            .length;
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading statistics: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _fetchAllPatients() async {
    setState(() => _isLoadingPatients = true);
    try {
      final response = await _supabase
          .from('profiles')
          .select(
            'id, full_name, email, phone, age, region, chw_id, created_at, role',
          )
          .eq('role', 'patient')
          .order('created_at', ascending: false);

      debugPrint('PATIENTS RESPONSE: $response');
      final patientsList = response as List;

      for (var patient in patientsList) {
        if (patient['chw_id'] != null) {
          try {
            final chwResponse = await _supabase
                .from('profiles')
                .select('full_name')
                .eq('id', patient['chw_id'])
                .single();
            patient['chw_name'] = chwResponse['full_name'];
          } catch (e) {
            patient['chw_name'] = 'Unknown CHW';
          }
        } else {
          patient['chw_name'] = null;
        }
      }

      setState(() {
        _allPatients = List<Map<String, dynamic>>.from(patientsList);
      });
    } catch (e) {
      debugPrint('Patients fetch error: $e');
    } finally {
      setState(() => _isLoadingPatients = false);
    }
  }

  Future<void> _fetchAllCHWs() async {
    setState(() => _isLoadingCHWs = true);
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, email, phone, region, created_at, role')
          .eq('role', 'chw')
          .order('created_at', ascending: false);

      final chwsList = response as List;

      for (var chw in chwsList) {
        try {
          final patientCount = await _supabase
              .from('profiles')
              .select('id')
              .eq('role', 'patient')
              .eq('chw_id', chw['id']);
          chw['patient_count'] = (patientCount as List).length;
        } catch (e) {
          chw['patient_count'] = 0;
        }
      }

      setState(() {
        _allCHWs = List<Map<String, dynamic>>.from(chwsList);
      });
    } catch (e) {
      debugPrint('CHWs fetch error: $e');
    } finally {
      setState(() => _isLoadingCHWs = false);
    }
  }

  // ASSIGN PATIENT to CHW
Future<void> _assignCHWToPatient(String patientId, String patientName) async {
  print('🔍 Starting CHW assignment for patient: $patientName ($patientId)');
  
  if (_allCHWs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No CHWs available to assign'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  final selectedCHW = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Assign CHW to $patientName'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _allCHWs.length,
          itemBuilder: (context, index) {
            final chw = _allCHWs[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Text(
                  chw['full_name']?[0] ?? '?',
                  style: TextStyle(color: Colors.blue[700]),
                ),
              ),
              title: Text(chw['full_name'] ?? 'Unknown'),
              subtitle: Text('${chw['region'] ?? 'No region'}\n${chw['patient_count'] ?? 0} patients'),
              isThreeLine: true,
              onTap: () => Navigator.pop(context, chw),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  if (selectedCHW == null) {
    print('❌ No CHW selected');
    return;
  }

  try {
    print('🔍 Assigning CHW ${selectedCHW['id']} to patient $patientId');
    
    final response = await _supabase
        .from('profiles')
        .update({
          'chw_id': selectedCHW['id'],
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', patientId)
        .select()
        .timeout(const Duration(seconds: 10));

    print('✅ Assignment response: $response');

    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$patientName assigned to ${selectedCHW['full_name']}'),
        backgroundColor: Colors.green,
      ),
    );

    // Refresh data
    await Future.wait([
      _fetchStatistics(),
      _fetchAllPatients(),
      _fetchAllCHWs(),
    ]);
    
  } on PostgrestException catch (e) {
    print('❌ Supabase error: ${e.message}');
    print('❌ Details: ${e.details}');
    print('❌ Hint: ${e.hint}');
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Database error: ${e.message}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  } catch (e) {
    print('❌ Error assigning CHW: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

// UNASSIGN CHW from PATIENT
Future<void> _unassignCHW(String patientId, String patientName) async {
  print('🔍 Starting CHW unassignment for patient: $patientName ($patientId)');
  
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unassign CHW'),
      content: Text('Remove CHW assignment from $patientName?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Unassign'),
        ),
      ],
    ),
  );

  if (confirm != true) {
    print('❌ Unassignment cancelled');
    return;
  }

  try {
    print('🔍 Removing CHW assignment from patient $patientId');
    
    final response = await _supabase
        .from('profiles')
        .update({
          'chw_id': null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', patientId)
        .select()
        .timeout(const Duration(seconds: 10));

    print('✅ Unassignment response: $response');

    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CHW unassigned from $patientName'),
        backgroundColor: Colors.orange,
      ),
    );

    // Refresh data
    await Future.wait([
      _fetchStatistics(),
      _fetchAllPatients(),
      _fetchAllCHWs(),
    ]);
    
  } on PostgrestException catch (e) {
    print('❌ Supabase error: ${e.message}');
    print('❌ Details: ${e.details}');
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Database error: ${e.message}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  } catch (e) {
    print('❌ Error unassigning CHW: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

// ASSIGN PATIENT(S) to CHW (from CHW tab)
Future<void> _assignPatientsToCHW(String chwId, String chwName) async {
  print('🔍 Starting patient assignment to CHW: $chwName ($chwId)');
  
  final unassignedPatients = _allPatients.where((p) => p['chw_id'] == null).toList();

  if (unassignedPatients.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No unassigned patients available'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  final selectedPatients = await showDialog<List<Map<String, dynamic>>>(
    context: context,
    builder: (context) {
      final selected = <Map<String, dynamic>>[];
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Assign Patients to $chwName'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: unassignedPatients.length,
                itemBuilder: (context, index) {
                  final patient = unassignedPatients[index];
                  final isSelected = selected.contains(patient);
                  return CheckboxListTile(
                    title: Text(patient['full_name'] ?? 'Unknown'),
                    subtitle: Text(patient['region'] ?? 'No region'),
                    value: isSelected,
                    onChanged: (val) {
                      setStateDialog(() {
                        if (val == true) {
                          selected.add(patient);
                        } else {
                          selected.remove(patient);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, selected),
                child: Text('Assign ${selected.length} Patient(s)'),
              ),
            ],
          );
        },
      );
    },
  );

  if (selectedPatients == null || selectedPatients.isEmpty) {
    print('❌ No patients selected');
    return;
  }

  try {
    print('🔍 Assigning ${selectedPatients.length} patients to CHW $chwId');
    
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Text('Assigning ${selectedPatients.length} patient(s)...'),
            ],
          ),
          duration: const Duration(seconds: 30),
        ),
      );
    }

    int successCount = 0;
    int failCount = 0;

    for (var patient in selectedPatients) {
      try {
        await _supabase
            .from('profiles')
            .update({
              'chw_id': chwId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', patient['id'])
            .timeout(const Duration(seconds: 10));
        
        successCount++;
        print('✅ Assigned patient ${patient['full_name']} to CHW');
      } catch (e) {
        failCount++;
        print('❌ Failed to assign patient ${patient['full_name']}: $e');
      }
    }

    if (!mounted) return;
    
    // Hide loading indicator
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failCount == 0
              ? '$successCount patient(s) assigned to $chwName'
              : '$successCount assigned, $failCount failed',
        ),
        backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
      ),
    );

    // Refresh data
    await Future.wait([
      _fetchStatistics(),
      _fetchAllPatients(),
      _fetchAllCHWs(),
    ]);
    
  } catch (e) {
    print('❌ Error during bulk assignment: $e');
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

  Future<void> _registerCHW() async {
    if (!_chwFormKey.currentState!.validate()) return;
    if (selectedVillage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a complete region for the CHW'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final region =
          '$selectedVillage, $selectedCell, $selectedSector, $selectedDistrict, Northern Province';

      final result = await _authService.registerUser(
        email: _chwEmailController.text.trim(),
        password: _chwPasswordController.text,
        fullName: _chwNameController.text.trim(),
        phone: _chwPhoneController.text.trim(),
        role: 'chw',
      );

      if (result['success']) {
        final userId = result['user'].id;
        await _supabase
            .from('profiles')
            .update({
              'region': region,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);

        final patientsInRegion = await _supabase
            .from('profiles')
            .select('id, full_name')
            .eq('role', 'patient')
            .eq('region', region)
            .isFilter('chw_id', null);

        if (patientsInRegion.isNotEmpty) {
          for (var patient in patientsInRegion) {
            await _supabase
                .from('profiles')
                .update({
                  'chw_id': userId,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', patient['id']);
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              patientsInRegion.isEmpty
                  ? 'CHW registered successfully!'
                  : 'CHW registered and ${patientsInRegion.length} patients auto-assigned!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        _chwNameController.clear();
        _chwEmailController.clear();
        _chwPhoneController.clear();
        _chwPasswordController.clear();
        setState(() {
          selectedDistrict = null;
          selectedSector = null;
          selectedCell = null;
          selectedVillage = null;
        });

        _fetchStatistics();
        _fetchAllPatients();
        _fetchAllCHWs();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRegions) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchStatistics();
              _fetchAllPatients();
              _fetchAllCHWs();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.people), text: 'Patients'),
            Tab(icon: Icon(Icons.badge), text: 'CHWs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildOverviewTab(), _buildPatientsTab(), _buildCHWsTab()],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'System Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Patients',
                  totalPatients.toString(),
                  Icons.people,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total CHWs',
                  totalCHWs.toString(),
                  Icons.badge,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'High Risk',
                  totalHighRisk.toString(),
                  Icons.warning,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Unassigned',
                  unassignedPatients.toString(),
                  Icons.person_off,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _chwFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.badge,
                          color: Colors.green[700],
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Register Community Health Worker',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _chwNameController,
                    label: 'Full Name *',
                    icon: Icons.person_outline,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _chwEmailController,
                    label: 'Email *',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v?.isEmpty ?? true)
                        ? 'Required'
                        : (!v!.contains('@') ? 'Invalid email' : null),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _chwPhoneController,
                    label: 'Phone Number *',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v?.isEmpty ?? true)
                        ? 'Required'
                        : (v!.length < 10 ? 'Invalid phone' : null),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _chwPasswordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          color: Colors.green[700],
                          size: 20,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.green[700]!,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (v) => (v?.isEmpty ?? true)
                        ? 'Required'
                        : (v!.length < 6 ? 'Min 6 characters' : null),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'CHW Service Region *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    value: selectedDistrict,
                    label: 'District *',
                    icon: Icons.location_city,
                    items:
                        (rwandaData['province']?['districts'] as List?)
                            ?.map((d) => d['name'] as String)
                            .toList() ??
                        [],
                    onChanged: (v) => setState(() {
                      selectedDistrict = v;
                      selectedSector = null;
                      selectedCell = null;
                      selectedVillage = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (selectedDistrict != null)
                    _buildDropdown(
                      value: selectedSector,
                      label: 'Sector *',
                      icon: Icons.map,
                      items: _getSectorsForDistrict(selectedDistrict!),
                      onChanged: (v) => setState(() {
                        selectedSector = v;
                        selectedCell = null;
                        selectedVillage = null;
                      }),
                    ),
                  if (selectedDistrict != null) const SizedBox(height: 16),
                  if (selectedSector != null)
                    _buildDropdown(
                      value: selectedCell,
                      label: 'Cell *',
                      icon: Icons.location_on,
                      items: _getCellsForSector(selectedSector!),
                      onChanged: (v) => setState(() {
                        selectedCell = v;
                        selectedVillage = null;
                      }),
                    ),
                  if (selectedSector != null) const SizedBox(height: 16),
                  if (selectedCell != null)
                    _buildDropdown(
                      value: selectedVillage,
                      label: 'Village *',
                      icon: Icons.home,
                      items: _getVillagesForCell(selectedCell!),
                      onChanged: (v) => setState(() => selectedVillage = v),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registerCHW,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_add, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Register CHW',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsTab() {
    return _isLoadingPatients
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              await _fetchAllPatients();
              await _fetchStatistics();
            },
            child: _allPatients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No patients registered',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _allPatients.length,
                    itemBuilder: (context, index) {
                      final patient = _allPatients[index];
                      final hasChw = patient['chw_id'] != null;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: hasChw
                                ? Colors.green[100]
                                : Colors.orange[100],
                            child: Icon(
                              Icons.person,
                              color: hasChw
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                            ),
                          ),
                          title: Text(
                            patient['full_name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    patient['phone'] ?? 'No phone',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    hasChw ? Icons.check_circle : Icons.warning,
                                    size: 14,
                                    color: hasChw
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      hasChw
                                          ? 'CHW: ${patient['chw_name']}'
                                          : 'No CHW assigned',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: hasChw
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: hasChw
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.person_remove,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _unassignCHW(
                                    patient['id'],
                                    patient['full_name'],
                                  ),
                                  tooltip: 'Unassign CHW',
                                )
                              : IconButton(
                                  icon: Icon(
                                    Icons.person_add,
                                    color: Colors.green[700],
                                  ),
                                  onPressed: () => _assignCHWToPatient(
                                    patient['id'],
                                    patient['full_name'],
                                  ),
                                  tooltip: 'Assign CHW',
                                ),
                        ),
                      );
                    },
                  ),
          );
  }

  Widget _buildCHWsTab() {
    return _isLoadingCHWs
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              await _fetchAllCHWs();
              await _fetchStatistics();
            },
            child: _allCHWs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No CHWs registered',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _allCHWs.length,
                    itemBuilder: (context, index) {
                      final chw = _allCHWs[index];
                      final patientCount = chw['patient_count'] ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Icon(Icons.badge, color: Colors.blue[700]),
                          ),
                          title: Text(
                            chw['full_name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.people,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$patientCount patients',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      chw['region'] ?? 'No region',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow(
                                    Icons.email,
                                    'Email',
                                    chw['email'] ?? 'Not set',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.phone,
                                    'Phone',
                                    chw['phone'] ?? 'Not set',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.location_on,
                                    'Region',
                                    chw['region'] ?? 'Not set',
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _assignPatientsToCHW(
                                        chw['id'],
                                        chw['full_name'],
                                      ),
                                      icon: const Icon(
                                        Icons.person_add,
                                        size: 18,
                                      ),
                                      label: const Text('Assign Patients'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.green[700], size: 20),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.green[700]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.green[700], size: 20),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.green[700]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }

  List<String> _getSectorsForDistrict(String district) {
    try {
      final districtData = (rwandaData['province']['districts'] as List)
          .firstWhere((d) => d['name'] == district);
      return (districtData['sectors'] as List)
          .map<String>((s) => s['name'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }

  List<String> _getCellsForSector(String sector) {
    try {
      final districts = rwandaData['province']['districts'] as List;
      for (var district in districts) {
        final sectors = district['sectors'] as List;
        for (var s in sectors) {
          if (s['name'] == sector) {
            return (s['cells'] as List)
                .map<String>((c) => c['name'] as String)
                .toList();
          }
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  List<String> _getVillagesForCell(String cell) {
    try {
      final districts = rwandaData['province']['districts'] as List;
      for (var district in districts) {
        final sectors = district['sectors'] as List;
        for (var sector in sectors) {
          final cells = sector['cells'] as List;
          for (var c in cells) {
            if (c['name'] == cell) {
              return List<String>.from(c['villages'] as List);
            }
          }
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error in _getVillagesForCell: $e');
      return [];
    }
  }
}