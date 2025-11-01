// lib/screens/patient/profile_completion_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:mama_safe/services/auth_service.dart';
import 'package:mama_safe/screens/patient/patient_dashboard.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  double _bmi = 0.0;
  bool _isLoading = false;
  bool _isLoadingRegions = true;
  bool _isLoadingProfile = true;

  String? selectedDistrict, selectedSector, selectedCell, selectedVillage;
  
  final AuthService _authService = AuthService();
  
  Map<String, dynamic> rwandaData = {};
  Map<String, dynamic> _existingProfile = {};

  @override
  void initState() {
    super.initState();
    _loadRegionData();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // ✅ NEW: Load existing profile data
  Future<void> _loadExistingProfile() async {
    setState(() => _isLoadingProfile = true);
    
    try {
      _existingProfile = await _authService.getProfile();
      print('📋 Loaded existing profile: $_existingProfile');

      // Auto-fill text fields
      if (_existingProfile['full_name'] != null) {
        _usernameController.text = _existingProfile['full_name'];
      }
      
      if (_existingProfile['phone'] != null) {
        _phoneController.text = _existingProfile['phone'];
      }
      
      if (_existingProfile['age'] != null) {
        _ageController.text = _existingProfile['age'].toString();
      }
      
      if (_existingProfile['height'] != null) {
        _heightController.text = _existingProfile['height'].toString();
      }
      
      if (_existingProfile['weight'] != null) {
        _weightController.text = _existingProfile['weight'].toString();
      }

      // Calculate BMI if height and weight exist
      if (_existingProfile['height'] != null && _existingProfile['weight'] != null) {
        _calculateBMI();
      }

      // Parse and auto-fill region data
      if (_existingProfile['region'] != null && _existingProfile['region'].toString().isNotEmpty) {
        _parseAndFillRegion(_existingProfile['region']);
      }

      if (mounted) {
        setState(() => _isLoadingProfile = false);
        
        // Show notification if data was auto-filled
        if (_usernameController.text.isNotEmpty || _phoneController.text.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📋 Profile data loaded successfully'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  // ✅ NEW: Parse region string and fill dropdowns
  void _parseAndFillRegion(String region) {
    try {
      // Expected format: "Village, Cell, Sector, District, Province"
      final parts = region.split(',').map((e) => e.trim()).toList();
      
      if (parts.length >= 4) {
        setState(() {
          selectedVillage = parts[0];
          selectedCell = parts[1];
          selectedSector = parts[2];
          selectedDistrict = parts[3];
        });
        print('✅ Region auto-filled: $selectedDistrict > $selectedSector > $selectedCell > $selectedVillage');
      }
    } catch (e) {
      print('⚠️ Could not parse region: $e');
    }
  }

  Future<void> _loadRegionData() async {
    try {
      final String jsonString = await rootBundle.loadString('lib/data/rwanda_regions.json');
      setState(() {
        rwandaData = json.decode(jsonString);
        _isLoadingRegions = false;
      });
    } catch (e) {
      print('Error loading regions: $e');
      // Fallback to embedded data
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
                        "villages": ["Byimana Village"]
                      },
                      {
                        "name": "Cyabararika Cell", 
                        "villages": ["Gasanze Village", "Buhuye Village"]
                      }
                    ]
                  }
                ]
              }
            ]
          }
        };
        _isLoadingRegions = false;
      });
    }
  }

  void _calculateBMI() {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);
    if (height != null && weight != null && height > 0) {
      final heightM = height / 100;
      _bmi = weight / (heightM * heightM);
      setState(() {});
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final region = selectedVillage != null 
          ? '$selectedVillage, $selectedCell, $selectedSector, $selectedDistrict, Northern Province'
          : '';

      final result = await _authService.updateProfile(
        fullName: _usernameController.text.trim(),
        phone: _phoneController.text.trim(),
        age: int.parse(_ageController.text),
        height: double.parse(_heightController.text),
        weight: double.parse(_weightController.text),
        bmi: double.parse(_bmi.toStringAsFixed(2)),
        region: region,
      );

      setState(() => _isLoading = false);

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Profile saved successfully!'), backgroundColor: Colors.green),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PatientDashboard()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error: ${result['error']}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRegions || _isLoadingProfile) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.pink[400]),
              const SizedBox(height: 16),
              Text(
                'Loading your profile...',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _existingProfile.isNotEmpty ? 'Edit Profile' : 'Complete Your Profile',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.pink[400],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload profile data',
            onPressed: _loadExistingProfile,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Message
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.pink[50]!, Colors.purple[50]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.pink[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _existingProfile.isNotEmpty ? Icons.edit : Icons.person_add,
                        size: 48,
                        color: Colors.pink[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _existingProfile.isNotEmpty 
                            ? 'Update your information'
                            : 'Let\'s complete your profile',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _existingProfile.isNotEmpty
                            ? 'Review and update your details below'
                            : 'Please provide accurate information for better care',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Personal Information Section
                _buildSectionHeader('Personal Information', Icons.person),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _usernameController,
                  label: 'Full Name',
                  icon: Icons.person,
                  validator: (value) => value?.isEmpty ?? true ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your phone number';
                    if (value.length < 10) return 'Please enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _ageController,
                  label: 'Age',
                  icon: Icons.cake,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your age';
                    if (int.tryParse(value) == null || int.parse(value) < 1) return 'Please enter a valid age';
                    return null;
                  },
                ),
                
                const SizedBox(height: 24),
                _buildSectionHeader('Body Measurements', Icons.monitor_weight),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _heightController,
                        label: 'Height (cm)',
                        icon: Icons.height,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculateBMI(),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (double.tryParse(value) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _weightController,
                        label: 'Weight (kg)',
                        icon: Icons.fitness_center,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculateBMI(),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (double.tryParse(value) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // BMI Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bmi > 0 ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _bmi > 0 ? Colors.green[200]! : Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calculate, color: _bmi > 0 ? Colors.green[700] : Colors.grey[600]),
                      const SizedBox(width: 12),
                      Text(
                        'BMI: ${_bmi > 0 ? _bmi.toStringAsFixed(1) : 'Enter height & weight'}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _bmi > 0 ? Colors.green[900] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionHeader('📍 Location (Rwanda)', Icons.location_on),
                const SizedBox(height: 16),

                // District Dropdown
                _buildDropdown(
                  value: selectedDistrict,
                  label: 'District *',
                  icon: Icons.location_city,
                  items: (rwandaData['province']?['districts'] as List?)
                      ?.map((d) => d['name'] as String)
                      .toList() ?? [],
                  onChanged: (value) {
                    setState(() {
                      selectedDistrict = value;
                      selectedSector = null;
                      selectedCell = null;
                      selectedVillage = null;
                    });
                  },
                  validator: (value) => value == null ? 'Select district' : null,
                ),
                const SizedBox(height: 16),

                // Sector Dropdown (Conditional)
                if (selectedDistrict != null)
                  _buildDropdown(
                    value: selectedSector,
                    label: 'Sector *',
                    icon: Icons.map,
                    items: _getSectorsForDistrict(selectedDistrict!),
                    onChanged: (value) {
                      setState(() {
                        selectedSector = value;
                        selectedCell = null;
                        selectedVillage = null;
                      });
                    },
                    validator: (value) => value == null ? 'Select sector' : null,
                  ),
                if (selectedDistrict != null) const SizedBox(height: 16),

                // Cell Dropdown (Conditional)
                if (selectedSector != null)
                  _buildDropdown(
                    value: selectedCell,
                    label: 'Cell *',
                    icon: Icons.location_on,
                    items: _getCellsForSector(selectedSector!),
                    onChanged: (value) {
                      setState(() {
                        selectedCell = value;
                        selectedVillage = null;
                      });
                    },
                    validator: (value) => value == null ? 'Select cell' : null,
                  ),
                if (selectedSector != null) const SizedBox(height: 16),

                // Village Dropdown (Conditional)
                if (selectedCell != null)
                  _buildDropdown(
                    value: selectedVillage,
                    label: 'Village *',
                    icon: Icons.home,
                    items: _getVillagesForCell(selectedCell!),
                    onChanged: (value) => setState(() => selectedVillage = value),
                    validator: (value) => value == null ? 'Select village' : null,
                  ),

                const SizedBox(height: 32),
                
                // Save Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[400],
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: Colors.pink.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24, width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                _existingProfile.isNotEmpty ? 'Update Profile' : 'Save Profile',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.pink[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.pink[400], size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    final hasValue = controller.text.isNotEmpty;
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.pink[400]),
        suffixIcon: hasValue 
            ? Icon(Icons.check_circle, color: Colors.green[400], size: 20)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasValue ? Colors.green[200]! : Colors.grey[300]!,
            width: hasValue ? 2 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
        ),
        filled: true,
        fillColor: hasValue ? Colors.green[50] : Colors.white,
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
    String? Function(String?)? validator,
  }) {
    final hasValue = value != null;
    
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.pink[400]),
        suffixIcon: hasValue 
            ? Icon(Icons.check_circle, color: Colors.green[400], size: 20)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasValue ? Colors.green[200]! : Colors.grey[300]!,
            width: hasValue ? 2 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
        ),
        filled: true,
        fillColor: hasValue ? Colors.green[50] : Colors.white,
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  List<String> _getSectorsForDistrict(String district) {
    try {
      final districtData = (rwandaData['province']['districts'] as List).firstWhere((d) => d['name'] == district);
      return (districtData['sectors'] as List).map<String>((s) => s['name'] as String).toList();
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
            return (s['cells'] as List).map<String>((c) => c['name'] as String).toList();
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
              return List<String>.from(c['villages']);
            }
          }
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}