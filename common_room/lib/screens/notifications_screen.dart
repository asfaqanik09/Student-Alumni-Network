
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/alumni_data.dart';
import '../models/connection_data.dart';
import 'alumnus_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String userId;

  const NotificationsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const String apiUrl =
      'http:///common_room_api';

  bool aiNotificationRead = false;
  final Set<String> readConnectionNotifications = {};

  int unreadMessageCount = 0;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();

    ConnectionData.instance.addListener(updateScreen);

    loadUnreadMessages();

    refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => loadUnreadMessages(),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    ConnectionData.instance.removeListener(updateScreen);
    super.dispose();
  }

  void updateScreen() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> loadUnreadMessages() async {
    if (widget.userId.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse(
          '$apiUrl/get_unread_count.php'
              '?user_id=${Uri.encodeComponent(widget.userId)}',
        ),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          data['success'] == true) {
        if (!mounted) return;

        setState(() {
          unreadMessageCount =
              int.tryParse(
                data['unread_count'].toString(),
              ) ??
                  0;
        });
      }
    } catch (e) {
      // Keep the last displayed count if the server is unavailable.
    }
  }

  AlumniData? findAlumni(String name) {
    for (final alumni in alumniList) {
      if (alumni.name == name) {
        return alumni;
      }
    }

    return null;
  }

  void openAlumniProfile(String alumniName) {
    final alumni = findAlumni(alumniName);

    if (alumni == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Alumni information could not be found.',
          ),
        ),
      );
      return;
    }

    setState(() {
      readConnectionNotifications.add(alumniName);
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlumnusProfileScreen(
          alumni: alumni,
          studentId: widget.userId,
        ),
      ),
    );
  }

  void markAllAsRead() {
    setState(() {
      aiNotificationRead = true;

      for (final connection
      in ConnectionData.instance.allConnections) {
        if (connection.status != ConnectionStatus.none) {
          readConnectionNotifications.add(
            connection.alumniName,
          );
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Demo notifications marked as read.',
        ),
      ),
    );
  }

  String notificationTitle(
      AlumniConnection connection,
      ) {
    switch (connection.status) {
      case ConnectionStatus.pending:
        return 'Connection request pending';

      case ConnectionStatus.accepted:
        return 'Connection request accepted';

      case ConnectionStatus.declined:
        return 'Connection request update';

      case ConnectionStatus.none:
        return 'Connection update';
    }
  }

  String notificationMessage(
      AlumniConnection connection,
      ) {
    switch (connection.status) {
      case ConnectionStatus.pending:
        return 'Your connection request to '
            '${connection.alumniName} is waiting for a response.';

      case ConnectionStatus.accepted:
        return '${connection.alumniName} accepted your '
            'connection request. You can now start chatting.';

      case ConnectionStatus.declined:
        return '${connection.alumniName} declined your '
            'connection request.';

      case ConnectionStatus.none:
        return '';
    }
  }

  IconData notificationIcon(
      ConnectionStatus status,
      ) {
    switch (status) {
      case ConnectionStatus.pending:
        return Icons.schedule;

      case ConnectionStatus.accepted:
        return Icons.check_circle_outline;

      case ConnectionStatus.declined:
        return Icons.info_outline;

      case ConnectionStatus.none:
        return Icons.notifications_none;
    }
  }

  Color notificationIconColor(
      ConnectionStatus status,
      ) {
    switch (status) {
      case ConnectionStatus.pending:
        return const Color(0xFFB47B00);

      case ConnectionStatus.accepted:
        return const Color(0xFF365B47);

      case ConnectionStatus.declined:
        return const Color(0xFF7B8794);

      case ConnectionStatus.none:
        return const Color(0xFF7B8794);
    }
  }

  Color notificationIconBackground(
      ConnectionStatus status,
      ) {
    switch (status) {
      case ConnectionStatus.pending:
        return const Color(0xFFF3EEDB);

      case ConnectionStatus.accepted:
        return const Color(0xFFE6ECE2);

      case ConnectionStatus.declined:
        return const Color(0xFFF3F5F1);

      case ConnectionStatus.none:
        return const Color(0xFFF3F5F1);
    }
  }

  Widget connectionNotification(
      AlumniConnection connection,
      ) {
    final bool isRead =
    readConnectionNotifications.contains(
      connection.alumniName,
    );

    return InkWell(
      onTap: () {
        openAlumniProfile(connection.alumniName);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isRead
              ? Colors.white
              : const Color(0xFFF8F9F7),
          border: Border.all(
            color: const Color(0xFFE1E5DF),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: notificationIconBackground(
                  connection.status,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                notificationIcon(connection.status),
                size: 21,
                color: notificationIconColor(
                  connection.status,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notificationTitle(connection),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF172B3A),
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFB47B00),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notificationMessage(connection),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF52606D),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Tap to view profile',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7B8794),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget aiMatchNotification() {
    return InkWell(
      onTap: () {
        setState(() {
          aiNotificationRead = true;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlumnusProfileScreen(
              alumni: alumniList[0],
              studentId: widget.userId,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: aiNotificationRead
              ? Colors.white
              : const Color(0xFFF8F9F7),
          border: Border.all(
            color: const Color(0xFFE1E5DF),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: const BoxDecoration(
                color: Color(0xFFF3EEDB),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 21,
                color: Color(0xFFB47B00),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'New AI match',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF172B3A),
                          ),
                        ),
                      ),
                      if (!aiNotificationRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFB47B00),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${alumniList[0].name} is a '
                        '${alumniList[0].matchPercentage}% match '
                        'for your profile.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF52606D),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Tap to view profile',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7B8794),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget messageNotification() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: unreadMessageCount > 0
            ? const Color(0xFFF8F9F7)
            : Colors.white,
        border: Border.all(
          color: const Color(0xFFE1E5DF),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: const BoxDecoration(
              color: Color(0xFFE6ECE2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 21,
              color: Color(0xFF365B47),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unread messages',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  unreadMessageCount == 0
                      ? 'You have no unread messages.'
                      : 'You have $unreadMessageCount unread '
                      'message${unreadMessageCount == 1 ? '' : 's'}. '
                      'Open your accepted conversations to read them.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF52606D),
                  ),
                ),
              ],
            ),
          ),
          if (unreadMessageCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EEDB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                unreadMessageCount > 99
                    ? '99+'
                    : '$unreadMessageCount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8A6500),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget emptyConnectionMessage() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.notifications_none,
            color: Color(0xFF9AA5B1),
          ),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Your connection request updates will appear here.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF7B8794),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connections =
    ConnectionData.instance.allConnections
        .where(
          (connection) =>
      connection.status != ConnectionStatus.none,
    )
        .toList();

    final int unreadConnections =
        connections.where((connection) {
          return !readConnectionNotifications.contains(
            connection.alumniName,
          );
        }).length;

    final int unreadCount =
        unreadConnections +
            (aiNotificationRead ? 0 : 1) +
            unreadMessageCount;

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
                        'Notifications',
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your updates',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172B3A),
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EEDB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$unreadCount new',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8A6500),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Stay updated with your connections and matches.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF52606D),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: unreadCount == 0
                        ? null
                        : markAllAsRead,
                    icon: const Icon(
                      Icons.done_all,
                      size: 17,
                    ),
                    label: const Text('Mark demo updates as read'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF172B3A),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(height: 11),
                messageNotification(),
                const SizedBox(height: 18),
                const Text(
                  'Connections',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(height: 11),
                if (connections.isEmpty)
                  emptyConnectionMessage()
                else
                  for (final connection in connections)
                    connectionNotification(connection),
                const SizedBox(height: 18),
                const Text(
                  'Matches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(height: 11),
                aiMatchNotification(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
