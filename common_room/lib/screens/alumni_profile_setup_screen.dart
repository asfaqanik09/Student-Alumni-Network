
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'incoming_requests_screen.dart';
import 'login_screen.dart';

class AlumniProfileSetupScreen extends StatefulWidget {
  final String userId;

  const AlumniProfileSetupScreen({
    super.key,
    required this.userId,
  });

  @override
  State<AlumniProfileSetupScreen> createState() =>
      _AlumniProfileSetupScreenState();
}

class _AlumniProfileSetupScreenState
    extends State<AlumniProfileSetupScreen> {
  final TextEditingController graduationYearController =
  TextEditingController();

  final TextEditingController jobTitleController =
  TextEditingController();

  final TextEditingController companyController =
  TextEditingController();

  final TextEditingController industryController =
  TextEditingController();

  final TextEditingController helpController =
  TextEditingController();

  final TextEditingController bioController =
  TextEditingController();

  bool isLoading = false;
  bool isLoadingProfile = true;
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
    graduationYearController.dispose();
    jobTitleController.dispose();
    companyController.dispose();
    industryController.dispose();
    helpController.dispose();
    bioController.dispose();
    super.dispose();
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

  Future<void> loadProfile() async {
    setState(() {
      isLoadingProfile = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          '$apiUrl/get_alumni_profile.php'
              '?user_id=${Uri.encodeComponent(widget.userId)}',
        ),
      ).timeout(const Duration(seconds: 20));

      final result = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        if (result['exists'] == true) {
          final profile =
          Map<String, dynamic>.from(result['profile']);

          graduationYearController.text =
              profile['graduation_year']?.toString() ?? '';

          jobTitleController.text =
              profile['current_job']?.toString() ?? '';

          companyController.text =
              profile['company']?.toString() ?? '';

          industryController.text =
              profile['industry']?.toString() ?? '';

          helpController.text =
              profile['help_text']?.toString() ?? '';

          bioController.text =
              profile['bio']?.toString() ?? '';

          profileExists = true;
        } else {
          profileExists = false;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ??
                  'Could not load your profile.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load profile. Please check your connection.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> saveProfile() async {
    if (graduationYearController.text.trim().isEmpty ||
        jobTitleController.text.trim().isEmpty ||
        companyController.text.trim().isEmpty ||
        industryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required fields.'),
        ),
      );
      return;
    }

    final graduationYear =
    int.tryParse(graduationYearController.text.trim());

    if (graduationYear == null ||
        graduationYear < 1950 ||
        graduationYear > 2100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid graduation year.'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/save_alumni_profile.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': widget.userId,
          'graduation_year': graduationYear,
          'current_job': jobTitleController.text.trim(),
          'company': companyController.text.trim(),
          'industry': industryController.text.trim(),
          'help_text': helpController.text.trim(),
          'bio': bioController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 20));

      final result = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        profileExists = true;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alumni profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingRequestsScreen(
              userId: widget.userId,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ??
                  'Could not save your profile.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to connect to the server. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
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
    );
  }

  Widget fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF172B3A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoadingProfile
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
                      ? 'My Alumni Profile'
                      : 'Build your alumni profile',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  profileExists
                      ? 'View and update your professional information'
                      : 'Help students understand your experience',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF52606D),
                  ),
                ),

                const SizedBox(height: 28),

                fieldLabel('Graduation year'),
                const SizedBox(height: 7),
                TextField(
                  controller: graduationYearController,
                  keyboardType: TextInputType.number,
                  decoration: fieldDecoration('2022'),
                ),

                const SizedBox(height: 20),

                fieldLabel('Current job title'),
                const SizedBox(height: 7),
                TextField(
                  controller: jobTitleController,
                  decoration:
                  fieldDecoration('Software Engineer'),
                ),

                const SizedBox(height: 20),

                fieldLabel('Company'),
                const SizedBox(height: 7),
                TextField(
                  controller: companyController,
                  decoration: fieldDecoration('Google'),
                ),

                const SizedBox(height: 20),

                fieldLabel('Industry'),
                const SizedBox(height: 7),
                TextField(
                  controller: industryController,
                  decoration:
                  fieldDecoration('Technology'),
                ),

                const SizedBox(height: 20),

                fieldLabel(
                  'What can you help students with?',
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: helpController,
                  maxLines: 3,
                  decoration: fieldDecoration(
                    'Career advice, internships, interview preparation...',
                  ),
                ),

                const SizedBox(height: 20),

                fieldLabel('Short bio'),
                const SizedBox(height: 7),
                TextField(
                  controller: bioController,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: fieldDecoration(
                    'Tell students a little about your experience and career journey...',
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                    isLoading ? null : saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(0xFF172B3A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                      const Color(0xFF52606D),
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
                      child:
                      CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      profileExists
                          ? 'Update profile'
                          : 'Save profile',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
