
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alumni_data.dart';
import 'send_request_screen.dart';
import 'chat_screen.dart';

class AlumnusProfileScreen extends StatefulWidget {
  final AlumniData alumni;
  final String studentId;

  const AlumnusProfileScreen({
    super.key,
    required this.alumni,
    this.studentId = '',
  });

  @override
  State<AlumnusProfileScreen> createState() =>
      _AlumnusProfileScreenState();
}

class _AlumnusProfileScreenState
    extends State<AlumnusProfileScreen> {
  static const String apiUrl =
      'http://172.20.10.3/common_room_api';

  String requestStatus = 'none';
  bool isLoadingStatus = true;

  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadRequestStatus();
  }

  // Get the existing login token.
  Future<Map<String, String>> getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception(
        'Authentication token not found. Please log in again.',
      );
    }

    return {
      'Authorization': 'Bearer $token',
    };
  }

  // Retrieve the latest mentorship request status.
  Future<void> loadRequestStatus() async {
    if (widget.studentId.isEmpty ||
        widget.alumni.userId.isEmpty) {
      if (!mounted) return;

      setState(() {
        isLoadingStatus = false;
        errorMessage = 'Student or alumni ID is missing.';
      });

      return;
    }

    if (mounted) {
      setState(() {
        isLoadingStatus = true;
        errorMessage = '';
      });
    }

    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse(
          '$apiUrl/get_request_status.php'
              '?student_id=${Uri.encodeComponent(widget.studentId)}'
              '&alumni_id=${Uri.encodeComponent(widget.alumni.userId)}',
        ),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data['success'] == true) {
        setState(() {
          requestStatus =
              data['status']?.toString() ?? 'none';

          isLoadingStatus = false;
          errorMessage = '';
        });
      } else {
        setState(() {
          isLoadingStatus = false;

          errorMessage =
              data['message']?.toString() ??
                  'Could not retrieve connection status.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingStatus = false;

        errorMessage =
        e.toString().contains('Authentication token')
            ? 'Your login session has expired. Please log in again.'
            : 'Could not connect to the server.';
      });
    }
  }

  Future<void> openSendRequest() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SendRequestScreen(
          alumni: widget.alumni,
          studentId: widget.studentId,
        ),
      ),
    );

    if (mounted) {
      await loadRequestStatus();
    }
  }

  void openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          alumni: widget.alumni,
          studentId: widget.studentId,
        ),
      ),
    );
  }

  Widget helpChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE6ECE2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF365B47),
        ),
      ),
    );
  }

  Widget connectionButton() {
    if (isLoadingStatus) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Column(
        children: [
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: loadRequestStatus,
              child: const Text('Check again'),
            ),
          ),
        ],
      );
    }

    if (requestStatus == 'pending') {
      return Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF3EEDB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule,
              size: 20,
              color: Color(0xFFB47B00),
            ),
            SizedBox(width: 8),
            Text(
              'Request pending',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8A6500),
              ),
            ),
          ],
        ),
      );
    }

    if (requestStatus == 'accepted') {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6ECE2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Color(0xFF365B47),
                ),
                SizedBox(width: 8),
                Text(
                  'Connection accepted',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF365B47),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: openChat,
              icon: const Icon(
                Icons.chat_bubble_outline,
                size: 19,
              ),
              label: Text(
                'Message ${widget.alumni.name.split(' ').first}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF172B3A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (requestStatus == 'declined') {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'Previous request was declined',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7B8794),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: openSendRequest,
              icon: const Icon(
                Icons.send_outlined,
                size: 19,
              ),
              label: const Text(
                'Send request again',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF172B3A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: openSendRequest,
        icon: const Icon(
          Icons.person_add_alt_1_outlined,
          size: 19,
        ),
        label: const Text(
          'Send connection request',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF172B3A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alumni = widget.alumni;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Alumni Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172B3A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 25),

                Center(
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: const Color(0xFFE6ECE2),
                    child: Text(
                      alumni.initials,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Center(
                  child: Text(
                    alumni.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172B3A),
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                Center(
                  child: Text(
                    '${alumni.job} at ${alumni.company}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF52606D),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Center(
                  child: Text(
                    '${alumni.department} • Class of ${alumni.graduationYear}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7B8794),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEDB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 17,
                          color: Color(0xFFB47B00),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${alumni.matchPercentage}% AI Match',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8A6500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  'Why this match?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 9),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEDB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 19,
                        color: Color(0xFFB47B00),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          alumni.matchReason,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF52606D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                const Text(
                  'About',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  alumni.about,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF52606D),
                  ),
                ),

                const SizedBox(height: 26),

                const Text(
                  'Can help with',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: alumni.canHelpWith
                      .map((item) => helpChip(item))
                      .toList(),
                ),

                const SizedBox(height: 28),

                const Text(
                  'Experience',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9F7),
                    border: Border.all(
                      color: const Color(0xFFE1E5DF),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.work_outline,
                        color: Color(0xFF172B3A),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alumni.job,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF172B3A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alumni.company,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF52606D),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Class of ${alumni.graduationYear}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7B8794),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                connectionButton(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
