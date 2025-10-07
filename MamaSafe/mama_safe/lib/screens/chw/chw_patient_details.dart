import 'package:flutter/material.dart';

class CHWPatientDetails extends StatefulWidget {
  final Map<String, dynamic> patient;

  const CHWPatientDetails({
    super.key,
    required this.patient,
  });

  @override
  State<CHWPatientDetails> createState() => _CHWPatientDetailsState();
}

class _CHWPatientDetailsState extends State<CHWPatientDetails>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock detailed patient data
  final List<Map<String, dynamic>> _healthHistory = [
    {
      'date': '2024-10-01',
      'glucose': 185,
      'bp': '140/90',
      'weight': 68.5,
      'notes': 'Patient reported feeling dizzy',
    },
    {
      'date': '2024-09-28',
      'glucose': 178,
      'bp': '138/88',
      'weight': 68.0,
      'notes': 'Dietary changes recommended',
    },
    {
      'date': '2024-09-25',
      'glucose': 165,
      'bp': '135/85',
      'weight': 67.5,
      'notes': 'Regular monitoring advised',
    },
  ];

  final List<Map<String, dynamic>> _visits = [
    {
      'date': '2024-09-30',
      'type': 'Home Visit',
      'notes': 'Checked vitals, provided health education',
      'duration': '45 min',
    },
    {
      'date': '2024-09-23',
      'type': 'Home Visit',
      'notes': 'Medication adherence check, blood glucose monitoring',
      'duration': '30 min',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final patient = widget.patient;
    final riskColor = _getRiskColor(patient['riskLevel'] ?? 'Low');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () => _callPatient(patient['phone'] ?? ''),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Patient Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [riskColor, riskColor.withOpacity(0.7)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          patient['name']
                              .toString()
                              .split(' ')
                              .map((n) => n[0])
                              .join(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "ID: ${patient['id'] ?? 'N/A'}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${patient['riskLevel'] ?? 'Unknown'} Risk",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _addNote(),
                      icon: const Icon(Icons.note_add),
                      label: const Text("Add Note"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoChip(
                      Icons.cake,
                      "${patient['age'] ?? 0} yrs",
                    ),
                    _buildInfoChip(
                      Icons.child_care,
                      "Week ${patient['pregnancyWeek'] ?? 0}",
                    ),
                    _buildInfoChip(
                      Icons.phone,
                      "Contact",
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.pink[400],
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.pink[400],
              tabs: const [
                Tab(text: "Overview"),
                Tab(text: "History"),
                Tab(text: "Visits"),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildHistoryTab(),
                _buildVisitsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _scheduleVisit(),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text("Schedule Visit"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.pink[400]!, width: 2),
                    foregroundColor: Colors.pink[400],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Emergency alert
                  },
                  icon: const Icon(Icons.emergency, color: Colors.white),
                  label: const Text("Emergency Alert"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Helper Methods ----------------

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final patient = widget.patient;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Current Health Metrics",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  "Blood Glucose",
                  "${patient['bloodGlucose'] ?? 0}",
                  "mg/dL",
                  Icons.bloodtype,
                  Colors.red,
                  (patient['bloodGlucose'] ?? 0) > 140,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  "Blood Pressure",
                  patient['bloodPressure'] ?? "N/A",
                  "mmHg",
                  Icons.favorite,
                  Colors.pink,
                  false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Contact Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.phone, "Phone", patient['phone'] ?? 'N/A'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on, "Address", "Kigali, Gasabo District"),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.email, "Email", "patient@email.com"),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _healthHistory.length,
      itemBuilder: (context, index) {
        final record = _healthHistory[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record['date'], style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("Glucose: ${record['glucose']} mg/dL"),
              Text("BP: ${record['bp']}"),
              Text("Weight: ${record['weight']} kg"),
              Text("Notes: ${record['notes']}"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _visits.length,
      itemBuilder: (context, index) {
        final visit = _visits[index];
        return ListTile(
          leading: const Icon(Icons.event_available, color: Colors.pink),
          title: Text("${visit['type']} - ${visit['date']}"),
          subtitle: Text(visit['notes']),
          trailing: Text(visit['duration']),
        );
      },
    );
  }

  // Helper metric card for Overview tab
  Widget _buildMetricCard(
      String title, String value, String unit, IconData icon, Color color, bool isHigh) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                "$value $unit",
                style: TextStyle(
                  color: isHigh ? Colors.red : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.pink[400]),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    );
  }

  void _callPatient(String phone) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Calling $phone...")),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text("Edit Patient"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text("Remove Patient"),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _addNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Note added!")),
    );
  }

  void _scheduleVisit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Visit scheduled!")),
    );
  }
}
