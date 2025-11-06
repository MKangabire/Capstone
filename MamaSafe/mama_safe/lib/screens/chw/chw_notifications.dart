import 'package:flutter/material.dart';
import 'package:mama_safe/services/supabase_service.dart';

class CHWNotifications extends StatefulWidget {
  const CHWNotifications({super.key});

  @override
  State<CHWNotifications> createState() => _CHWNotificationsState();
}

class _CHWNotificationsState extends State<CHWNotifications> {
  final _supabase = SupabaseService.client;
  bool _isLoading = true;
  bool _showUnreadOnly = false;
  
  List<Map<String, dynamic>> notifications = [];
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final chwId = _supabase.auth.currentUser?.id;
      if (chwId == null) throw 'No user logged in';

      // Fetch notifications with patient info
      var query = _supabase
          .from('notifications')
          .select('''
            id,
            title,
            message,
            created_at,
            type,
            is_read,
            patient_id,
            profiles!notifications_patient_id_fkey(full_name)
          ''')
          .eq('chw_id', chwId)
          .order('created_at', ascending: false);

      // Execute query
      final response = await query;

      // Filter by read status if needed
      List<dynamic> filteredResponse = response;
      if (_showUnreadOnly) {
        filteredResponse = response.where((n) => n['is_read'] == false).toList();
      }

      notifications = response.map<Map<String, dynamic>>((n) {
        String patientName = 'Unknown Patient';
        if (n['profiles'] != null && n['profiles']['full_name'] != null) {
          patientName = n['profiles']['full_name'];
        }

        final type = (n['type'] ?? 'info').toString().toLowerCase();
        
        return {
          'id': n['id'],
          'patient_name': patientName,
          'title': n['title'] ?? 'Notification',
          'message': n['message'] ?? 'No message',
          'timestamp': n['created_at'] ?? DateTime.now().toIso8601String(),
          'type': type.contains('high') || type.contains('urgent') || type.contains('risk') 
              ? 'urgent' 
              : type,
          'is_read': n['is_read'] ?? false,
        };
      }).toList();

      // Count unread
      unreadCount = notifications.where((n) => n['is_read'] == false).length;

      setState(() {});
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      // Update local state
      setState(() {
        final index = notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          notifications[index]['is_read'] = true;
          unreadCount = notifications.where((n) => n['is_read'] == false).length;
        }
      });
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final chwId = _supabase.auth.currentUser?.id;
      if (chwId == null) return;

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('chw_id', chwId)
          .eq('is_read', false);

      _fetchNotifications();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      setState(() {
        notifications.removeWhere((n) => n['id'] == notificationId);
        unreadCount = notifications.where((n) => n['is_read'] == false).length;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      }
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final now = DateTime.now();
      final dateTime = DateTime.parse(timestamp);
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return "Just now";
      if (difference.inMinutes < 60) return "${difference.inMinutes} min ago";
      if (difference.inHours < 24) {
        return "${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago";
      }
      if (difference.inDays < 7) {
        return "${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago";
      }
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    } catch (e) {
      return "Recently";
    }
  }

  IconData _getNotificationIcon(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('urgent') || lowerType.contains('high') || lowerType.contains('risk')) {
      return Icons.warning_amber_rounded;
    } else if (lowerType.contains('reminder') || lowerType.contains('appointment')) {
      return Icons.calendar_today;
    } else if (lowerType.contains('update') || lowerType.contains('info')) {
      return Icons.info_outline;
    } else if (lowerType.contains('success') || lowerType.contains('completed')) {
      return Icons.check_circle_outline;
    }
    return Icons.notifications_outlined;
  }

  Color _getNotificationColor(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('urgent') || lowerType.contains('high') || lowerType.contains('risk')) {
      return Colors.red;
    } else if (lowerType.contains('reminder') || lowerType.contains('appointment')) {
      return Colors.blue;
    } else if (lowerType.contains('update') || lowerType.contains('info')) {
      return Colors.orange;
    } else if (lowerType.contains('success') || lowerType.contains('completed')) {
      return Colors.green;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications'),
            if (unreadCount > 0)
              Text(
                '$unreadCount unread',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _showUnreadOnly = false);
                      _fetchNotifications();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_showUnreadOnly ? Colors.blue[700] : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'All',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: !_showUnreadOnly ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _showUnreadOnly = true);
                      _fetchNotifications();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _showUnreadOnly ? Colors.blue[700] : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Unread',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _showUnreadOnly ? Colors.white : Colors.grey[600],
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _showUnreadOnly ? Colors.white : Colors.blue[700],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _showUnreadOnly ? Colors.blue[700] : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchNotifications,
                    child: notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _showUnreadOnly 
                                      ? Icons.mark_email_read_outlined 
                                      : Icons.notifications_none,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _showUnreadOnly 
                                      ? 'No unread notifications' 
                                      : 'No notifications yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _showUnreadOnly
                                      ? 'You\'re all caught up!'
                                      : 'Notifications will appear here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              final isUrgent = notification['type'] == 'urgent';
                              final isRead = notification['is_read'];

                              return Dismissible(
                                key: Key(notification['id']),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                onDismissed: (direction) {
                                  _deleteNotification(notification['id']);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    onTap: () {
                                      if (!isRead) {
                                        _markAsRead(notification['id']);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isRead ? Colors.white : Colors.blue[50],
                                        borderRadius: BorderRadius.circular(16),
                                        border: isUrgent
                                            ? Border.all(
                                                color: Colors.red.withOpacity(0.3),
                                                width: 2,
                                              )
                                            : null,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.08),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: _getNotificationColor(notification['type'])
                                                  .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _getNotificationIcon(notification['type']),
                                              color: _getNotificationColor(notification['type']),
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
                                                          fontWeight: isRead
                                                              ? FontWeight.w600
                                                              : FontWeight.bold,
                                                          color: Colors.black87,
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
                                                          'URGENT',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                    if (!isRead && !isUrgent)
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        margin: const EdgeInsets.only(left: 8),
                                                        decoration: const BoxDecoration(
                                                          color: Colors.blue,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  notification['patient_name'],
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  notification['message'],
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[700],
                                                    height: 1.4,
                                                  ),
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.access_time,
                                                      size: 14,
                                                      color: Colors.grey[500],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _formatTimestamp(notification['timestamp']),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[500],
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
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}