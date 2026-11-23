import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_seminar_participants_screen.dart';

class AdminSeminarsScreen extends StatefulWidget {
  const AdminSeminarsScreen({super.key});

  @override
  State<AdminSeminarsScreen> createState() =>
      _AdminSeminarsScreenState();
}

class _AdminSeminarsScreenState extends State<AdminSeminarsScreen> {
  static const String apiUrl =
      'http://172.20.10.3/common_room_api';

  List<Map<String, dynamic>> seminars = [];

  bool isLoading = true;
  String errorMessage = '';
  final Set<int> reviewingSeminars = {};

  String selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    loadSeminars();
  }

  Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception(
        'Authentication token not found. Please log in again.',
      );
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> loadSeminars() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/admin_get_seminars.php'),
        headers: await getHeaders(),
      ).timeout(const Duration(seconds: 20));

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid server response.');
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true) {
        final List<dynamic> data = decoded['seminars'] ?? [];

        if (!mounted) return;

        setState(() {
          seminars = data
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception(
          decoded['message']?.toString() ??
              'Could not load seminar proposals.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  // Open the participants screen for the selected seminar.
  Future<void> openParticipants(
      Map<String, dynamic> seminar,
      ) async {
    final seminarId = int.tryParse(
      seminar['id']?.toString() ?? '',
    );

    if (seminarId == null || seminarId <= 0) {
      showMessage('Invalid seminar ID.', isError: true);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminSeminarParticipantsScreen(
          seminarId: seminarId.toString(),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get filteredSeminars {
    if (selectedFilter == 'all') return seminars;

    return seminars.where((seminar) {
      return seminar['status']?.toString() == selectedFilter;
    }).toList();
  }

  int countByStatus(String status) {
    return seminars.where(
          (seminar) => seminar['status']?.toString() == status,
    ).length;
  }

  String formatDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'Date not available';
    }

    try {
      final date = DateTime.parse(
        value.toString().replaceFirst(' ', 'T'),
      );

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;

      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$day/$month/$year • $hour:$minute $period';
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> reviewSeminar({
    required Map<String, dynamic> seminar,
    required String status,
    String meetingLink = '',
  }) async {
    final seminarId = int.tryParse(
      seminar['id']?.toString() ?? '',
    );

    if (seminarId == null || seminarId <= 0) {
      showMessage('Invalid seminar ID.', isError: true);
      return;
    }

    setState(() {
      reviewingSeminars.add(seminarId);
    });

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/review_seminar.php'),
        headers: await getHeaders(),
        body: jsonEncode({
          'seminar_id': seminarId,
          'status': status,
          'meeting_link': meetingLink.trim(),
        }),
      ).timeout(const Duration(seconds: 20));

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid server response.');
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true) {
        if (!mounted) return;

        showMessage(
          decoded['message']?.toString() ??
              'Seminar reviewed successfully.',
        );

        await loadSeminars();
      } else {
        throw Exception(
          decoded['message']?.toString() ??
              'Could not review the seminar.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      showMessage('Review failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          reviewingSeminars.remove(seminarId);
        });
      }
    }
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> confirmRejection(
      Map<String, dynamic> seminar,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Seminar?'),
          content: const Text(
            'Are you sure you want to reject this seminar proposal?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await reviewSeminar(
        seminar: seminar,
        status: 'rejected',
      );
    }
  }

  Future<void> approveSeminar(
      Map<String, dynamic> seminar,
      ) async {
    final eventType =
        seminar['event_type']?.toString() ?? 'online';

    final meetingController = TextEditingController();
    final bool isOnline = eventType == 'online';

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Approve Seminar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Approve "${seminar['title'] ?? 'this seminar'}"?',
              ),
              if (isOnline) ...[
                const SizedBox(height: 15),
                const Text(
                  'Enter the online meeting link:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: meetingController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'https://meet.google.com/...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                const Text(
                  'This is a physical seminar. Its venue will be used as the location.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final link = meetingController.text.trim();

                if (isOnline && link.isNotEmpty) {
                  final uri = Uri.tryParse(link);

                  if (uri == null ||
                      !uri.hasScheme ||
                      !['http', 'https'].contains(
                        uri.scheme.toLowerCase(),
                      ) ||
                      uri.host.isEmpty ||
                      link.length > 500) {
                    ScaffoldMessenger.of(dialogContext)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter a valid HTTP or HTTPS meeting link.',
                        ),
                      ),
                    );
                    return;
                  }
                }

                Navigator.pop(dialogContext, link);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF172B3A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    meetingController.dispose();

    if (result == null) return;

    await reviewSeminar(
      seminar: seminar,
      status: 'approved',
      meetingLink: result,
    );
  }

  Widget filterButton(
      String value,
      String label,
      int count,
      ) {
    final isSelected = selectedFilter == value;

    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          selectedFilter = value;
        });
      },
      selectedColor: const Color(0xFFE6ECE2),
      labelStyle: TextStyle(
        color: isSelected
            ? const Color(0xFF365B47)
            : const Color(0xFF52606D),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFFB7C9B5)
            : const Color(0xFFE1E5DF),
      ),
    );
  }

  Widget statusBadge(String status) {
    Color background;
    Color foreground;

    switch (status) {
      case 'approved':
        background = const Color(0xFFE6ECE2);
        foreground = const Color(0xFF365B47);
        break;
      case 'rejected':
        background = const Color(0xFFFCE8E6);
        foreground = Colors.red.shade800;
        break;
      default:
        background = const Color(0xFFF3EEDB);
        foreground = const Color(0xFF8A6500);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }

  Widget seminarCard(Map<String, dynamic> seminar) {
    final id = int.tryParse(
      seminar['id']?.toString() ?? '',
    ) ?? 0;

    final title =
        seminar['title']?.toString() ?? 'Untitled Seminar';

    final description =
        seminar['description']?.toString() ?? '';

    final status =
        seminar['status']?.toString() ?? 'pending';

    final eventType =
        seminar['event_type']?.toString() ?? 'online';

    final location =
        seminar['location']?.toString() ?? '';

    final alumniName =
        seminar['alumni_name']?.toString() ?? 'Unknown Alumni';

    final alumniEmail =
        seminar['alumni_email']?.toString() ?? '';

    final duration =
        seminar['duration_minutes']?.toString() ?? '0';

    final meetingLink =
        seminar['meeting_link']?.toString() ?? '';

    final isReviewing = reviewingSeminars.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F7),
        border: Border.all(
          color: const Color(0xFFE1E5DF),
        ),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              statusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          if (description.isNotEmpty)
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF52606D),
              ),
            ),
          const SizedBox(height: 15),
          infoRow(
            Icons.person_outline,
            'Submitted by: $alumniName',
          ),
          if (alumniEmail.isNotEmpty)
            infoRow(Icons.email_outlined, alumniEmail),
          infoRow(
            Icons.calendar_month_outlined,
            formatDateTime(seminar['scheduled_at']),
          ),
          infoRow(
            Icons.timer_outlined,
            '$duration minutes',
          ),
          infoRow(
            eventType == 'online'
                ? Icons.videocam_outlined
                : Icons.location_on_outlined,
            eventType == 'online'
                ? 'Online seminar'
                : 'Physical seminar${location.isNotEmpty ? ' • $location' : ''}',
          ),
          if (meetingLink.isNotEmpty)
            infoRow(
              Icons.link,
              'Meeting link: $meetingLink',
            ),

          // Participants button.
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => openParticipants(seminar),
              icon: const Icon(Icons.people_outline),
              label: const Text('View Participants'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF365B47),
                side: const BorderSide(
                  color: Color(0xFFB7C9B5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),

          if (status == 'pending') ...[
            const SizedBox(height: 17),
            if (isReviewing)
              const Center(
                child: CircularProgressIndicator(),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          confirmRejection(seminar),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(
                          color: Colors.red.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => approveSeminar(seminar),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF172B3A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: const Color(0xFF52606D),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF52606D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget emptySeminars() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 55),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            size: 50,
            color: Color(0xFF9AA5B1),
          ),
          const SizedBox(height: 13),
          const Text(
            'No seminars found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF172B3A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedFilter == 'all'
                ? 'Seminar proposals will appear here.'
                : 'There are no ${selectedFilter} seminars.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7B8794),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildErrorDisplay() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: Color(0xFF7B8794),
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF52606D),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Center(
          child: ElevatedButton.icon(
            onPressed: loadSeminars,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleSeminars = filteredSeminars;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172B3A),
        title: const Text(
          'Manage Seminars',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadSeminars,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh seminars',
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : errorMessage.isNotEmpty
            ? RefreshIndicator(
          onRefresh: loadSeminars,
          child: buildErrorDisplay(),
        )
            : RefreshIndicator(
          onRefresh: loadSeminars,
          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Seminar Proposals',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Review seminar proposals submitted by alumni.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF52606D),
                ),
              ),
              const SizedBox(height: 17),
              Wrap(
                spacing: 8,
                runSpacing: 5,
                children: [
                  filterButton(
                    'all',
                    'All',
                    seminars.length,
                  ),
                  filterButton(
                    'pending',
                    'Pending',
                    countByStatus('pending'),
                  ),
                  filterButton(
                    'approved',
                    'Approved',
                    countByStatus('approved'),
                  ),
                  filterButton(
                    'rejected',
                    'Rejected',
                    countByStatus('rejected'),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              if (visibleSeminars.isEmpty)
                emptySeminars()
              else
                ...visibleSeminars.map(seminarCard),
            ],
          ),
        ),
      ),
    );
  }
}