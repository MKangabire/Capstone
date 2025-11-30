// lib/utils/call_helper.dart
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class CallHelper {
  /// Make a phone call directly
  static Future<void> makePhoneCall(BuildContext context, String phoneNumber) async {
    // Clean the phone number (remove spaces, dashes, etc.)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleanNumber.isEmpty) {
      _showError(context, 'Invalid phone number');
      return;
    }
    
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showError(context, 'Could not launch phone dialer');
      }
    } catch (e) {
      _showError(context, 'Error: ${e.toString()}');
    }
  }
  
  /// Make a phone call with confirmation dialog
  static Future<void> makePhoneCallWithConfirmation(
    BuildContext context, 
    String phoneNumber,
    {String? name}
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone, color: Colors.blue),
            SizedBox(width: 12),
            Text('Make a Call'),
          ],
        ),
        content: Text(
          name != null 
            ? 'Do you want to call $name at $phoneNumber?'
            : 'Do you want to call $phoneNumber?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.call),
            label: const Text('Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await makePhoneCall(context, phoneNumber);
    }
  }
  
  /// Send SMS message
  static Future<void> sendSMS(BuildContext context, String phoneNumber, {String? message}) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleanNumber.isEmpty) {
      _showError(context, 'Invalid phone number');
      return;
    }
    
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: cleanNumber,
      queryParameters: message != null ? {'body': message} : null,
    );
    
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        _showError(context, 'Could not launch SMS app');
      }
    } catch (e) {
      _showError(context, 'Error: ${e.toString()}');
    }
  }
  
  /// Send email
  static Future<void> sendEmail(
    BuildContext context, 
    String email, 
    {String? subject, String? body}
  ) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showError(context, 'Could not launch email app');
      }
    } catch (e) {
      _showError(context, 'Error: ${e.toString()}');
    }
  }
  
  /// Show error message
  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  /// Show success message
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }
}