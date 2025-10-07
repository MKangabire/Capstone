import 'package:flutter/material.dart';
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
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filterOptions = ['All', 'High Risk', 'Medium Risk', 'Low Risk'];

  // Mock patient data - replace with actual data from backend
  final List<Map<String, dynamic>> _patients = [
    {
      'id': '001',
      'name': 'Mary Johnson',
      'age': 28,
      'pregnancyWeek': 24,
      'riskLevel': 'High',
      'lastVisit': '2024-09-30',
      'nextVisit': '2024-10-05',
      'phone': '+250 781 234 567',
      'bloodGlucose': 185,
      'bloodPressure': '140/90',
    },
    {
      'id': '002',
      'name': 'Alice Williams',
      'age': 32,
      'pregnancyWeek': 28,
      'riskLevel': 'Medium',
      'lastVisit': '2024-10-01',
      'nextVisit': '2024-10-08',
      'phone': '+250 782 345 678',
      'bloodGlucose': 125,
      'bloodPressure': '130/85',
    },
    {
      'id': '003',
      'name': 'Grace Brown',
      'age': 26,
      'pregnancyWeek': 20,
      'riskLevel': 'Low',
      'lastVisit': '2024-10-02',
      'nextVisit': '2024-10-09',
      'phone': '+250 783 456 789',
      'bloodGlucose': 95,
      'bloodPressure': '118/76',
    },
    {
      'id': '004',
      'name': 'Sarah Davis',
      'age': 35,
      'pregnancyWeek': 32,
      'riskLevel': 'High',
      'lastVisit': '2024-09-29',
      'nextVisit': '2024-10-04',
      'phone': '+250 784 567 890',
      'bloodGlucose': 178,
      'bloodPressure': '145/92',
    },
    {
      'id': '005',
      'name': 'Emma Wilson',
      'age': 29,
      'pregnancyWeek': 22,
      'riskLevel': 'Low',
      'lastVisit': '2024-10-01',
      'nextVisit': '2024-10-08',
      'phone': '+250 785 678 901',
      'bloodGlucose': 88,
      'bloodPressure': '115/75',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.filterHighRisk) {
      _selectedFilter = 'High Risk';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredPatients {
    return _patients.where((patient) {
      final matchesSearch = patient['name']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      
      final matchesFilter = _selectedFilter == 'All' ||
          patient['riskLevel'] == _selectedFilter.replaceAll(' Risk', '');
      
      return matchesSearch && matchesFilter;
    }).toList();
  }

  Color _getRiskColor(String riskLevel) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Patients"),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
              _showSortOptions(context);
            },
          ),
        ],
      ),
      body: Column(
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
                          selectedColor: Colors.pink[100],
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.pink[700] : Colors.grey[700],
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
                  "${_patients.where((p) => p['riskLevel'] == 'High').length} high risk",
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
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredPatients.length,
                    itemBuilder: (context, index) {
                      final patient = _filteredPatients[index];
                      return _buildPatientCard(patient);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final riskColor = _getRiskColor(patient['riskLevel']);
    final isHighRisk = patient['riskLevel'] == 'High';

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
              color: Colors.grey.withOpacity(0.2),
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
                      color: riskColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        patient['name'].toString().split(' ').map((n) => n[0]).join(),
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
                                color: riskColor.withOpacity(0.1),
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
                            Icon(Icons.child_care, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              "Week ${patient['pregnancyWeek']}",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
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
            
            // Health Metrics
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
                      "Glucose",
                      "${patient['bloodGlucose']} mg/dL",
                      Icons.water_drop_outlined,
                      patient['bloodGlucose'] > 140 ? Colors.red : Colors.green,
                    ),
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: _buildMetric(
                      "BP",
                      patient['bloodPressure'],
                      Icons.favorite_outline,
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
                          "Next Visit",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatShortDate(patient['nextVisit']),
                          style: const TextStyle(
                            fontSize: 13,
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
            Icons.search_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "No patients found",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try adjusting your search or filters",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(String date) {
    final parts = date.split('-');
    if (parts.length == 3) {
      return "${parts[2]}/${parts[1]}";
    }
    return date;
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Sort By",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text("Name (A-Z)"),
                onTap: () {
                  // TODO: Implement sorting
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning),
                title: const Text("Risk Level (High to Low)"),
                onTap: () {
                  // TODO: Implement sorting
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text("Next Visit Date"),
                onTap: () {
                  // TODO: Implement sorting
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text("Last Visit Date"),
                onTap: () {
                  // TODO: Implement sorting
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}