
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StudentSeminarsScreen extends StatefulWidget {
  const StudentSeminarsScreen({super.key});

  @override
  State<StudentSeminarsScreen> createState() =>
      _StudentSeminarsScreenState();
}

class _StudentSeminarsScreenState extends State<StudentSeminarsScreen> {
  static const String baseUrl =
      'http://172.20.10.3/common_room_api';

  bool isLoading = true;
  String? errorMessage;
  List<dynamic> seminars = [];

  @override
  void initState() {
    super.initState();
    loadSeminars();
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> loadSeminars() async {
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

      final response = await http.get(
        Uri.parse('$baseUrl/get_approved_seminars.php'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final loadedSeminars = data['seminars'];

        if (!mounted) return;

        setState(() {
          seminars = loadedSeminars is List ? loadedSeminars : [];
          isLoading = false;
        });
      } else {
        throw Exception(
          data['message'] ?? 'Could not load seminars.',
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

  DateTime? parseSeminarDate(String? value) {
    if (value == null || value.isEmpty) return null;

    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  String formatDate(String? value) {
    final date = parseSeminarDate(value);

    if (date == null) return 'Date unavailable';

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
    final date = parseSeminarDate(value);

    if (date == null) return 'Time unavailable';

    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:$minute $period';
  }

  Future<void> showSuccessDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 75,
              ),
              const SizedBox(height: 16),
              const Text(
                'Registration Successful!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You have successfully registered for the seminar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF52606D),
                  height: 1.5,
                ),
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
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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

  Future<void> showRegistrationDialog(
      Map<String, dynamic> seminar,
      ) async {
    final contactController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final registered = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Register for Seminar'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seminar['title']?.toString() ?? 'Seminar',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter your contact number to complete registration.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactController,
                      keyboardType: TextInputType.phone,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        hintText: '+8801XXXXXXXXX',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (value) {
                        final phone = value?.trim() ?? '';

                        if (phone.isEmpty) {
                          return 'Please enter your contact number.';
                        }

                        if (!RegExp(r'^[0-9+\-\s()]{7,20}$')
                            .hasMatch(phone)) {
                          return 'Enter a valid contact number.';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    setDialogState(() {
                      isSubmitting = true;
                    });

                    final success = await registerForSeminar(
                      seminar['id'].toString(),
                      contactController.text.trim(),
                    );

                    if (!dialogContext.mounted) return;

                    if (success) {
                      Navigator.pop(dialogContext, true);
                    } else {
                      setDialogState(() {
                        isSubmitting = false;
                      });
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );

    contactController.dispose();

    if (registered == true && mounted) {
      await showSuccessDialog();
    }
  }

  Future<bool> registerForSeminar(
      String seminarId,
      String contactNumber,
      ) async {
    try {
      final token = await getAuthToken();

      if (token == null || token.isEmpty) {
        showMessage(
          'Your login session was not found. Please log in again.',
        );
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/register_seminar.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'seminar_id': int.tryParse(seminarId) ?? seminarId,
          'contact_number': contactNumber,
        }),
      ).timeout(const Duration(seconds: 20));

      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        return true;
      }

      showMessage(
        data['message'] ?? 'Registration failed. Please try again.',
      );

      return false;
    } catch (e) {
      showMessage(
        'Could not complete registration. Please check your connection.',
      );
      return false;
    }
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

  Widget buildSeminarCard(Map<String, dynamic> seminar) {
    final eventType =
        seminar['event_type']?.toString().toLowerCase() ?? 'online';

    final isOnline = eventType == 'online';

    final duration =
        seminar['duration_minutes']?.toString() ?? 'Not specified';

    final organizer =
        seminar['organizer_name']?.toString() ?? 'Unknown organizer';

    final location = seminar['location']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE1E5E9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? Colors.blue.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOnline ? 'ONLINE' : 'PHYSICAL',
                    style: TextStyle(
                      color: isOnline
                          ? Colors.blue.shade800
                          : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.verified,
                  color: Colors.green,
                  size: 18,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Approved',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              seminar['title']?.toString() ?? 'Untitled Seminar',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172B3A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              seminar['description']?.toString() ??
                  'No description available.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF52606D),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.person_outline,
              'Organizer',
              organizer,
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Date',
              formatDate(seminar['scheduled_at']?.toString()),
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              Icons.access_time,
              'Time',
              formatTime(seminar['scheduled_at']?.toString()),
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              Icons.timer_outlined,
              'Duration',
              '$duration minutes',
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              isOnline
                  ? Icons.videocam_outlined
                  : Icons.location_on_outlined,
              isOnline ? 'Event type' : 'Location',
              isOnline
                  ? 'Online seminar'
                  : (location.isEmpty
                  ? 'Location not provided'
                  : location),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showRegistrationDialog(seminar),
                icon: const Icon(Icons.app_registration),
                label: const Text('Register Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF172B3A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon,
      String label,
      String value,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: const Color(0xFF52606D),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF52606D),
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172B3A),
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text(
          'Upcoming Seminars',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF172B3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: loadSeminars,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh seminars',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadSeminars,
        child: isLoading
            ? ListView(
          children: const [
            SizedBox(height: 250),
            Center(
              child: CircularProgressIndicator(),
            ),
          ],
        )
            : errorMessage != null
            ? ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 100),
            const Icon(
              Icons.error_outline,
              size: 55,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: loadSeminars,
                child: const Text('Try Again'),
              ),
            ),
          ],
        )
            : seminars.isEmpty
            ? ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 110),
            Icon(
              Icons.event_busy,
              size: 65,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'No upcoming seminars available.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF52606D),
                ),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Approved seminars will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: seminars.length,
          itemBuilder: (context, index) {
            final seminar =
            Map<String, dynamic>.from(
              seminars[index] as Map,
            );

            return buildSeminarCard(seminar);
          },
        ),
      ),
    );
  }
}
