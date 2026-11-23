
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StudentRoadmapDetailsScreen extends StatefulWidget {
  final int roadmapId;

  const StudentRoadmapDetailsScreen({
    super.key,
    required this.roadmapId,
  });

  @override
  State<StudentRoadmapDetailsScreen> createState() =>
      _StudentRoadmapDetailsScreenState();
}

class _StudentRoadmapDetailsScreenState
    extends State<StudentRoadmapDetailsScreen> {
  static const String apiUrl =
      'http://172.20.10.3/common_room_api';

  Map<String, dynamic>? roadmap;
  List<Map<String, dynamic>> steps = [];

  int totalSteps = 0;
  int completedSteps = 0;
  double progressPercentage = 0;

  bool isLoading = true;
  String errorMessage = '';
  final Set<int> updatingSteps = {};

  @override
  void initState() {
    super.initState();
    loadRoadmapDetails();
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

  bool parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().toLowerCase();
    return text == '1' || text == 'true';
  }

  Future<void> loadRoadmapDetails() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse(
          '$apiUrl/get_roadmap_details.php?roadmap_id=${widget.roadmapId}',
        ),
        headers: await getHeaders(),
      ).timeout(const Duration(seconds: 20));

      final result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        final roadmapData =
        Map<String, dynamic>.from(result['roadmap'] ?? {});

        final List<dynamic> stepData = result['steps'] ?? [];

        final parsedSteps = stepData.map((item) {
          final step = Map<String, dynamic>.from(item);

          step['id'] = int.tryParse(
            step['id']?.toString() ?? '',
          ) ??
              0;

          step['step_order'] = int.tryParse(
            step['step_order']?.toString() ?? '',
          ) ??
              0;

          step['is_completed'] = parseBool(
            step['is_completed'],
          );

          final List<dynamic> resourceData =
              step['resources'] ?? [];

          step['resources'] = resourceData
              .map(
                (resource) =>
            Map<String, dynamic>.from(resource),
          )
              .toList();

          return step;
        }).toList();

        if (!mounted) return;

        setState(() {
          roadmap = roadmapData;
          steps = parsedSteps;

          totalSteps = int.tryParse(
            result['total_steps']?.toString() ?? '',
          ) ??
              parsedSteps.length;

          completedSteps = int.tryParse(
            result['completed_steps']?.toString() ?? '',
          ) ??
              parsedSteps
                  .where((step) => step['is_completed'] == true)
                  .length;

          progressPercentage = double.tryParse(
            result['progress_percentage']?.toString() ?? '',
          ) ??
              0;

          isLoading = false;
        });
      } else {
        throw Exception(
          result['message'] ??
              'Could not load roadmap details.',
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

  Future<void> updateStepProgress(
      Map<String, dynamic> step,
      bool isCompleted,
      ) async {
    final stepId = int.tryParse(step['id'].toString()) ?? 0;

    if (stepId <= 0 || updatingSteps.contains(stepId)) {
      return;
    }

    setState(() {
      updatingSteps.add(stepId);
    });

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/update_roadmap_progress.php'),
        headers: await getHeaders(),
        body: jsonEncode({
          'step_id': stepId,
          'is_completed': isCompleted,
        }),
      ).timeout(const Duration(seconds: 20));

      final result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        if (!mounted) return;

        setState(() {
          step['is_completed'] = isCompleted;

          completedSteps = steps
              .where((item) => item['is_completed'] == true)
              .length;

          progressPercentage = totalSteps > 0
              ? (completedSteps / totalSteps) * 100
              : 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCompleted
                  ? 'Step marked as completed!'
                  : 'Step marked as incomplete.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception(
          result['message'] ??
              'Could not update your progress.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Progress update failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          updatingSteps.remove(stepId);
        });
      }
    }
  }

  Widget buildProgressSection() {
    final percentage = progressPercentage.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE1E5DF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 9,
              backgroundColor: const Color(0xFFE1E5DF),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF2E7D32),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$completedSteps of $totalSteps steps completed',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF52606D),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildResourceCard(Map<String, dynamic> resource) {
    final title =
        resource['title']?.toString() ?? 'Untitled resource';
    final type =
        resource['resource_type']?.toString() ?? 'other';
    final url = resource['url']?.toString() ?? '';
    final description =
        resource['description']?.toString() ?? '';

    IconData resourceIcon;

    switch (type.toLowerCase()) {
      case 'youtube':
        resourceIcon = Icons.play_circle_outline;
        break;
      case 'course':
        resourceIcon = Icons.school_outlined;
        break;
      case 'documentation':
        resourceIcon = Icons.menu_book_outlined;
        break;
      case 'project':
        resourceIcon = Icons.code;
        break;
      case 'tutorial':
        resourceIcon = Icons.video_library_outlined;
        break;
      default:
        resourceIcon = Icons.link;
    }

    return Container(
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE1E5DF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                resourceIcon,
                size: 20,
                color: const Color(0xFF52606D),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF52606D),
              ),
            ),
          ],
          if (url.isNotEmpty) ...[
            const SizedBox(height: 9),
            SelectableText(
              url,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1565C0),
                decoration: TextDecoration.underline,
              ),
            ),
          ],
          const SizedBox(height: 5),
          Text(
            type.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7B8794),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStepCard(
      Map<String, dynamic> step,
      int index,
      ) {
    final isCompleted = step['is_completed'] == true;
    final stepId = int.tryParse(step['id'].toString()) ?? 0;
    final isUpdating = updatingSteps.contains(stepId);

    final title =
        step['title']?.toString() ?? 'Untitled step';
    final description =
        step['description']?.toString() ?? '';

    final List<Map<String, dynamic>> resources =
    (step['resources'] as List<dynamic>? ?? [])
        .map(
          (item) => Map<String, dynamic>.from(item),
    )
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFFF1F8F1)
            : const Color(0xFFF8F9F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFFB7D9B8)
              : const Color(0xFFE1E5DF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: isCompleted
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFE6ECE2),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCompleted
                        ? Colors.white
                        : const Color(0xFF172B3A),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172B3A),
                    ),
                  ),
                ),
              ),
              if (isUpdating)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                Checkbox(
                  value: isCompleted,
                  activeColor: const Color(0xFF2E7D32),
                  onChanged: (value) {
                    if (value != null) {
                      updateStepProgress(step, value);
                    }
                  },
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF52606D),
              ),
            ),
          ],
          if (resources.isNotEmpty) ...[
            const SizedBox(height: 15),
            const Text(
              'Learning Resources',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172B3A),
              ),
            ),
            ...resources.map(buildResourceCard),
          ],
          if (isCompleted) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 15,
                  color: Color(0xFF2E7D32),
                ),
                SizedBox(width: 5),
                Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget buildErrorDisplay() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.cloud_off_outlined,
          size: 48,
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
            onPressed: loadRoadmapDetails,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = roadmap?['title']?.toString() ??
        'Career Roadmap';
    final description =
        roadmap?['description']?.toString() ?? '';
    final icon = roadmap?['icon']?.toString() ?? '💻';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172B3A),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadRoadmapDetails,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh roadmap',
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
          onRefresh: loadRoadmapDetails,
          child: buildErrorDisplay(),
        )
            : RefreshIndicator(
          onRefresh: loadRoadmapDetails,
          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor:
                    const Color(0xFFE6ECE2),
                    child: Text(
                      icon.isEmpty ? '💻' : icon,
                      style:
                      const TextStyle(fontSize: 25),
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Text(
                      'Build Your Career Step by Step',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 15),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF52606D),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              buildProgressSection(),
              const SizedBox(height: 23),
              const Text(
                'Learning Steps',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Complete each step and explore its learning resources.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFF52606D),
                ),
              ),
              const SizedBox(height: 15),
              if (steps.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 35,
                  ),
                  child: Center(
                    child: Text(
                      'No learning steps have been added yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF7B8794),
                      ),
                    ),
                  ),
                )
              else
                ...steps.asMap().entries.map(
                      (entry) => buildStepCard(
                    entry.value,
                    entry.key,
                  ),
                ),
              if (steps.isNotEmpty &&
                  completedSteps == totalSteps)
                Container(
                  padding: const EdgeInsets.all(15),
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8F1),
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.celebration,
                        color: Color(0xFF2E7D32),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Congratulations! You completed this roadmap.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
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
    );
  }
}
