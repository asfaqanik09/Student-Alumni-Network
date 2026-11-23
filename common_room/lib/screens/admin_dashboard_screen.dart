
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import 'admin_users_screen.dart';
import 'roadmaps/admin_roadmap_screen.dart';
import 'admin_seminars_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String email;

  const AdminDashboardScreen({
    super.key,
    this.email = '',
  });

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const String apiUrl =
      'http://172.20.10.3/common_room_api';

  bool isLoggingOut = false;
  bool isLoadingStats = true;
  String statsError = '';

  int students = 0;
  int alumni = 0;
  int connections = 0;
  int pending = 0;

  @override
  void initState() {
    super.initState();
    loadDashboardStats();
  }

  Future<void> loadDashboardStats() async {
    if (!mounted) return;

    setState(() {
      isLoadingStats = true;
      statsError = '';
    });

    try {
      final response = await http.get(
        Uri.parse(
          '$apiUrl/admin_dashboard_stats.php'
              '?email=${Uri.encodeComponent(widget.email)}',
        ),
      ).timeout(const Duration(seconds: 20));

      final Map<String, dynamic> result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        if (!mounted) return;

        setState(() {
          students = int.tryParse(
            result['students']?.toString() ?? '',
          ) ??
              0;
          alumni = int.tryParse(
            result['alumni']?.toString() ?? '',
          ) ??
              0;
          connections = int.tryParse(
            result['connections']?.toString() ?? '',
          ) ??
              0;
          pending = int.tryParse(
            result['pending']?.toString() ?? '',
          ) ??
              0;
          isLoadingStats = false;
        });
      } else {
        throw Exception(
          result['message'] ?? 'Could not load statistics.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingStats = false;
        statsError =
        'Could not load statistics. Tap refresh to try again.';
      });
    }
  }

  void openManageUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUsersScreen(
          adminEmail: widget.email,
        ),
      ),
    );
  }

  void openManageRoadmaps() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminRoadmapScreen(),
      ),
    );
  }

  void openManageSeminars() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminSeminarsScreen(),
      ),
    );
  }

  Future<void> logout() async {
    if (isLoggingOut) return;

    setState(() {
      isLoggingOut = true;
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('user_email');
    await prefs.remove('auth_token');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9F7),
          border: Border.all(
            color: const Color(0xFFE1E5DF),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFE6ECE2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: const Color(0xFF172B3A),
              ),
            ),
            const SizedBox(height: 13),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172B3A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF52606D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget managementCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE1E5DF),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),
        leading: Container(
          width: 45,
          height: 45,
          decoration: const BoxDecoration(
            color: Color(0xFFE6ECE2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 21,
            color: const Color(0xFF172B3A),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF172B3A),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF52606D),
            ),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Color(0xFF7B8794),
        ),
      ),
    );
  }

  void showTemporaryMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 25,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Dashboard',
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF172B3A),
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Manage the Common Room community',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF52606D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed:
                      isLoadingStats ? null : loadDashboardStats,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh statistics',
                    ),
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFF172B3A),
                      child: Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.email.isNotEmpty)
                  Text(
                    'Logged in as ${widget.email}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF52606D),
                    ),
                  ),
                const SizedBox(height: 28),
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(height: 13),
                if (isLoadingStats)
                  const Padding(
                    padding: EdgeInsets.all(25),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (statsError.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          statsError,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: loadDashboardStats,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                else ...[
                    Row(
                      children: [
                        statCard(
                          title: 'Students',
                          value: students.toString(),
                          icon: Icons.school_outlined,
                        ),
                        const SizedBox(width: 10),
                        statCard(
                          title: 'Alumni',
                          value: alumni.toString(),
                          icon: Icons.work_outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        statCard(
                          title: 'Connections',
                          value: connections.toString(),
                          icon: Icons.people_outline,
                        ),
                        const SizedBox(width: 10),
                        statCard(
                          title: 'Pending',
                          value: pending.toString(),
                          icon: Icons.pending_actions_outlined,
                        ),
                      ],
                    ),
                  ],
                const SizedBox(height: 30),
                const Text(
                  'Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(height: 13),
                managementCard(
                  icon: Icons.people_outline,
                  title: 'Manage users',
                  subtitle:
                  'View students, alumni and account information',
                  onTap: openManageUsers,
                ),
                managementCard(
                  icon: Icons.map_outlined,
                  title: 'Career Roadmaps',
                  subtitle:
                  'Create careers, learning steps and free resources',
                  onTap: openManageRoadmaps,
                ),
                managementCard(
                  icon: Icons.event_note_outlined,
                  title: 'Manage Seminars',
                  subtitle:
                  'Review, approve and reject alumni seminar proposals',
                  onTap: openManageSeminars,
                ),
                managementCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Verify alumni',
                  subtitle: 'Review and approve alumni profiles',
                  onTap: () {
                    showTemporaryMessage(
                      'Alumni verification is not implemented yet.',
                    );
                  },
                ),
                managementCard(
                  icon: Icons.flag_outlined,
                  title: 'Reports',
                  subtitle: 'Review reported users and content',
                  onTap: () {
                    showTemporaryMessage(
                      'Reports are not implemented yet.',
                    );
                  },
                ),
                managementCard(
                  icon: Icons.link,
                  title: 'Connections',
                  subtitle: 'Monitor connection activity',
                  onTap: () {
                    showTemporaryMessage(
                      'Connection management is not implemented yet.',
                    );
                  },
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: isLoggingOut ? null : logout,
                    icon: const Icon(
                      Icons.logout,
                      size: 19,
                    ),
                    label: Text(
                      isLoggingOut ? 'Logging out...' : 'Log out',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF172B3A),
                      side: const BorderSide(
                        color: Color(0xFFD3D8CF),
                      ),
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
      ),
    );
  }
}
