
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'verify_email_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController =
  TextEditingController();

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController passwordController =
  TextEditingController();

  bool isLoading = false;

  static const String registerUrl =
      'http://172.20.10.3/common_room_api/register.php';

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> createAccount() async {
    final String name = nameController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showMessage('Please fill in all fields.');
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(email)) {
      showMessage('Please enter a valid email address.');
      return;
    }

    if (password.length < 8) {
      showMessage(
        'Password must contain at least 8 characters.',
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http
          .post(
        Uri.parse(registerUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      )
          .timeout(const Duration(seconds: 20));

      final Map<String, dynamic> result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201 &&
          result['success'] == true) {
        final String userId =
        result['user_id'].toString();

        if (userId.isEmpty || userId == 'null') {
          showMessage(
            'Account created, but the user ID was not returned.',
          );
          return;
        }

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyEmailScreen(
              email: email,
              userId: userId,
            ),
          ),
        );
      } else {
        showMessage(
          result['message']?.toString() ??
              'Registration failed.',
        );
      }
    } catch (e) {
      showMessage(
        'Could not connect to the server. Check XAMPP and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void openLoginScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
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
                  'Join Common Room',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Free for every student and alumnus',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF52606D),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Full name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 7),

                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Anik Hemal',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFD3D8CF),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

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
                    hintText: 'At least 8 characters',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFD3D8CF),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : createAccount,
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
                      'Create account',
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
                        'Already have an account? ',
                        style: TextStyle(
                          color: Color(0xFF52606D),
                        ),
                      ),

                      GestureDetector(
                        onTap: openLoginScreen,
                        child: const Text(
                          'Log in',
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
