import 'package:flutter/material.dart';

class CHWVisitScheduler extends StatefulWidget {
  const CHWVisitScheduler({super.key});

  @override
  State<CHWVisitScheduler> createState() => _CHWVisitSchedulerState();
}

class _CHWVisitSchedulerState extends State<CHWVisitScheduler> {
  DateTime _selectedDate = DateTime.now();
  String _selectedView = 'day';

  // Mock scheduled visits
  final Map<String, List<Map<String, dynamic>>> _visits = {
    '2024-10-04': [
      {
        'time': '10:00 AM',
        'patient': 'Mary Johnson',
        'type': 'Home Visit',
        'status': 'scheduled',
        'duration': '45 min',
        'address': 'Gasabo District, KG 123 St',
      },
      {
        'time': '02:00 PM',
        'patient': 'Sarah Davis',
        'type': 'Follow-up',
        'status': 'scheduled',
        'duration': '30 min',
        'address': 'Kicukiro, KK 456 Ave',
      },
    ],
    '2024-10-05': [
      {
        'time': '09:00 AM',
        'patient': 'Alice Williams',
        'type': 'Routine Check',
        'status': 'scheduled',
        'duration': '30 min',
        'address': 'Nyarugenge, KN 789 Rd',
      },
    ],
  };

  List<Map<String, dynamic>> _getPendingVisits() {
    return [
      {
        'patient': 'Emma Wilson',
        'lastVisit': '2024-09-15',
        'daysOverdue': 19,
        'reason': 'Routine monthly check',
      },
      {
        'patient': 'Grace Brown',
        'lastVisit': '2024-09-28',
        'daysOverdue': 6,
        'reason': 'Follow-up required',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Visit Scheduler"),
        actions: [
          IconButton(
            icon: Icon(_selectedView == 'day' ? Icons.calendar_month : Icons.calendar_today),
            onPressed: () {
              setState(() {
                _selectedView = _selectedView == 'day' ? 'month' : 'day';
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(
                        Duration(days: _selectedView == 'day' ? 1 : 30),
                      );
                    });
                  },
                ),
                Column(
                  children: [
                    Text(
                      _formatDateHeader(_selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getVisitsForDate(_selectedDate).length == 1
                          ? "1 visit scheduled"
                          : "${_getVisitsForDate(_selectedDate).length} visits scheduled",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(
                        Duration(days: _selectedView == 'day' ? 1 : 30),
                      );
                    });
                  },
                ),
              ],
            ),
          ),

          // Pending Visits Alert
          if (_getPendingVisits().isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${_getPendingVisits().length} Pending Visits",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                        Text(
                          "Patients need scheduling",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _showPendingVisits,
                    child: const Text("View"),
                  ),
                ],
              ),
            ),

          // Scheduled Visits List
          Expanded(
            child: _getVisitsForDate(_selectedDate).isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _getVisitsForDate(_selectedDate).length,
                    itemBuilder: (context, index) {
                      final visit = _getVisitsForDate(_selectedDate)[index];
                      return _buildVisitCard(visit);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scheduleNewVisit,
        icon: const Icon(Icons.add),
        label: const Text("Schedule Visit"),
        backgroundColor: Colors.pink[400],
      ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> visit) {
    final statusColor = visit['status'] == 'completed'
        ? Colors.green
        : visit['status'] == 'cancelled'
            ? Colors.red
            : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.access_time, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit['patient'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.event, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            "${visit['time']} • ${visit['duration']}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    visit['type'],
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    visit['address'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.directions, size: 20),
                  onPressed: () {
                    // TODO: Open maps
                  },
                  color: Colors.pink[400],
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () => _showVisitOptions(visit),
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "No visits scheduled",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap + to schedule a new visit",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getVisitsForDate(DateTime date) {
    final dateKey = _formatDateKey(date);
    return _visits[dateKey] ?? [];
  }

  String _formatDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatDateHeader(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  void _scheduleNewVisit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Schedule New Visit",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Select Patient",
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: const [
                    DropdownMenuItem(value: '1', child: Text('Mary Johnson')),
                    DropdownMenuItem(value: '2', child: Text('Alice Williams')),
                    DropdownMenuItem(value: '3', child: Text('Sarah Davis')),
                  ],
                  onChanged: (value) {},
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Visit Type",
                    prefixIcon: Icon(Icons.medical_services),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'home', child: Text('Home Visit')),
                    DropdownMenuItem(value: 'followup', child: Text('Follow-up')),
                    DropdownMenuItem(value: 'routine', child: Text('Routine Check')),
                  ],
                  onChanged: (value) {},
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: "Date",
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () async {
                          await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: "Time",
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        readOnly: true,
                        onTap: () async {
                          await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Visit scheduled successfully')),
                    );
                  },
                  child: const Text("Schedule Visit"),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPendingVisits() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final pendingVisits = _getPendingVisits();
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Pending Visits",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...pendingVisits.map((visit) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visit['patient'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              visit['reason'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${visit['daysOverdue']} days overdue",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _scheduleNewVisit();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: const Text("Schedule"),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showVisitOptions(Map<String, dynamic> visit) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text("Mark as Completed"),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Visit marked as completed')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("Reschedule"),
                onTap: () {
                  Navigator.pop(context);
                  _scheduleNewVisit();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text("Cancel Visit"),
                onTap: () {
                  Navigator.pop(context);
                  _showCancelConfirmation();
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text("Call Patient"),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement call
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Visit"),
        content: const Text("Are you sure you want to cancel this visit?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Visit cancelled')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );
  }
}