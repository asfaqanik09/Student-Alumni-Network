
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'student_roadmap_details_screen.dart';

class StudentRoadmapsScreen extends StatefulWidget {
  const StudentRoadmapsScreen({super.key});

  @override
  State<StudentRoadmapsScreen> createState() =>
      _StudentRoadmapsScreenState();
}

class _StudentRoadmapsScreenState
    extends State<StudentRoadmapsScreen> {
  static const String apiUrl =
      'http://172.20.10.3/common_room_api';

  List<Map<String, dynamic>> roadmaps = [];

  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadRoadmaps();
  }

  Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception(
        'Authentication token not found. Please log in again.',
      );
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> loadRoadmaps() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/get_published_roadmaps.php'),
        headers: await getHeaders(),
      ).timeout(const Duration(seconds: 20));

      final result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        final List<dynamic> data = result['roadmaps'] ?? [];

        if (!mounted) return;

        setState(() {
          roadmaps = data
              .map(
                (item) => Map<String, dynamic>.from(item),
          )
              .toList();

          isLoading = false;
        });
      } else {
        throw Exception(
          result['message'] ??
              'Could not load career roadmaps.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> openRoadmapDetails(
      Map<String, dynamic> roadmap,
      ) async {
    final roadmapId = int.tryParse(
      roadmap['id']?.toString() ?? '',
    );

    if (roadmapId == null || roadmapId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid roadmap ID.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            StudentRoadmapDetailsScreen(
              roadmapId: roadmapId,
            ),
      ),
    );
  }

  Widget roadmapCard(Map<String, dynamic> roadmap) {
    final title =
        roadmap['title']?.toString() ?? 'Untitled Roadmap';

    final description =
        roadmap['description']?.toString() ?? '';

    final icon = roadmap['icon']?.toString() ?? '💻';

    final totalSteps = int.tryParse(
      roadmap['total_steps']?.toString() ?? '',
    ) ??
        0;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F7),
        border: Border.all(
          color: const Color(0xFFE1E5DF),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => openRoadmapDetails(roadmap),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor:
                      const Color(0xFFE6ECE2),
                      child: Text(
                        icon.isEmpty ? '💻' : icon,
                        style: const TextStyle(fontSize: 23),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172B3A),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Color(0xFF52606D),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF52606D),
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(
                      Icons.menu_book_outlined,
                      size: 17,
                      color: Color(0xFF52606D),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$totalSteps learning steps',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF52606D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Published',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(
                  height: 1,
                  color: Color(0xFFE1E5DF),
                ),
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View Roadmap',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(
                      Icons.arrow_forward,
                      size: 15,
                      color: Color(0xFF172B3A),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget emptyRoadmaps() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 130),
        Icon(
          Icons.school_outlined,
          size: 55,
          color: Color(0xFF9AA5B1),
        ),
        SizedBox(height: 15),
        Center(
          child: Text(
            'No career roadmaps available yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF172B3A),
            ),
          ),
        ),
        SizedBox(height: 7),
        Center(
          child: Text(
            'Published career roadmaps will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF7B8794),
            ),
          ),
        ),
      ],
    );
  }

  Widget errorDisplay() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.cloud_off_outlined,
          size: 45,
          color: Color(0xFF7B8794),
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF52606D),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Center(
          child: ElevatedButton.icon(
            onPressed: loadRoadmaps,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172B3A),
        title: const Text(
          'Career Roadmaps',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadRoadmaps,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh roadmaps',
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : errorMessage.isNotEmpty
            ? RefreshIndicator(
          onRefresh: loadRoadmaps,
          child: errorDisplay(),
        )
            : RefreshIndicator(
          onRefresh: loadRoadmaps,
          child: roadmaps.isEmpty
              ? emptyRoadmaps()
              : ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Explore Your Career Path',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a career roadmap and start '
                    'building your future step by step.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF52606D),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${roadmaps.length} career roadmaps available',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 13),
              ...roadmaps.map(roadmapCard),
            ],
          ),
        ),
      ),
    );
  }
}
