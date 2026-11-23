
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminSeminarParticipantsScreen extends StatefulWidget {
  final String seminarId;

  const AdminSeminarParticipantsScreen({
    super.key,
    required this.seminarId,
  });

  @override
  State<AdminSeminarParticipantsScreen> createState() =>
      _AdminSeminarParticipantsScreenState();
}

class _AdminSeminarParticipantsScreenState
    extends State<AdminSeminarParticipantsScreen> {
  static const String baseUrl =
      'http://172.20.10.3/common_room_api';

  bool isLoading = true;
  bool isSendingEmails = false;

  String? errorMessage;
  Map<String, dynamic>? seminar;
  List<dynamic> participants = [];

  @override
  void initState() {
    super.initState();
    loadParticipants();
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> loadParticipants() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await getAuthToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Your login session was not found. Please log in again.',
        );
      }

      final uri = Uri.parse(
        '$baseUrl/admin_seminar_participants.php',
      ).replace(
        queryParameters: {
          'seminar_id': widget.seminarId,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;

        setState(() {
          seminar = data['seminar'] is Map
              ? Map<String, dynamic>.from(data['seminar'] as Map)
              : null;

          participants = data['participants'] is List
              ? data['participants'] as List
              : [];

          isLoading = false;
        });
      } else {
        throw Exception(
          data['message'] ?? 'Could not load participants.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  String formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Date unavailable';
    }

    final date = DateTime.tryParse(value.replaceFirst(' ', 'T'));

    if (date == null) return value;

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String formatTime(String? value) {
    if (value == null || value.isEmpty) {
      return 'Time unavailable';
    }

    final date = DateTime.tryParse(value.replaceFirst(' ', 'T'));

    if (date == null) return '';

    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:$minute $period';
  }

  Future<void> confirmSendEmails() async {
    if (participants.isEmpty) {
      showMessage('There are no registered participants.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Send Seminar Details?'),
          content: Text(
            'You are about to send seminar details to '
                '${participants.length} registered participant(s).\n\n'
                'Do you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF172B3A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Emails'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await sendSeminarEmails();
    }
  }

  Future<void> sendSeminarEmails() async {
    if (isSendingEmails) return;

    setState(() {
      isSendingEmails = true;
    });

    try {
      final token = await getAuthToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Your login session was not found. Please log in again.',
        );
      }

      final response = await http.post(
        Uri.parse('$baseUrl/send_seminar_details.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'seminar_id': int.tryParse(widget.seminarId) ??
              widget.seminarId,
        }),
      ).timeout(const Duration(seconds: 60));

      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        if (!mounted) return;

        final total = data['total_participants'] ?? 0;
        final sent = data['emails_sent'] ?? 0;
        final failed = data['emails_failed'] ?? 0;

        await showEmailResultDialog(
          total: total.toString(),
          sent: sent.toString(),
          failed: failed.toString(),
          message: data['message']?.toString() ??
              'Email distribution completed.',
        );
      } else {
        throw Exception(
          data['message'] ?? 'Could not send seminar emails.',
        );
      }
    } catch (e) {
      showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSendingEmails = false;
        });
      }
    }
  }

  Future<void> showEmailResultDialog({
    required String total,
    required String sent,
    required String failed,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final sentCount = int.tryParse(sent) ?? 0;
        final failedCount = int.tryParse(failed) ?? 0;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                failedCount == 0
                    ? Icons.check_circle
                    : Icons.info_outline,
                color: failedCount == 0
                    ? Colors.green
                    : Colors.orange,
                size: 70,
              ),
              const SizedBox(height: 14),
              Text(
                failedCount == 0
                    ? 'Emails Sent Successfully!'
                    : 'Email Distribution Completed',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF52606D),
                ),
              ),
              const SizedBox(height: 20),
              _resultRow(
                'Total participants',
                total,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _resultRow(
                'Emails sent',
                sent,
                Colors.green,
              ),
              const SizedBox(height: 12),
              _resultRow(
                'Emails failed',
                failed,
                failedCount == 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF172B3A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _resultRow(
      String label,
      String value,
      Color color,
      ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF52606D),
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget buildSeminarInformation() {
    final title =
        seminar?['title']?.toString() ?? 'Seminar';

    final scheduledAt =
    seminar?['scheduled_at']?.toString();

    final eventType =
        seminar?['event_type']?.toString() ?? 'Unknown';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE1E5E9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF172B3A),
            ),
          ),
          const SizedBox(height: 14),
          _infoRow(
            Icons.calendar_today_outlined,
            'Date',
            formatDate(scheduledAt),
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.access_time,
            'Time',
            formatTime(scheduledAt),
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.event,
            'Event type',
            eventType.toUpperCase(),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
      IconData icon,
      String label,
      String value,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: const Color(0xFF52606D),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF52606D),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildParticipantCard(
      Map<String, dynamic> participant,
      int index,
      ) {
    final name =
        participant['attendee_name']?.toString() ??
            'Unknown participant';

    final email =
        participant['attendee_email']?.toString() ??
            'No email available';

    final phone =
        participant['contact_number']?.toString() ??
            'No contact number';

    final registeredAt =
    participant['registered_at']?.toString();

    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFE1E5E9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFE6ECE2),
                child: Text(
                  initials.isEmpty ? '?' : initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Participant ${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7B8794),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(
            Icons.email_outlined,
            'Email',
            email,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.phone_outlined,
            'Contact',
            phone,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.access_time,
            'Registered',
            registeredAt == null
                ? 'Unavailable'
                : formatDate(registeredAt),
          ),
        ],
      ),
    );
  }

  Widget buildErrorDisplay() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 55,
              color: Colors.grey,
            ),
            const SizedBox(height: 14),
            Text(
              errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF52606D),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: loadParticipants,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text(
          'Seminar Participants',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF172B3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: loadParticipants,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh participants',
          ),
        ],
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : errorMessage != null
          ? buildErrorDisplay()
          : RefreshIndicator(
        onRefresh: loadParticipants,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (seminar != null)
              buildSeminarInformation(),

            const SizedBox(height: 20),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Registered Participants',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172B3A),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6ECE2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${participants.length} registered',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172B3A),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (participants.isEmpty)
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0xFFE1E5E9),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 55,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No participants yet',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Registered participants will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF7B8794),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (int i = 0; i < participants.length; i++)
                buildParticipantCard(
                  Map<String, dynamic>.from(
                    participants[i] as Map,
                  ),
                  i,
                ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: participants.isEmpty ||
                    isSendingEmails
                    ? null
                    : confirmSendEmails,
                icon: isSendingEmails
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.email_outlined),
                label: Text(
                  isSendingEmails
                      ? 'Sending Emails...'
                      : 'Send Seminar Details to Participants',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF172B3A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}
