
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alumni_data.dart';

class ChatScreen extends StatefulWidget {
  final AlumniData alumni;
  final String studentId;
  final bool isAlumni;

  const ChatScreen({
    super.key,
    required this.alumni,
    required this.studentId,
    this.isAlumni = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const String apiUrl =
      'http://172.20.10.3/common_room_api';

  final TextEditingController messageController =
  TextEditingController();

  final ScrollController scrollController =
  ScrollController();

  List<Map<String, dynamic>> messages = [];
  List<String> replySuggestions = [];

  Timer? refreshTimer;

  bool isLoading = true;
  bool isSending = false;
  bool isGeneratingReplies = false;
  bool canChat = false;

  int? requestId;
  String errorMessage = '';

  String get currentUserId {
    return widget.isAlumni
        ? widget.alumni.userId
        : widget.studentId;
  }

  @override
  void initState() {
    super.initState();
    checkConnectionStatus();
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // Retrieve the existing login token.
  Future<Map<String, String>> getAuthHeaders({
    bool includeJsonContentType = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception(
        'Authentication token not found. Please log in again.',
      );
    }

    return {
      if (includeJsonContentType)
        'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Check whether the mentorship connection is accepted.
  Future<void> checkConnectionStatus() async {
    if (widget.studentId.isEmpty ||
        widget.alumni.userId.isEmpty) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Student or alumni ID is missing.';
      });
      return;
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
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data['success'] == true) {
        final status =
            data['status']?.toString() ?? 'none';

        final id = int.tryParse(
          data['request_id']?.toString() ?? '',
        );

        setState(() {
          canChat = status == 'accepted';
          requestId = id;
          isLoading = false;
          errorMessage = '';
        });

        if (canChat && requestId != null) {
          await loadMessages();

          refreshTimer?.cancel();

          refreshTimer = Timer.periodic(
            const Duration(seconds: 5),
                (_) => loadMessages(),
          );
        } else {
          refreshTimer?.cancel();
        }
      } else {
        setState(() {
          errorMessage =
              data['message']?.toString() ??
                  'Could not check connection status.';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage =
        e.toString().contains('Authentication token')
            ? 'Your login session was not found. Please log in again.'
            : 'Could not connect to the server.';
        isLoading = false;
      });
    }
  }

  // Load messages using the authenticated user's token.
  Future<void> loadMessages() async {
    if (requestId == null || currentUserId.isEmpty) {
      return;
    }

    try {
      final headers = await getAuthHeaders();

      final response = await http.get(
        Uri.parse(
          '$apiUrl/get_messages.php?request_id=$requestId',
        ),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data['success'] == true) {
        final List<dynamic> result =
            data['messages'] ?? [];

        setState(() {
          messages = result.map((item) {
            return Map<String, dynamic>.from(item);
          }).toList();
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scrollController.hasClients) {
            scrollController.jumpTo(
              scrollController.position.maxScrollExtent,
            );
          }
        });
      } else if (response.statusCode == 401) {
        setState(() {
          errorMessage =
          'Your session has expired. Please log in again.';
        });
      }
    } catch (e) {
      // Keep existing messages visible if background refresh fails.
    }
  }

  // Generate up to three AI reply suggestions.
  Future<void> generateReplySuggestions() async {
    if (!canChat ||
        requestId == null ||
        messages.isEmpty ||
        isGeneratingReplies) {
      return;
    }

    setState(() {
      isGeneratingReplies = true;
      replySuggestions.clear();
    });

    try {
      final headers = await getAuthHeaders(
        includeJsonContentType: true,
      );

      final response = await http
          .post(
        Uri.parse('$apiUrl/generate_chat_replies.php'),
        headers: headers,
        body: jsonEncode({
          'request_id': requestId,
        }),
      )
          .timeout(const Duration(seconds: 70));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data['success'] == true) {
        final List<dynamic> result =
            data['suggestions'] ?? [];

        final suggestions = result
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .take(3)
            .toList();

        setState(() {
          replySuggestions = suggestions;
        });

        if (suggestions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No reply suggestions were generated.',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ??
                  'Could not generate reply suggestions.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      final message =
      e.toString().contains('Authentication token')
          ? 'Your login session was not found. Please log in again.'
          : 'AI suggestions are temporarily unavailable.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingReplies = false;
        });
      }
    }
  }

  // Select a suggestion and place it in the message box.
  void selectReplySuggestion(String suggestion) {
    messageController.text = suggestion;
    messageController.selection =
        TextSelection.fromPosition(
          TextPosition(
            offset: messageController.text.length,
          ),
        );

    setState(() {
      replySuggestions.clear();
    });
  }

  // Send a message. PHP identifies the sender from the token.
  Future<void> sendMessage() async {
    if (!canChat || requestId == null || isSending) {
      return;
    }

    final text = messageController.text.trim();

    if (text.isEmpty) return;

    setState(() {
      isSending = true;
      replySuggestions.clear();
    });

    try {
      final headers = await getAuthHeaders(
        includeJsonContentType: true,
      );

      final response = await http.post(
        Uri.parse('$apiUrl/send_message.php'),
        headers: headers,
        body: jsonEncode({
          'request_id': requestId,
          'message_text': text,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data['success'] == true) {
        messageController.clear();

        FocusScope.of(context).unfocus();

        await loadMessages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ??
                  'Message could not be sent.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      final message =
      e.toString().contains('Authentication token')
          ? 'Your login session was not found. Please log in again.'
          : 'Could not connect to the server.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  // Display the AI review attached to a received message.
  Widget aiReviewInfo(Map<String, dynamic> message) {
    final status =
        message['ai_review_status']?.toString() ?? 'pending';

    if (status != 'reviewed') {
      return const SizedBox.shrink();
    }

    final score = int.tryParse(
      message['ai_review_score']?.toString() ?? '',
    );

    final reason =
        message['ai_review_reason']?.toString().trim() ?? '';

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      margin: const EdgeInsets.only(top: 5, bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFEAD9AE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 15,
                color: Color(0xFF765B20),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'AI message review',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF765B20),
                  ),
                ),
              ),
              if (score != null)
                Text(
                  'Concern: $score/100',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF765B20),
                  ),
                ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              reason,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Color(0xFF665A40),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget messageBubble({
    required String text,
    required bool isMe,
    required Map<String, dynamic> message,
  }) {
    return Align(
      alignment:
      isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFF172B3A)
                  : const Color(0xFFF3F5F1),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft:
                Radius.circular(isMe ? 14 : 3),
                bottomRight:
                Radius.circular(isMe ? 3 : 14),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isMe
                    ? Colors.white
                    : const Color(0xFF172B3A),
              ),
            ),
          ),

          // Show the review to the recipient.
          if (!isMe) aiReviewInfo(message),
        ],
      ),
    );
  }

  // Display the AI-generated reply suggestions.
  Widget replySuggestionsArea() {
    if (replySuggestions.isEmpty &&
        !isGeneratingReplies) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      color: const Color(0xFFF8F9F7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 17,
                color: Color(0xFF52606D),
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'AI reply suggestions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Close suggestions',
                onPressed: () {
                  setState(() {
                    replySuggestions.clear();
                  });
                },
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: Color(0xFF7B8794),
                ),
              ),
            ],
          ),
          if (isGeneratingReplies)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Generating replies...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF52606D),
                    ),
                  ),
                ],
              ),
            )
          else
            ...replySuggestions.map((suggestion) {
              return InkWell(
                onTap: () =>
                    selectReplySuggestion(suggestion),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFD3D8CF),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          suggestion,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xFF172B3A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.north_west,
                        size: 16,
                        color: Color(0xFF52606D),
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (!isGeneratingReplies)
            const Text(
              'Tap a suggestion to edit it before sending.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF7B8794),
              ),
            ),
        ],
      ),
    );
  }

  Widget lockedChat() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 65,
                color: Color(0xFF7B8794),
              ),
              const SizedBox(height: 20),
              const Text(
                'Chat is locked',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '${widget.alumni.name} must accept your connection request before you can start chatting.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF52606D),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget chatArea() {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
              child: Text(
                'You are connected! Start your conversation.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7B8794),
                  fontSize: 14,
                ),
              ),
            )
                : ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];

                final isMe =
                    message['sender_id'].toString() ==
                        currentUserId;

                return messageBubble(
                  text: message['message_text']
                      ?.toString() ??
                      '',
                  isMe: isMe,
                  message: message,
                );
              },
            ),
          ),

          // AI reply suggestions appear above the message composer.
          replySuggestionsArea(),

          Container(
            padding: const EdgeInsets.fromLTRB(
              12, 10, 16, 14,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Color(0xFFE1E5DF),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // AI suggestion button.
                  IconButton(
                    tooltip: 'Generate AI reply suggestions',
                    onPressed: isGeneratingReplies ||
                        messages.isEmpty
                        ? null
                        : generateReplySuggestions,
                    icon: isGeneratingReplies
                        ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF52606D),
                      size: 23,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9AA5B1),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F9F7),
                        contentPadding:
                        const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFFE1E5DF),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFF172B3A),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFF172B3A),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed:
                      isSending ? null : sendMessage,
                      icon: isSending
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE1E5DF),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF172B3A),
                    ),
                  ),
                  CircleAvatar(
                    radius: 21,
                    backgroundColor:
                    const Color(0xFFE6ECE2),
                    child: Text(
                      widget.alumni.initials,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.alumni.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF172B3A),
                          ),
                        ),
                        Text(
                          canChat
                              ? 'Connected'
                              : 'Not connected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: canChat
                                ? const Color(0xFF365B47)
                                : const Color(0xFF7B8794),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canChat)
                    const Icon(
                      Icons.check_circle,
                      size: 20,
                      color: Color(0xFF365B47),
                    ),
                ],
              ),
            ),
            if (isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (errorMessage.isNotEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: checkConnectionStatus,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (canChat && requestId != null)
                chatArea()
              else
                lockedChat(),
          ],
        ),
      ),
    );
  }
}
