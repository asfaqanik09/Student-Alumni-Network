
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SubmitSeminarScreen extends StatefulWidget {
  const SubmitSeminarScreen({super.key});

  @override
  State<SubmitSeminarScreen> createState() =>
      _SubmitSeminarScreenState();
}

class _SubmitSeminarScreenState extends State<SubmitSeminarScreen> {
  static const String apiUrl =
      'http://172.20.10.3/common_room_api';

  final _formKey = GlobalKey<FormState>();

  final TextEditingController titleController =
  TextEditingController();
  final TextEditingController descriptionController =
  TextEditingController();
  final TextEditingController locationController =
  TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  int durationMinutes = 60;
  String eventType = 'online';

  bool isSubmitting = false;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    super.dispose();
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

  String formatDateTime() {
    final date = selectedDate!;
    final time = selectedTime!;

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute:00';
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ??
          now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );

    if (picked != null && mounted) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> chooseTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  String get formattedDate {
    if (selectedDate == null) return 'Choose seminar date';

    final date = selectedDate!;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String get formattedTime {
    if (selectedTime == null) return 'Choose seminar time';
    return selectedTime!.format(context);
  }

  Future<void> submitSeminar() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the seminar date and time.'),
        ),
      );
      return;
    }

    if (eventType == 'physical' &&
        locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the seminar venue.'),
        ),
      );
      return;
    }

    final scheduledAt = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    if (scheduledAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a future date and time.'),
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/submit_seminar.php'),
        headers: await getHeaders(),
        body: jsonEncode({
          'title': titleController.text.trim(),
          'description': descriptionController.text.trim(),
          'scheduled_at': formatDateTime(),
          'duration_minutes': durationMinutes,
          'event_type': eventType,
          'location': locationController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 20));

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('The server returned an invalid response.');
      }

      final result = decoded;

      // Accept every successful HTTP status from 200 to 299.
      // Some PHP endpoints return 201 when a record is created.
      final bool httpSuccess =
          response.statusCode >= 200 &&
              response.statusCode < 300;

      if (httpSuccess && result['success'] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ??
                  'Seminar proposal submitted successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } else {
        throw Exception(
          result['message']?.toString() ??
              'Could not submit seminar proposal. '
                  'HTTP status: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  InputDecoration fieldDecoration(
      String label,
      String hint,
      IconData icon,
      ) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8F9F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFFD3D8CF),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFFD3D8CF),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFF172B3A),
          width: 1.5,
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF172B3A),
        ),
      ),
    );
  }

  Widget buildDateTimeButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: isSubmitting ? null : onPressed,
      icon: Icon(icon, size: 19),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF172B3A),
        minimumSize: const Size(double.infinity, 52),
        alignment: Alignment.centerLeft,
        side: const BorderSide(
          color: Color(0xFFD3D8CF),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172B3A),
        title: const Text(
          'Submit a Seminar',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Share Your Knowledge',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Submit a seminar proposal for students. '
                    'An administrator will review your proposal '
                    'before it is published.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF52606D),
                ),
              ),
              const SizedBox(height: 25),

              sectionTitle('Seminar Information'),
              TextFormField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: fieldDecoration(
                  'Seminar Title',
                  'Enter the seminar title',
                  Icons.event_note_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a seminar title.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: descriptionController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 4,
                maxLines: 6,
                decoration: fieldDecoration(
                  'Description',
                  'Describe the seminar topics and learning outcomes',
                  Icons.description_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a seminar description.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 23),

              sectionTitle('Seminar Type'),
              DropdownButtonFormField<String>(
                value: eventType,
                decoration: fieldDecoration(
                  'Event Type',
                  'Select seminar type',
                  Icons.category_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'online',
                    child: Text('Online Seminar'),
                  ),
                  DropdownMenuItem(
                    value: 'physical',
                    child: Text('Physical Seminar'),
                  ),
                ],
                onChanged: isSubmitting
                    ? null
                    : (value) {
                  if (value == null) return;
                  setState(() {
                    eventType = value;
                  });
                },
              ),
              const SizedBox(height: 15),

              if (eventType == 'physical') ...[
                TextFormField(
                  controller: locationController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: fieldDecoration(
                    'Venue / Location',
                    'Enter the seminar venue',
                    Icons.location_on_outlined,
                  ),
                  validator: (value) {
                    if (eventType == 'physical' &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please enter the seminar venue.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
              ],

              sectionTitle('Date and Time'),
              Row(
                children: [
                  Expanded(
                    child: buildDateTimeButton(
                      label: formattedDate,
                      icon: Icons.calendar_month_outlined,
                      onPressed: chooseDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildDateTimeButton(
                      label: formattedTime,
                      icon: Icons.access_time,
                      onPressed: chooseTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              sectionTitle('Seminar Duration'),
              DropdownButtonFormField<int>(
                value: durationMinutes,
                decoration: fieldDecoration(
                  'Duration',
                  'Select duration',
                  Icons.timer_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 30,
                    child: Text('30 minutes'),
                  ),
                  DropdownMenuItem(
                    value: 45,
                    child: Text('45 minutes'),
                  ),
                  DropdownMenuItem(
                    value: 60,
                    child: Text('1 hour'),
                  ),
                  DropdownMenuItem(
                    value: 90,
                    child: Text('1 hour 30 minutes'),
                  ),
                  DropdownMenuItem(
                    value: 120,
                    child: Text('2 hours'),
                  ),
                  DropdownMenuItem(
                    value: 180,
                    child: Text('3 hours'),
                  ),
                ],
                onChanged: isSubmitting
                    ? null
                    : (value) {
                  if (value == null) return;
                  setState(() {
                    durationMinutes = value;
                  });
                },
              ),
              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE1E5DF),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF52606D),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your proposal will remain pending until '
                            'an administrator reviews it. If approved, '
                            'it can be published for students.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF52606D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed:
                  isSubmitting ? null : submitSeminar,
                  icon: isSubmitting
                      ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    isSubmitting
                        ? 'Submitting...'
                        : 'Submit Seminar Proposal',
                    style: const TextStyle(
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
