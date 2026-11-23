
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'role_selection_screen.dart';
import 'search_alumni_screen.dart';
import 'incoming_requests_screen.dart';
import 'admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  static const String loginUrl =
      'http://172.20.10.3/common_room_api/login.php';

  static const String saveFcmTokenUrl =
      'http://172.20.10.3/common_room_api/save_fcm_token.php';

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Register the device's FCM token with the PHP backend.
  Future<void> saveFcmToken(String authToken) async {
    try {
      final messaging = FirebaseMessaging.instance;

      final String? fcmToken = await messaging.getToken();

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('FCM token is not available.');
        return;
      }

      final response = await http
          .post(
        Uri.parse(saveFcmTokenUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'fcm_token': fcmToken,
          'device_type': 'android',
        }),
      )
          .timeout(const Duration(seconds: 15));

      final result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        debugPrint('FCM token saved successfully.');
      } else {
        debugPrint(
          'FCM token save failed: ${result['message']}',
        );
      }
    } catch (e) {
      // Notification registration failure must not block login.
      debugPrint('FCM token registration error: $e');
    }
  }

  Future<void> login() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter your email and password.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http
          .post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      )
          .timeout(const Duration(seconds: 20));

      final Map<String, dynamic> result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        final user = result['user'] as Map<String, dynamic>;

        final String userId = user['id'].toString();
        final String role =
            user['role']?.toString().toLowerCase() ?? 'pending';
        final String userEmail =
            user['email']?.toString() ?? email;

        // Get the authentication token from PHP.
        final String token = result['token']?.toString() ?? '';

        if (token.isEmpty) {
          showMessage(
            'Login token was not received. Please try again.',
          );
          return;
        }

        // Save user information and authentication token.
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('user_id', userId);
        await prefs.setString('user_role', role);
        await prefs.setString('user_email', userEmail);
        await prefs.setString('auth_token', token);

        // Register this device with Firebase and PHP.
        await saveFcmToken(token);

        if (!mounted) return;

        // Navigate according to the user's role.
        if (role == 'admin') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AdminDashboardScreen(email: userEmail),
            ),
                (route) => false,
          );
        } else if (role == 'student') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SearchAlumniScreen(userId: userId),
            ),
                (route) => false,
          );
        } else if (role == 'alumni') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  IncomingRequestsScreen(userId: userId),
            ),
                (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RoleSelectionScreen(userId: userId),
            ),
                (route) => false,
          );
        }
      } else {
        showMessage(
          result['message']?.toString() ??
              'Login failed. Please try again.',
        );
      }
    } on http.ClientException {
      showMessage('Network error. Check your Wi-Fi and XAMPP.');
    } catch (e) {
      showMessage(
        'Could not connect to the server. Check XAMPP and try again.',
      );
      debugPrint('Login error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

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
              horizontal: 28,
              vertical: 30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 15),
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sign in with your university email',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF52606D),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'University email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'you@university.edu',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
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
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Your password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
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
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF172B3A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Log in',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'New here? ',
                        style: TextStyle(
                          color: Color(0xFF52606D),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Create an account',
                          style: TextStyle(
                            color: Color(0xFFB47B00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
