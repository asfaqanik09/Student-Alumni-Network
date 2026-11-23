
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alumni_data.dart';
import 'ai_matches_screen.dart';
import 'alumnus_profile_screen.dart';
import 'notifications_screen.dart';
import 'role_selection_screen.dart';
import 'student_profile_screen.dart';
import 'login_screen.dart';
import 'roadmaps/student_roadmaps_screen.dart';
import 'student_seminars_screen.dart';

class SearchAlumniScreen extends StatefulWidget {
  final String userId;

  const SearchAlumniScreen({
    super.key,
    required this.userId,
  });

  @override
  State<SearchAlumniScreen> createState() =>
      _SearchAlumniScreenState();
}

class _SearchAlumniScreenState extends State<SearchAlumniScreen> {
  final TextEditingController searchController =
  TextEditingController();

  static const String alumniApiUrl =
      'http://172.20.10.3/common_room_api/get_alumni.php';

  List<AlumniData> alumni = [];

  bool isLoading = true;
  String? errorMessage;

  String selectedDepartment = 'All industries';
  String selectedYear = 'All years';

  @override
  void initState() {
    super.initState();
    loadAlumni();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('user_email');
    await prefs.remove('auth_token');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(),
      ),
          (route) => false,
    );
  }

  void openMyProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentProfileScreen(
          userId: widget.userId,
        ),
      ),
    );
  }

  void openCareerRoadmaps() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StudentRoadmapsScreen(),
      ),
    );
  }

  // Open the existing student seminar screen.
  void openUpcomingSeminars() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StudentSeminarsScreen(),
      ),
    );
  }

  // Load alumni using the authenticated login token.
  Future<void> loadAlumni() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      // Step 1: Retrieve the saved login token.
      final prefs = await SharedPreferences.getInstance();

      final String? token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        throw Exception(
          'Login session not found. Please log in again.',
        );
      }

      // Step 2: Create the API URL.
      final uri = Uri.parse(alumniApiUrl);

      // Step 3: Send the token in the Authorization header.
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      // Step 4: Decode the PHP response.
      final Map<String, dynamic> result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 401) {
        throw Exception(
          'Your login session has expired. Please log in again.',
        );
      }

      if (response.statusCode == 403) {
        throw Exception(
          'You are not authorized to view alumni.',
        );
      }

      if (response.statusCode == 200 &&
          result['success'] == true) {
        final List<dynamic> alumniData =
            result['alumni'] as List<dynamic>? ?? [];

        final List<AlumniData> loadedAlumni =
        alumniData.map((item) {
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

          final List<String> initialsParts = name
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .toList();

          String initials = '';

          if (initialsParts.isNotEmpty) {
            initials = initialsParts.first[0].toUpperCase();

            if (initialsParts.length > 1) {
              initials += initialsParts.last[0].toUpperCase();
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
            matchPercentage: 0,
            matchReason:
            'This alumni profile is available based on their professional experience.',
            about: bio.isEmpty
                ? 'No biography has been added yet.'
                : bio,
            canHelpWith: helpItems,
          );
        }).toList();

        if (!mounted) return;

        setState(() {
          alumni = loadedAlumni;
          isLoading = false;
        });
      } else {
        throw Exception(
          result['message']?.toString() ??
              'Could not retrieve alumni.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
        'Could not load alumni. Please check your connection and try again.';
      });

      debugPrint('Load alumni error: $e');
    }
  }

  void switchRole() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => RoleSelectionScreen(
          userId: widget.userId,
        ),
      ),
          (route) => false,
    );
  }

  void openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(
          userId: widget.userId,
        ),
      ),
    );
  }

  void openAiMatches() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiMatchesScreen(
          studentId: widget.userId,
        ),
      ),
    );
  }

  void openProfile(AlumniData person) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlumnusProfileScreen(
          alumni: person,
          studentId: widget.userId,
        ),
      ),
    );
  }

  List<String> get availableIndustries {
    final industries = alumni
        .map((person) => person.department)
        .where((industry) => industry.trim().isNotEmpty)
        .toSet()
        .toList();

    industries.sort();

    return ['All industries', ...industries];
  }

  List<String> get availableYears {
    final years = alumni
        .map((person) => person.graduationYear)
        .where((year) => year.trim().isNotEmpty)
        .toSet()
        .toList();

    years.sort((a, b) => b.compareTo(a));

    return ['All years', ...years];
  }

  List<AlumniData> get filteredAlumni {
    final query =
    searchController.text.trim().toLowerCase();

    return alumni.where((person) {
      final matchesSearch =
          query.isEmpty ||
              person.name.toLowerCase().contains(query) ||
              person.job.toLowerCase().contains(query) ||
              person.company.toLowerCase().contains(query) ||
              person.department.toLowerCase().contains(query);

      final matchesIndustry =
          selectedDepartment == 'All industries' ||
              person.department == selectedDepartment;

      final matchesYear =
          selectedYear == 'All years' ||
              person.graduationYear == selectedYear;

      return matchesSearch && matchesIndustry && matchesYear;
    }).toList();
  }

  Widget alumniCard(AlumniData person) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE1E5DF),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFE6ECE2),
                child: Text(
                  person.initials,
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
                      person.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      person.job,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF52606D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      person.company,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF52606D),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${person.department} • Class of ${person.graduationYear}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7B8794),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF9AA5B1),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () {
                openProfile(person);
              },
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

  Widget emptyResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 35,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_off,
            size: 35,
            color: Color(0xFF9AA5B1),
          ),
          SizedBox(height: 10),
          Text(
            'No alumni found',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF172B3A),
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Try changing your search or filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF7B8794),
            ),
          ),
        ],
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
            onPressed: loadAlumni,
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

  @override
  Widget build(BuildContext context) {
    final results = filteredAlumni;

    final industries = availableIndustries;
    final years = availableYears;

    if (!industries.contains(selectedDepartment)) {
      selectedDepartment = 'All industries';
    }

    if (!years.contains(selectedYear)) {
      selectedYear = 'All years';
    }

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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find Alumni',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF172B3A),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Connect with alumni who can guide you.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF52606D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: openNotifications,
                      icon: const Icon(
                        Icons.notifications_none,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: openMyProfile,
                          icon: const Icon(
                            Icons.person_outline,
                            size: 19,
                          ),
                          label: const Text(
                            'My Profile',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                            const Color(0xFF172B3A),
                            side: const BorderSide(
                              color: Color(0xFFD3D8CF),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: switchRole,
                          icon: const Icon(
                            Icons.swap_horiz,
                            size: 19,
                          ),
                          label: const Text(
                            'Switch Role',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                            const Color(0xFF172B3A),
                            side: const BorderSide(
                              color: Color(0xFFD3D8CF),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Career Roadmaps button.
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: openCareerRoadmaps,
                    icon: const Icon(
                      Icons.route_outlined,
                      size: 20,
                    ),
                    label: const Text(
                      'Career Roadmaps',
                      style: TextStyle(
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

                const SizedBox(height: 12),

                // Upcoming Seminars button.
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: openUpcomingSeminars,
                    icon: const Icon(
                      Icons.event_note_outlined,
                      size: 20,
                    ),
                    label: const Text(
                      'Upcoming Seminars',
                      style: TextStyle(
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

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: logout,
                    icon: const Icon(
                      Icons.logout,
                      size: 18,
                    ),
                    label: const Text('Logout'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF52606D),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: searchController,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name, job or company',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9AA5B1),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF7B8794),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F9F7),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFE1E5DF),
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

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedDepartment,
                        decoration: InputDecoration(
                          contentPadding:
                          const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: const BorderSide(
                              color: Color(0xFFD3D8CF),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: const BorderSide(
                              color: Color(0xFF172B3A),
                            ),
                          ),
                        ),
                        isExpanded: true,
                        items: industries.map((industry) {
                          return DropdownMenuItem<String>(
                            value: industry,
                            child: Text(
                              industry,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedDepartment = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedYear,
                        decoration: InputDecoration(
                          contentPadding:
                          const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: const BorderSide(
                              color: Color(0xFFD3D8CF),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: const BorderSide(
                              color: Color(0xFF172B3A),
                            ),
                          ),
                        ),
                        isExpanded: true,
                        items: years.map((year) {
                          return DropdownMenuItem<String>(
                            value: year,
                            child: Text(year),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedYear = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEDB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFFB47B00),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI recommended matches',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF172B3A),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'See alumni matched to your goals.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF52606D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: openAiMatches,
                        child: const Text(
                          'See matches',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF172B3A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                Row(
                  children: [
                    const Text(
                      'Alumni',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      isLoading
                          ? 'Loading...'
                          : '${results.length} found',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7B8794),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(35),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (errorMessage != null)
                  errorDisplay()
                else if (results.isEmpty)
                    emptyResults()
                  else
                    for (final person in results)
                      alumniCard(person),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
