import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alumni_data.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'alumni_profile_setup_screen.dart';
import 'submit_seminar_screen.dart';

class IncomingRequestsScreen extends StatefulWidget {
  final String userId;

  const IncomingRequestsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<IncomingRequestsScreen> createState() =>
      _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState
    extends State<IncomingRequestsScreen> {
  static const String apiUrl =
      'http://172.20.10.3/common_room_api';

  List<dynamic> requests = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    if (token.isEmpty) {
      return null;
    }

    return token;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('user_email');
    await prefs.remove('auth_token');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(),
      ),
          (route) => false,
    );
  }

  void openMyProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlumniProfileSetupScreen(
          userId: widget.userId,
        ),
      ),
    );
  }

  Future<void> openSubmitSeminar() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SubmitSeminarScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your seminar proposal was submitted for review.',
          ),
        ),
      );
    }
  }

  Future<void> loadRequests() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final token = await getAuthToken();

      if (!mounted) return;

      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage =
          'Your session has expired. Please log in again.';
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$apiUrl/get_incoming_requests.php'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      debugPrint('INCOMING REQUESTS STATUS: ${response.statusCode}');
      debugPrint('INCOMING REQUESTS RESPONSE: ${response.body}');

      final data =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data['success'] == true) {
        setState(() {
          requests = data['requests'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              data['message'] ?? 'Could not load requests.';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('LOAD REQUESTS ERROR: $e');

      if (!mounted) return;

      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> updateRequest(
      int requestId,
      String status,
      ) async {
    try {
      final token = await getAuthToken();

      if (!mounted) return;

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your session has expired. Please log in again.',
            ),
          ),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('$apiUrl/update_request_status.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'request_id': requestId,
          'alumni_id': widget.userId,
          'status': status,
        }),
      ).timeout(const Duration(seconds: 20));

      final data =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'accepted'
                  ? 'Request accepted successfully.'
                  : 'Request declined.',
            ),
          ),
        );

        await loadRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? 'Could not update request.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('UPDATE REQUEST ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  void openStudentChat(Map<String, dynamic> request) {
    final String studentId =
        request['student_id']?.toString() ?? '';

    final String studentName =
        request['student_name']?.toString() ?? 'Student';

    if (studentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student ID is missing.'),
        ),
      );
      return;
    }

    final nameParts = studentName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    String initials = 'S';

    if (nameParts.isNotEmpty) {
      initials = nameParts.first[0].toUpperCase();

      if (nameParts.length > 1) {
        initials += nameParts.last[0].toUpperCase();
      }
    }

    final student = AlumniData(
      userId: widget.userId,
      name: studentName,
      initials: initials,
      job: 'Student',
      company: '',
      department: '',
      graduationYear: '',
      matchPercentage: 0,
      matchReason: '',
      about: '',
      canHelpWith: const [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          alumni: student,
          studentId: studentId,
          isAlumni: true,
        ),
      ),
    );
  }

  Widget statusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'accepted':
        backgroundColor = const Color(0xFFE6ECE2);
        textColor = const Color(0xFF365B47);
        label = 'Accepted';
        break;

      case 'declined':
        backgroundColor = const Color(0xFFF3F5F1);
        textColor = const Color(0xFF7B8794);
        label = 'Declined';
        break;

      default:
        backgroundColor = const Color(0xFFF3EEDB);
        textColor = const Color(0xFF8A6500);
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  // Displays the AI review result returned by the backend.
  // This is guidance only; the alumni makes the final decision.
  Widget aiReviewPanel(Map<String, dynamic> request) {
    final String reviewStatus =
        request['ai_review_status']?.toString() ?? 'pending';

    final String reason =
        request['ai_review_reason']?.toString() ?? '';

    final int? score =
    int.tryParse(request['ai_review_score']?.toString() ?? '');

    Color panelColor;
    Color accentColor;
    IconData reviewIcon;
    String heading;
    String description;

    if (reviewStatus == 'reviewed') {
      if (score != null && score >= 61) {
        panelColor = const Color(0xFFFFF0ED);
        accentColor = const Color(0xFFB54736);
        reviewIcon = Icons.warning_amber_rounded;
        heading = 'AI review completed';
        description = 'Higher concern indicator';
      } else if (score != null && score >= 31) {
        panelColor = const Color(0xFFFFF7E8);
        accentColor = const Color(0xFF946200);
        reviewIcon = Icons.info_outline;
        heading = 'AI review completed';
        description = 'Moderate concern indicator';
      } else {
        panelColor = const Color(0xFFEDF5EF);
        accentColor = const Color(0xFF365B47);
        reviewIcon = Icons.verified_outlined;
        heading = 'AI review completed';
        description = 'Low concern indicator';
      }
    } else if (reviewStatus == 'failed') {
      panelColor = const Color(0xFFF3F5F1);
      accentColor = const Color(0xFF52606D);
      reviewIcon = Icons.info_outline;
      heading = 'AI review unavailable';
      description = 'Please review the message manually.';
    } else {
      panelColor = const Color(0xFFF3F5F1);
      accentColor = const Color(0xFF52606D);
      reviewIcon = Icons.hourglass_empty;
      heading = 'AI review pending';
      description = 'The message has not been reviewed yet.';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                reviewIcon,
                color: accentColor,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  heading,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: accentColor,
            ),
          ),
          if (reviewStatus == 'reviewed' && score != null) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                const Text(
                  'Risk indicator:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$score/100',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'A higher score indicates more concerns identified by AI.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Color(0xFF52606D),
              ),
            ),
          ],
          if (reviewStatus == 'reviewed' && reason.isNotEmpty) ...[
            const SizedBox(height: 9),
            const Text(
              'AI review reason',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172B3A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF52606D),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'AI review is only a suggestion. You make the final decision.',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              fontStyle: FontStyle.italic,
              color: Color(0xFF52606D),
            ),
          ),
        ],
      ),
    );
  }

  Widget requestCard(Map<String, dynamic> request) {
    final int requestId =
        int.tryParse(request['id']?.toString() ?? '') ?? 0;

    final String studentName =
        request['student_name']?.toString() ?? 'Student';

    final String message =
        request['message']?.toString() ?? '';

    final String status =
        request['status']?.toString() ?? 'pending';

    final String initials = studentName
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE1E5DF),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: const Color(0xFFE6ECE2),
                child: Text(
                  initials.isEmpty ? 'S' : initials,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Student',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF52606D),
                      ),
                    ),
                  ],
                ),
              ),
              statusBadge(status),
            ],
          ),

          if (message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9F7),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF52606D),
                ),
              ),
            ),
          ],

          // New AI review information.
          aiReviewPanel(request),

          if (status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: requestId == 0
                          ? null
                          : () => updateRequest(
                        requestId,
                        'declined',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                        const Color(0xFF52606D),
                        side: const BorderSide(
                          color: Color(0xFFD3D8CF),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(9),
                        ),
                      ),
                      child: const Text(
                        'Decline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: requestId == 0
                          ? null
                          : () => updateRequest(
                        requestId,
                        'accepted',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF172B3A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(9),
                        ),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (status == 'accepted') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => openStudentChat(request),
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                ),
                label: const Text(
                  'Message student',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF172B3A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget emptyRequests() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F7),
        border: Border.all(
          color: const Color(0xFFE1E5DF),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.person_add_alt_1_outlined,
            size: 38,
            color: Color(0xFF9AA5B1),
          ),
          SizedBox(height: 13),
          Text(
            'No connection requests',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF172B3A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'New student requests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF7B8794),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSubmitSeminarButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: openSubmitSeminar,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text(
          'Submit a Seminar Proposal',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
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
    final pendingCount = requests
        .where((request) => request['status'] == 'pending')
        .length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadRequests,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      const Expanded(
                        child: Text(
                          'Incoming requests',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF172B3A),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: openMyProfile,
                        icon: const Icon(
                          Icons.person_outline,
                          size: 18,
                        ),
                        label: const Text('My Profile'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                          const Color(0xFF172B3A),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: logout,
                        icon: const Icon(
                          Icons.logout,
                          size: 18,
                        ),
                        label: const Text('Logout'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                          const Color(0xFF52606D),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Students who would like to connect with you.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF52606D),
                    ),
                  ),

                  const SizedBox(height: 18),

                  buildSubmitSeminarButton(),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const Text(
                        'Connection requests',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172B3A),
                        ),
                      ),
                      const Spacer(),
                      if (pendingCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3EEDB),
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$pendingCount pending',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8A6500),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(35),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (errorMessage.isNotEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: loadRequests,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (requests.isEmpty)
                      emptyRequests()
                    else
                      for (final request in requests)
                        requestCard(
                          Map<String, dynamic>.from(request),
                        ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}