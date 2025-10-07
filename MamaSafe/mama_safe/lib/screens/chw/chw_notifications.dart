import 'package:flutter/material.dart';
import 'chw_patient_details.dart';

class CHWNotifications extends StatefulWidget {
  const CHWNotifications({super.key});

  @override
  State<CHWNotifications> createState() => _CHWNotificationsState();
}

class _CHWNotificationsState extends State<CHWNotifications> {
  String _selectedTab = 'All';
  final List<String> _tabs = ['All', 'Urgent', 'Reminders', 'Updates'];

  // Mock notification data - replace with actual data from backend
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': '1',
      'type': 'urgent',
      'patientId': '001',
      'patientName': 'Mary Johnson',
      'title': 'Critical Blood Glucose Level',
      'message': 'Blood glucose reading of 185 mg/dL detected',
      'timestamp': '2024-10-04 08:15',
      'isRead': false,
      'icon': Icons.bloodtype,
      'color': Colors.red,
    },
    {
      'id': '2',
      'type': 'urgent',
      'patientId': '004',
      'patientName': 'Sarah Davis',
      'title': 'Elevated Blood Pressure',
      'message': 'BP reading: 145/92 mmHg - requires attention',
      'timestamp': '2024-10-04 07:30',
      'isRead': false,
      'icon': Icons.favorite,
      'color': Colors.red,
    },
    {
      'id': '3',
      'type': 'reminder',
      'patientId': '001',
      'patientName': 'Mary Johnson',
      'title': 'Scheduled Visit Tomorrow',
      'message': 'Home visit scheduled for 10:00 AM',
      'timestamp': '2024-10-03 18:00',
      'isRead': false,
      'icon': Icons.calendar_today,
      'color': Colors.blue,
    },
    {
      'id': '4',
      'type': 'reminder',
      'patientId': '002',
      'patientName': 'Alice Williams',
      'title': 'Medication Reminder Not Taken',
      'message': 'Patient missed morning medication',
      'timestamp': '2024-10-03 12:00',
      'isRead': true,
      'icon': Icons.medication,
      'color': Colors.orange,
    },
    {
      'id': '5',
      'type': 'update',
      'patientId': '003',
      'patientName': 'Grace Brown',
      'title': 'New Health Data Logged',
      'message': 'Patient logged blood glucose: 95 mg/dL',
      'timestamp': '2024-10-03 09:15',
      'isRead': true,
      'icon': Icons.update,
      'color': Colors.green,
    },
    {
      'id': '6',
      'type': 'urgent',
      'patientId': '004',
      'patientName': 'Sarah Davis',
      'title': 'Missed Appointment',
      'message': 'Patient did not attend scheduled visit',
      'timestamp': '2024-10-02 15:00',
      'isRead': true,
      'icon': Icons.event_busy,
      'color': Colors.red,
    },
    {
      'id': '7',
      'type': 'reminder',
      'patientId': '005',
      'patientName': 'Emma Wilson',
      'title': 'Follow-up Required',
      'message': 'Schedule follow-up visit this week',
      'timestamp': '2024-10-02 10:00',
      'isRead': true,
      'icon': Icons.schedule,
      'color': Colors.blue,
    },
  ];

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedTab == 'All') {
      return _notifications;
    } else if (_selectedTab == 'Urgent') {
      return _notifications.where((n) => n['type'] == 'urgent').toList();
    } else if (_selectedTab == 'Reminders') {
      return _notifications.where((n) => n['type'] == 'reminder').toList();
    } else {
      return _notifications.where((n) => n['type'] == 'update').toList();
    }
  }

  int get _unreadCount {
    return _notifications.where((n) => !n['isRead']).length;
  }

  void _markAsRead(String notificationId) {
    setState(() {
      final notification = _notifications.firstWhere((n) => n['id'] == notificationId);
      notification['isRead'] = true;
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification['isRead'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Notifications"),
            if (_unreadCount > 0)
              Text(
                "$_unreadCount unread",
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                "Mark all read",
                style: TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Additional filter options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _tabs.map((tab) {
                  final isSelected = _selectedTab == tab;
                  final count = tab == 'All'
                      ? _notifications.length
                      : tab == 'Urgent'
                          ? _notifications.where((n) => n['type'] == 'urgent').length
                          : tab == 'Reminders'
                              ? _notifications.where((n) => n['type'] == 'reminder').length
                              : _notifications.where((n) => n['type'] == 'update').length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        children: [
                          Text(tab),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.pink[700] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              count.toString(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTab = tab;
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
          ),

          // Notifications List
          Expanded(
            child: _filteredNotifications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredNotifications.length,
                    itemBuilder: (context, index) {
                      final notification = _filteredNotifications[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isUrgent = notification['type'] == 'urgent';
    final isRead = notification['isRead'];

    return Dismissible(
      key: Key(notification['id']),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.centerLeft,
        child: const Row(
          children: [
            Icon(Icons.check, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "Mark as read",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              "Delete",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _markAsRead(notification['id']);
          return false;
        } else {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Delete Notification"),
              content: const Text("Are you sure you want to delete this notification?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Delete"),
                ),
              ],
            ),
          );
        }
      },
      child: InkWell(
        onTap: () {
          _markAsRead(notification['id']);
          // Navigate to patient details
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CHWPatientDetails(
                patient: {
                  'id': notification['patientId'],
                  'name': notification['patientName'],
                },
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : Colors.pink[50],
            borderRadius: BorderRadius.circular(15),
            border: isUrgent ? Border.all(color: Colors.red, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: notification['color'].withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notification['icon'],
                    color: notification['color'],
                    size: 24,
                  ),
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
                              notification['title'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['patientName'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.pink[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification['message'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(notification['timestamp']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          if (!isRead) ...[
                            const Spacer(),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.pink[400],
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "No notifications",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You're all caught up!",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
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
}