
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'search_alumni_screen.dart';
import 'login_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  final String userId;

  const StudentProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final TextEditingController departmentController =
  TextEditingController();

  final TextEditingController yearController =
  TextEditingController();

  final TextEditingController goalController =
  TextEditingController();

  bool isLoading = false;
  bool isFetching = true;
  bool profileExists = false;

  static const String apiUrl =
      'http://172.20.10.3/common_room_api';

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    departmentController.dispose();
    yearController.dispose();
    goalController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    try {
      final response = await http
          .get(
        Uri.parse(
          '$apiUrl/get_student_profile.php?user_id=${Uri.encodeComponent(widget.userId)}',
        ),
      )
          .timeout(const Duration(seconds: 20));

      final Map<String, dynamic> result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true &&
          result['exists'] == true) {
        final profile =
        result['profile'] as Map<String, dynamic>;

        if (!mounted) return;

        setState(() {
          profileExists = true;
          departmentController.text =
              profile['major']?.toString() ?? '';
          yearController.text =
              profile['grad_year_expected']?.toString() ?? '';
          goalController.text =
              profile['career_goal']?.toString() ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          'Could not load saved profile. Check your connection.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isFetching = false;
        });
      }
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('user_email');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(),
      ),
          (route) => false,
    );
  }

  Future<void> saveAndContinue() async {
    final String department =
    departmentController.text.trim();

    final String yearText =
    yearController.text.trim();

    final String careerGoal =
    goalController.text.trim();

    if (department.isEmpty ||
        yearText.isEmpty ||
        careerGoal.isEmpty) {
      showMessage('Please fill in all fields.');
      return;
    }

    final int? graduationYear = int.tryParse(yearText);

    if (graduationYear == null ||
        graduationYear < 2000 ||
        graduationYear > 2100) {
      showMessage(
        'Please enter a valid graduation year, such as 2028.',
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http
          .post(
        Uri.parse('$apiUrl/save_student_profile.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': widget.userId,
          'major': department,
          'grad_year_expected': graduationYear,
          'career_goal': careerGoal,
        }),
      )
          .timeout(const Duration(seconds: 20));

      final Map<String, dynamic> result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        if (!mounted) return;

        setState(() {
          profileExists = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student profile saved successfully!'),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SearchAlumniScreen(
              userId: widget.userId,
            ),
          ),
        );
      } else {
        showMessage(
          result['message']?.toString() ??
              'Could not save your profile.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isFetching
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: logout,
                    icon: const Icon(
                      Icons.logout,
                      size: 19,
                    ),
                    label: const Text('Logout'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                      const Color(0xFF52606D),
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  profileExists
                      ? 'My Student Profile'
                      : 'Tell us about you',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  profileExists
                      ? 'View and update your profile details'
                      : 'This helps us find the right alumni for you',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF52606D),
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'Department',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 7),

                TextField(
                  controller: departmentController,
                  decoration: InputDecoration(
                    hintText: 'Computer Science & Engineering',
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

                const SizedBox(height: 20),

                const Text(
                  'Expected graduation year',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 7),

                TextField(
                  controller: yearController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '2028',
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

                const SizedBox(height: 20),

                const Text(
                  'What do you need help with?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 7),

                TextField(
                  controller: goalController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                    'Example: Career advice, internship guidance, interview preparation...',
                    alignLabelWithHint: true,
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

                const SizedBox(height: 26),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                    isLoading ? null : saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(0xFF172B3A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(10),
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
                        : Text(
                      profileExists
                          ? 'Update profile'
                          : 'Save & continue',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
