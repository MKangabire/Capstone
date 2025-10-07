import 'package:flutter/material.dart';

class PatientHistory extends StatefulWidget {
  const PatientHistory({super.key});

  @override
  State<PatientHistory> createState() => _PatientHistoryState();
}

class _PatientHistoryState extends State<PatientHistory>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _selectedFilter = 'All Time';

  final List<String> _filterOptions = [
    'All Time',
    'This Week',
    'This Month',
    'Last 3 Months',
  ];

  // Mock data - replace with actual data from your backend
  final List<Map<String, dynamic>> _glucoseHistory = [
    {
      'date': '2024-10-01',
      'time': '08:00 AM',
      'value': 95,
      'mealTime': 'Fasting',
      'status': 'Normal',
    },
    {
      'date': '2024-09-30',
      'time': '02:30 PM',
      'value': 142,
      'mealTime': 'After Lunch',
      'status': 'High',
    },
    {
      'date': '2024-09-30',
      'time': '08:15 AM',
      'value': 88,
      'mealTime': 'Fasting',
      'status': 'Normal',
    },
    {
      'date': '2024-09-29',
      'time': '07:45 PM',
      'value': 118,
      'mealTime': 'After Dinner',
      'status': 'Normal',
    },
  ];

  final List<Map<String, dynamic>> _bloodPressureHistory = [
    {
      'date': '2024-10-01',
      'time': '08:00 AM',
      'systolic': 118,
      'diastolic': 76,
      'status': 'Normal',
    },
    {
      'date': '2024-09-30',
      'time': '02:30 PM',
      'systolic': 135,
      'diastolic': 88,
      'status': 'Elevated',
    },
    {
      'date': '2024-09-29',
      'time': '07:45 PM',
      'systolic': 122,
      'diastolic': 79,
      'status': 'Normal',
    },
  ];

  final List<Map<String, dynamic>> _weightHistory = [
    {
      'date': '2024-10-01',
      'weight': 65.5,
      'bmi': 24.1,
      'change': '+0.5',
    },
    {
      'date': '2024-09-24',
      'weight': 65.0,
      'bmi': 23.9,
      'change': '+0.3',
    },
    {
      'date': '2024-09-17',
      'weight': 64.7,
      'bmi': 23.8,
      'change': '+0.4',
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
        return Colors.green;
      case 'high':
      case 'elevated':
        return Colors.orange;
      case 'low':
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Health History"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Glucose"),
            Tab(text: "Blood Pressure"),
            Tab(text: "Weight"),
          ],
        ),
      ),
      body: Column(
        children: [
          // You can add a filter dropdown here if needed
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGlucoseHistory(),
                _buildBloodPressureHistory(),
                _buildWeightHistory(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export feature coming soon')),
          );
        },
        icon: const Icon(Icons.download),
        label: const Text("Export"),
        backgroundColor: Colors.pink[400],
      ),
    );
  }

  Widget _buildGlucoseHistory() {
    if (_glucoseHistory.isEmpty) {
      return _buildEmptyState("No glucose readings yet");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _glucoseHistory.length,
      itemBuilder: (context, index) {
        final reading = _glucoseHistory[index];
        final statusColor = _getStatusColor(reading['status']);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          reading['date'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        reading['status'],
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      reading['value'].toString(),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        "mg/dL",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.restaurant_menu,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      reading['mealTime'],
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      reading['time'],
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBloodPressureHistory() {
    if (_bloodPressureHistory.isEmpty) {
      return _buildEmptyState("No blood pressure readings yet");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bloodPressureHistory.length,
      itemBuilder: (context, index) {
        final reading = _bloodPressureHistory[index];
        final statusColor = _getStatusColor(reading['status']);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          reading['date'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          reading['time'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        reading['status'],
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.arrow_upward,
                                color: Colors.red[400], size: 20),
                            const SizedBox(height: 4),
                            Text(
                              reading['systolic'].toString(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Systolic",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.arrow_downward,
                                color: Colors.blue[400], size: 20),
                            const SizedBox(height: 4),
                            Text(
                              reading['diastolic'].toString(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Diastolic",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeightHistory() {
    if (_weightHistory.isEmpty) {
      return _buildEmptyState("No weight records yet");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _weightHistory.length,
      itemBuilder: (context, index) {
        final record = _weightHistory[index];
        final isGain = record['change'].toString().startsWith('+');

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          record['date'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isGain
                            ? Colors.green[50]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isGain
                                ? Icons.trending_up
                                : Icons.trending_down,
                            size: 16,
                            color: isGain ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            record['change'],
                            style: TextStyle(
                              color: isGain ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.monitor_weight,
                                color: Colors.purple[400], size: 28),
                            const SizedBox(height: 8),
                            Text(
                              "${record['weight']} kg",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Weight",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.calculate,
                                color: Colors.teal[400], size: 28),
                            const SizedBox(height: 8),
                            Text(
                              record['bmi'].toString(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "BMI",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Start logging your health data",
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