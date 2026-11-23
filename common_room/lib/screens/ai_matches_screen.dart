
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alumni_data.dart';
import 'alumnus_profile_screen.dart';

class AiMatchesScreen extends StatefulWidget {
  final String studentId;

  const AiMatchesScreen({
    super.key,
    required this.studentId,
  });

  @override
  State<AiMatchesScreen> createState() =>
      _AiMatchesScreenState();
}

class _AiMatchesScreenState extends State<AiMatchesScreen> {
  static const String apiUrl =
      'http://172.20.10.3/common_room_api/get_ai_matches.php';

  List<AlumniData> matches = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadAiMatches();
  }

  Future<void> loadAiMatches() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final String token =
          prefs.getString('auth_token') ?? '';

      if (token.isEmpty) {
        throw Exception(
          'Your login session was not found. Please log in again.',
        );
      }

      final response = await http
          .get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      )
          .timeout(const Duration(seconds: 75));

      final Map<String, dynamic> result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        final List<dynamic> data =
            result['matches'] as List<dynamic>? ?? [];

        final List<AlumniData> loadedMatches =
        data.map((item) {
          final Map<String, dynamic> person =
          item as Map<String, dynamic>;

          final String name =
              person['name']?.toString() ?? 'Unknown Alumni';

          final String job =
              person['current_job']?.toString() ?? '';

          final String company =
              person['company']?.toString() ?? '';

          final String industry =
              person['industry']?.toString() ?? 'Other';

          final String graduationYear =
              person['graduation_year']?.toString() ?? '';

          final String bio =
              person['bio']?.toString() ?? '';

          final String helpText =
              person['help_text']?.toString() ?? '';

          final List<String> helpItems = helpText
              .split(RegExp(r'[,;\n]'))
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();

          final List<String> nameParts = name
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .toList();

          String initials = '';

          if (nameParts.isNotEmpty) {
            initials = nameParts.first[0].toUpperCase();

            if (nameParts.length > 1) {
              initials += nameParts.last[0].toUpperCase();
            }
          }

          return AlumniData(
            userId: person['user_id']?.toString() ?? '',
            name: name,
            initials: initials,
            job: job,
            company: company,
            department: industry,
            graduationYear: graduationYear,
            matchPercentage:
            (person['match_percentage'] as num?)?.toInt() ?? 0,
            matchReason:
            person['match_reason']?.toString() ??
                'Recommended based on your profile.',
            about: bio.isEmpty
                ? 'No biography has been added yet.'
                : bio,
            canHelpWith: helpItems,
          );
        }).toList();

        if (!mounted) return;

        setState(() {
          matches = loadedMatches;
          isLoading = false;
        });
      } else {
        throw Exception(
          result['message']?.toString() ??
              'Could not generate AI matches.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void openProfile(AlumniData alumni) {
    if (alumni.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alumni profile ID is missing.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlumnusProfileScreen(
          alumni: alumni,
          studentId: widget.studentId,
        ),
      ),
    );
  }

  Widget matchCard(AlumniData alumni) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE1E5DF),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      alumni.job,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF52606D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alumni.company,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF52606D),
                      ),
                    ),
                    const SizedBox(height: 5),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEDB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Color(0xFFB47B00),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${alumni.matchPercentage}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8A6500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9F7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 17,
                  color: Color(0xFFB47B00),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alumni.matchReason,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF52606D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => openProfile(alumni),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF172B3A),
                side: const BorderSide(
                  color: Color(0xFFD3D8CF),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Text(
                'View profile',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget loadingDisplay() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            CircularProgressIndicator(
              color: Color(0xFF172B3A),
            ),
            SizedBox(height: 18),
            Text(
              'Gemini is finding your best alumni matches...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF52606D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget errorDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 35,
            color: Color(0xFF7B8794),
          ),
          const SizedBox(height: 12),
          Text(
            errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF52606D),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: loadAiMatches,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF172B3A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget emptyDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 38,
            color: Color(0xFF7B8794),
          ),
          SizedBox(height: 12),
          Text(
            'No mentor matches found',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF172B3A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'There are currently no alumni available for mentoring.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF52606D),
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
                        'AI Matches',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172B3A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: isLoading ? null : loadAiMatches,
                      icon: const Icon(
                        Icons.refresh,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 25,
                      color: Color(0xFFB47B00),
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Best matches for you',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172B3A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                const Text(
                  'Gemini compares your department, interests and career goals with available alumni mentors.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF52606D),
                  ),
                ),
                const SizedBox(height: 25),
                if (isLoading)
                  loadingDisplay()
                else if (errorMessage != null)
                  errorDisplay()
                else if (matches.isEmpty)
                    emptyDisplay()
                  else ...[
                      Text(
                        '${matches.length} mentor matches found',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7B8794),
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final alumni in matches)
                        matchCard(alumni),
                    ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
