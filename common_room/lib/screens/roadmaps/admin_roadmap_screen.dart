
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_roadmap_steps_screen.dart';

class AdminRoadmapScreen extends StatefulWidget {
  const AdminRoadmapScreen({super.key});

  @override
  State<AdminRoadmapScreen> createState() =>
      _AdminRoadmapScreenState();
}

class _AdminRoadmapScreenState extends State<AdminRoadmapScreen> {
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
        Uri.parse('$apiUrl/admin_manage_roadmaps.php'),
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
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception(
          result['message'] ?? 'Could not load roadmaps.',
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

  Future<void> saveRoadmap({
    int? roadmapId,
    required String title,
    required String description,
    required String icon,
    required bool isPublished,
  }) async {
    final isEditing = roadmapId != null;

    final body = {
      if (isEditing) 'roadmap_id': roadmapId,
      'title': title,
      'description': description,
      'icon': icon,
      'is_published': isPublished ? 1 : 0,
    };

    final headers = await getHeaders();

    final response = isEditing
        ? await http.put(
      Uri.parse('$apiUrl/admin_manage_roadmaps.php'),
      headers: headers,
      body: jsonEncode(body),
    )
        : await http.post(
      Uri.parse('$apiUrl/admin_manage_roadmaps.php'),
      headers: headers,
      body: jsonEncode(body),
    );

    final result =
    jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200 ||
        result['success'] != true) {
      throw Exception(
        result['message'] ?? 'Could not save roadmap.',
      );
    }

    await loadRoadmaps();
  }

  Future<void> deleteRoadmap(int roadmapId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiUrl/admin_manage_roadmaps.php'),
        headers: await getHeaders(),
        body: jsonEncode({'roadmap_id': roadmapId}),
      ).timeout(const Duration(seconds: 20));

      final result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Roadmap deleted successfully.'),
          ),
        );

        await loadRoadmaps();
      } else {
        throw Exception(
          result['message'] ?? 'Could not delete roadmap.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void openRoadmapSteps(Map<String, dynamic> roadmap) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminRoadmapStepsScreen(
          roadmapId: int.parse(roadmap['id'].toString()),
          roadmapTitle: roadmap['title']?.toString() ?? '',
        ),
      ),
    );
  }

  void showRoadmapDialog({
    Map<String, dynamic>? roadmap,
  }) {
    final titleController = TextEditingController(
      text: roadmap?['title']?.toString() ?? '',
    );

    final descriptionController = TextEditingController(
      text: roadmap?['description']?.toString() ?? '',
    );

    final iconController = TextEditingController(
      text: roadmap?['icon']?.toString() ?? '💻',
    );

    bool published = roadmap?['is_published'] == 1 ||
        roadmap?['is_published'] == true;

    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                roadmap == null
                    ? 'Create Career Roadmap'
                    : 'Edit Career Roadmap',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Career title',
                          hintText: 'Software Engineer',
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Enter a career title.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe this career path',
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Enter a description.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: iconController,
                        decoration: const InputDecoration(
                          labelText: 'Career icon (emoji)',
                          hintText: '💻',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Publish roadmap'),
                        subtitle: const Text(
                          'Published roadmaps are visible to students.',
                        ),
                        value: published,
                        onChanged: (value) {
                          setDialogState(() {
                            published = value;
                          });
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
                    titleController.dispose();
                    descriptionController.dispose();
                    iconController.dispose();
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
                      await saveRoadmap(
                        roadmapId: roadmap == null
                            ? null
                            : int.parse(
                          roadmap['id'].toString(),
                        ),
                        title: titleController.text.trim(),
                        description:
                        descriptionController.text.trim(),
                        icon: iconController.text.trim(),
                        isPublished: published,
                      );

                      if (!mounted) return;

                      Navigator.pop(dialogContext);

                      titleController.dispose();
                      descriptionController.dispose();
                      iconController.dispose();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Roadmap saved successfully.',
                          ),
                        ),
                      );
                    } catch (e) {
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
    );
  }

  Widget roadmapCard(Map<String, dynamic> roadmap) {
    final id = int.parse(roadmap['id'].toString());
    final title = roadmap['title']?.toString() ?? 'Untitled';
    final description =
        roadmap['description']?.toString() ?? '';
    final icon = roadmap['icon']?.toString() ?? '💻';

    final published = roadmap['is_published'] == 1 ||
        roadmap['is_published'] == true;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openRoadmapSteps(roadmap),
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
                  backgroundColor: const Color(0xFFE6ECE2),
                  child: Text(
                    icon.isEmpty ? '💻' : icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172B3A),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      showRoadmapDialog(roadmap: roadmap);
                    } else if (value == 'delete') {
                      showDeleteConfirmation(id, title);
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
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF52606D),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  published ? Icons.visibility : Icons.visibility_off,
                  size: 16,
                  color: published ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  published ? 'Published' : 'Not published',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: published ? Colors.green : Colors.orange,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Manage steps',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF172B3A),
                    fontWeight: FontWeight.bold,
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

  void showDeleteConfirmation(int id, String title) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete roadmap?'),
        content: Text(
          'Are you sure you want to delete "$title"? '
              'Its related learning steps and resources may also be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              deleteRoadmap(id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172B3A),
        title: const Text(
          'Career Roadmaps',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadRoadmaps,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh roadmaps',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRoadmapDialog(),
        backgroundColor: const Color(0xFF172B3A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Roadmap'),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
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
                  onPressed: loadRoadmaps,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        )
            : RefreshIndicator(
          onRefresh: loadRoadmaps,
          child: roadmaps.isEmpty
              ? ListView(
            children: const [
              SizedBox(height: 150),
              Center(
                child: Text(
                  'No career roadmaps yet.\n'
                      'Tap Add Roadmap to create one.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          )
              : ListView(
            padding: const EdgeInsets.fromLTRB(
              16, 16, 16, 90,
            ),
            children: [
              Text(
                'Total roadmaps: ${roadmaps.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 14),
              ...roadmaps.map(roadmapCard),
            ],
          ),
        ),
      ),
    );
  }
}
