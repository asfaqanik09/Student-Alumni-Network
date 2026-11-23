
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'student_profile_screen.dart';
import 'alumni_profile_setup_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String userId;

  const RoleSelectionScreen({
    super.key,
    required this.userId,
  });

  @override
  State<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool isLoading = false;

  static const String updateRoleUrl =
      'http://172.20.10.3/common_room_api/update_role.php';

  Future<void> selectRole(String role) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Retrieve the authentication token saved during login.
      final token = prefs.getString('auth_token') ?? '';

      if (token.isEmpty) {
        showMessage('Your session has expired. Please log in again.');
        return;
      }

      final response = await http.post(
        Uri.parse(updateRoleUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'role': role,
        }),
      ).timeout(const Duration(seconds: 20));

      final Map<String, dynamic> result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {

        // Save the selected role locally.
        await prefs.setString('user_id', widget.userId);
        await prefs.setString('user_role', role);

        if (!mounted) return;

        if (role == 'student') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => StudentProfileScreen(
                userId: widget.userId,
              ),
            ),
                (route) => false,
          );
        } else if (role == 'alumni') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => AlumniProfileSetupScreen(
                userId: widget.userId,
              ),
            ),
                (route) => false,
          );
        }
      } else {
        showMessage(
          result['message']?.toString() ??
              'Could not save your role.',
        );
      }
    } catch (e) {
      debugPrint('Role selection error: $e');

      showMessage(
        'Could not connect to the server. Check XAMPP.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void openAdmin() {
    showMessage(
      'Admin access is restricted to authorized accounts.',
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget roleCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE1E5DF),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6ECE2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 25,
                  color: const Color(0xFF172B3A),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF52606D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 17,
                color: Color(0xFF7B8794),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Choose your role',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select how you want to use Common Room',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF52606D),
                ),
              ),
              const SizedBox(height: 30),
              roleCard(
                icon: Icons.school_outlined,
                title: 'Student',
                description:
                'Find alumni, get career guidance and build professional connections.',
                onTap: () => selectRole('student'),
              ),
              roleCard(
                icon: Icons.work_outline,
                title: 'Alumni',
                description:
                'Guide students, receive connection requests and share your experience.',
                onTap: () => selectRole('alumni'),
              ),
              roleCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin',
                description:
                'Manage users, alumni verification and community activity.',
                onTap: openAdmin,
              ),
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                ),
              const Spacer(),
              Center(
                child: TextButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 18,
                  ),
                  label: const Text('Back'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF52606D),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
