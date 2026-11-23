
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alumni_data.dart';

class SendRequestScreen extends StatefulWidget {
  final AlumniData alumni;
  final String studentId;

  const SendRequestScreen({
    super.key,
    required this.alumni,
    this.studentId = '',
  });

  @override
  State<SendRequestScreen> createState() =>
      _SendRequestScreenState();
}

class _SendRequestScreenState extends State<SendRequestScreen> {
  final TextEditingController messageController =
  TextEditingController();

  bool isSending = false;
  bool isGenerating = false;

  static const String baseUrl =
      'http://172.20.10.3/common_room_api';

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    if (token.isEmpty) {
      showMessage('Your session has expired. Please log in again.');
      return null;
    }

    return token;
  }

  // Generate a personalized message using Gemini.
  Future<void> generateAiMessage() async {
    if (isGenerating || isSending) return;

    final String alumniId = widget.alumni.userId.trim();

    if (alumniId.isEmpty) {
      showMessage('Alumni account ID is missing. Please try again.');
      return;
    }

    setState(() {
      isGenerating = true;
    });

    try {
      final token = await getAuthToken();

      if (!mounted) return;

      if (token == null) return;

      final response = await http.post(
        Uri.parse('$baseUrl/generate_request_message.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'alumni_id': alumniId,
        }),
      );

      if (!mounted) return;

      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          data['success'] == true) {
        final generatedMessage =
            data['generated_message']?.toString() ?? '';

        if (generatedMessage.isEmpty) {
          showMessage('Gemini returned an empty message. Try again.');
          return;
        }

        // Put the AI-generated message into the editable text field.
        messageController.text = generatedMessage;

        showMessage('Your personalized AI message is ready!');
      } else {
        showMessage(
          data['message']?.toString() ??
              'Could not generate an AI message. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Could not connect to Gemini. Please check your internet connection and XAMPP.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }
  }

  // Send the student's mentorship request.
  Future<void> sendRequest() async {
    if (isSending || isGenerating) return;

    final String alumniId = widget.alumni.userId.trim();

    if (alumniId.isEmpty) {
      showMessage('Alumni account ID is missing. Please try again.');
      return;
    }

    final String typedMessage = messageController.text.trim();

    final String message = typedMessage.isEmpty
        ? 'Hi ${widget.alumni.name.split(' ').first}, '
        'I would like to connect with you and learn '
        'from your experience.'
        : typedMessage;

    if (message.length > 300) {
      showMessage('Your message cannot exceed 300 characters.');
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final token = await getAuthToken();

      if (!mounted) return;

      if (token == null) return;

      final response = await http.post(
        Uri.parse('$baseUrl/send_request.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'alumni_id': alumniId,
          'message': message,
        }),
      );

      if (!mounted) return;

      final Map<String, dynamic> data =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connection request sent to ${widget.alumni.name}.',
            ),
            backgroundColor: const Color(0xFF365B47),
          ),
        );

        Navigator.pop(context, true);
      } else {
        showMessage(
          data['message']?.toString() ??
              'Could not send the request. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Could not connect to the server. Please check that XAMPP Apache and MySQL are running.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // AI message generation button.
  Widget aiGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: (isGenerating || isSending)
            ? null
            : generateAiMessage,
        icon: isGenerating
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF172B3A),
          ),
        )
            : const Icon(
          Icons.auto_awesome,
          size: 19,
        ),
        label: Text(
          isGenerating
              ? 'Generating with Gemini...'
              : 'Generate with AI',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF172B3A),
          side: const BorderSide(
            color: Color(0xFF172B3A),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // Send request button.
  Widget actionButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: (isSending || isGenerating)
            ? null
            : sendRequest,
        icon: isSending
            ? const SizedBox(
          width: 19,
          height: 19,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Icon(
          Icons.send_outlined,
          size: 19,
        ),
        label: Text(
          isSending ? 'Sending...' : 'Send request',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF172B3A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF7B8794),
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
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Send Request',
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

                const SizedBox(height: 28),

                const Text(
                  'Connect with alumni',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Introduce yourself and explain why you would like to connect.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF52606D),
                  ),
                ),

                const SizedBox(height: 25),

                // Selected alumni information.
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
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFE6ECE2),
                        child: Text(
                          alumni.initials,
                          style: const TextStyle(
                            fontSize: 17,
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
                              alumni.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF172B3A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${alumni.job} at ${alumni.company}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF52606D),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${alumni.department} • Class of ${alumni.graduationYear}',
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

                const SizedBox(height: 24),

                const Text(
                  'Message',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 10),

                // Gemini AI button.
                aiGenerateButton(),

                const SizedBox(height: 12),

                TextField(
                  controller: messageController,
                  enabled: !isSending && !isGenerating,
                  maxLines: 6,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText:
                    'Hi ${alumni.name.split(' ').first}, I would like to connect with you...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9AA5B1),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(15),
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
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEDB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 19,
                        color: Color(0xFFB47B00),
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Generate a personalized message with AI, then review and edit it before sending.',
                          style: TextStyle(
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

                actionButton(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
