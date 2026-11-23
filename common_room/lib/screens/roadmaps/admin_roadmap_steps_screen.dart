
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_step_resources_screen.dart';

class AdminRoadmapStepsScreen extends StatefulWidget {
  final int roadmapId;
  final String roadmapTitle;

  const AdminRoadmapStepsScreen({
    super.key,
    required this.roadmapId,
    required this.roadmapTitle,
  });

  @override
  State<AdminRoadmapStepsScreen> createState() =>
      _AdminRoadmapStepsScreenState();
}

class _AdminRoadmapStepsScreenState
    extends State<AdminRoadmapStepsScreen> {
  static const String apiUrl =
      'http://172.20.10.3/common_room_api';

  List<Map<String, dynamic>> steps = [];

  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadSteps();
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

  Future<void> loadSteps() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse(
          '$apiUrl/admin_manage_roadmap_steps.php'
              '?roadmap_id=${widget.roadmapId}',
        ),
        headers: await getHeaders(),
      ).timeout(const Duration(seconds: 20));

      final result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        final List<dynamic> data = result['steps'] ?? [];

        if (!mounted) return;

        setState(() {
          steps = data
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception(
          result['message'] ?? 'Could not load learning steps.',
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

  Future<void> saveStep({
    int? stepId,
    required String title,
    required String description,
    required int stepOrder,
  }) async {
    final isEditing = stepId != null;

    final body = {
      'roadmap_id': widget.roadmapId,
      if (isEditing) 'step_id': stepId,
      'title': title,
      'description': description,
      'step_order': stepOrder,
    };

    final headers = await getHeaders();

    final response = isEditing
        ? await http.put(
      Uri.parse('$apiUrl/admin_manage_roadmap_steps.php'),
      headers: headers,
      body: jsonEncode(body),
    )
        : await http.post(
      Uri.parse('$apiUrl/admin_manage_roadmap_steps.php'),
      headers: headers,
      body: jsonEncode(body),
    );

    final result =
    jsonDecode(response.body) as Map<String, dynamic>;

    if ((response.statusCode != 200 &&
        response.statusCode != 201) ||
        result['success'] != true) {
      throw Exception(
        result['message'] ?? 'Could not save learning step.',
      );
    }

    await loadSteps();
  }

  Future<void> deleteStep(int stepId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiUrl/admin_manage_roadmap_steps.php'),
        headers: await getHeaders(),
        body: jsonEncode({
          'step_id': stepId,
        }),
      ).timeout(const Duration(seconds: 20));

      final result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Learning step deleted successfully.'),
          ),
        );

        await loadSteps();
      } else {
        throw Exception(
          result['message'] ?? 'Could not delete learning step.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void openStepResources(Map<String, dynamic> step) {
    final stepId = int.parse(step['id'].toString());
    final stepTitle =
        step['title']?.toString() ?? 'Learning Step';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminStepResourcesScreen(
          stepId: stepId,
          stepTitle: stepTitle,
        ),
      ),
    );
  }

  void showStepDialog({
    Map<String, dynamic>? step,
  }) {
    final isEditing = step != null;

    final titleController = TextEditingController(
      text: step?['title']?.toString() ?? '',
    );

    final descriptionController = TextEditingController(
      text: step?['description']?.toString() ?? '',
    );

    final orderController = TextEditingController(
      text: step?['step_order']?.toString() ??
          (steps.length + 1).toString(),
    );

    final formKey = GlobalKey<FormState>();

    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing
                    ? 'Edit Learning Step'
                    : 'Add Learning Step',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Step title',
                          hintText:
                          'Learn Programming Fundamentals',
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Enter a step title.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Step description',
                          hintText:
                          'Explain what the student should learn.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: orderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Learning order',
                          hintText: '1',
                        ),
                        validator: (value) {
                          final number = int.tryParse(
                            value?.trim() ?? '',
                          );

                          if (number == null || number < 1) {
                            return 'Enter a valid order starting from 1.';
                          }

                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    setDialogState(() {
                      saving = true;
                    });

                    try {
                      await saveStep(
                        stepId: isEditing
                            ? int.parse(step['id'].toString())
                            : null,
                        title: titleController.text.trim(),
                        description:
                        descriptionController.text.trim(),
                        stepOrder: int.parse(
                          orderController.text.trim(),
                        ),
                      );

                      if (!mounted) return;

                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditing
                                ? 'Learning step updated successfully.'
                                : 'Learning step created successfully.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;

                      setDialogState(() {
                        saving = false;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                        ),
                      );
                    }
                  },
                  child: saving
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      titleController.dispose();
      descriptionController.dispose();
      orderController.dispose();
    });
  }

  void showDeleteConfirmation(int stepId, String title) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete learning step?'),
          content: Text(
            'Are you sure you want to delete "$title"? '
                'Its associated resources may also be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                deleteStep(stepId);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget stepCard(Map<String, dynamic> step, int index) {
    final stepId = int.parse(step['id'].toString());

    final title =
        step['title']?.toString() ?? 'Untitled step';

    final description =
        step['description']?.toString() ?? '';

    final order =
        step['step_order']?.toString() ?? '$index';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openStepResources(step),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
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
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE6ECE2),
                  child: Text(
                    order,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172B3A),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172B3A),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      showStepDialog(step: step);
                    } else if (value == 'delete') {
                      showDeleteConfirmation(stepId, title);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF52606D),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Learning order: $order',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7B8794),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Manage resources',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Color(0xFF7B8794),
                ),
              ],
            ),
          ],
        ),
      ),
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
          'Learning Steps',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadSteps,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh steps',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showStepDialog(),
        backgroundColor: const Color(0xFF172B3A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Step'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF8F9F7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Career Roadmap',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF52606D),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.roadmapTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172B3A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Total learning steps: ${steps.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF52606D),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(),
              )
                  : errorMessage.isNotEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        errorMessage,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: loadSteps,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
                  : RefreshIndicator(
                onRefresh: loadSteps,
                child: steps.isEmpty
                    ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Text(
                        'No learning steps yet.\n'
                            'Tap Add Step to create the first one.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    90,
                  ),
                  itemCount: steps.length,
                  itemBuilder: (context, index) {
                    return stepCard(
                      steps[index],
                      index + 1,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
