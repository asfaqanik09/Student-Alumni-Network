
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminStepResourcesScreen extends StatefulWidget {
  final int stepId;
  final String stepTitle;

  const AdminStepResourcesScreen({
    super.key,
    required this.stepId,
    required this.stepTitle,
  });

  @override
  State<AdminStepResourcesScreen> createState() =>
      _AdminStepResourcesScreenState();
}

class _AdminStepResourcesScreenState
    extends State<AdminStepResourcesScreen> {
  static const String apiUrl =
      'http://172.20.10.3/common_room_api';

  List<Map<String, dynamic>> resources = [];
  bool isLoading = true;
  String errorMessage = '';

  final List<String> resourceTypes = [
    'course',
    'youtube',
    'tutorial',
    'documentation',
    'project',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    loadResources();
  }

  Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found. Please log in again.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> loadResources() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse(
          '$apiUrl/admin_manage_step_resources.php'
              '?step_id=${widget.stepId}',
        ),
        headers: await getHeaders(),
      ).timeout(const Duration(seconds: 20));

      final result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        final List<dynamic> data = result['resources'] ?? [];

        if (!mounted) return;

        setState(() {
          resources = data
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception(
          result['message'] ?? 'Could not load learning resources.',
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

  Future<void> saveResource({
    int? resourceId,
    required String title,
    required String type,
    required String url,
    required String description,
  }) async {
    final isEditing = resourceId != null;

    final body = {
      if (isEditing) 'resource_id': resourceId,
      'step_id': widget.stepId,
      'title': title,
      'resource_type': type,
      'url': url,
      'description': description,
    };

    final headers = await getHeaders();

    final response = isEditing
        ? await http.put(
      Uri.parse('$apiUrl/admin_manage_step_resources.php'),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20))
        : await http.post(
      Uri.parse('$apiUrl/admin_manage_step_resources.php'),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));

    final result =
    jsonDecode(response.body) as Map<String, dynamic>;

    if ((response.statusCode != 200 &&
        response.statusCode != 201) ||
        result['success'] != true) {
      throw Exception(
        result['message'] ?? 'Could not save learning resource.',
      );
    }

    await loadResources();
  }

  Future<void> deleteResource(int resourceId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiUrl/admin_manage_step_resources.php'),
        headers: await getHeaders(),
        body: jsonEncode({'resource_id': resourceId}),
      ).timeout(const Duration(seconds: 20));

      final result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resource deleted successfully.'),
          ),
        );

        await loadResources();
      } else {
        throw Exception(
          result['message'] ?? 'Could not delete resource.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void showResourceDialog({
    Map<String, dynamic>? resource,
  }) {
    final titleController = TextEditingController(
      text: resource?['title']?.toString() ?? '',
    );

    final urlController = TextEditingController(
      text: resource?['url']?.toString() ?? '',
    );

    final descriptionController = TextEditingController(
      text: resource?['description']?.toString() ?? '',
    );

    String selectedType =
        resource?['resource_type']?.toString() ?? 'tutorial';

    if (!resourceTypes.contains(selectedType)) {
      selectedType = 'tutorial';
    }

    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                resource == null
                    ? 'Add Learning Resource'
                    : 'Edit Learning Resource',
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
                          labelText: 'Resource title',
                          hintText: 'Flutter Beginner Course',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Enter a resource title.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Resource type',
                          border: OutlineInputBorder(),
                        ),
                        items: resourceTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type[0].toUpperCase() +
                                  type.substring(1),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedType = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: urlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Resource URL',
                          hintText: 'https://example.com',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final input = value?.trim() ?? '';
                          final uri = Uri.tryParse(input);

                          if (input.isEmpty ||
                              uri == null ||
                              !uri.hasAuthority ||
                              !['http', 'https'].contains(
                                uri.scheme.toLowerCase(),
                              )) {
                            return 'Enter a valid HTTP/HTTPS URL.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Explain what students will learn.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext),
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
                      await saveResource(
                        resourceId: resource == null
                            ? null
                            : int.parse(
                          resource['id'].toString(),
                        ),
                        title: titleController.text.trim(),
                        type: selectedType,
                        url: urlController.text.trim(),
                        description:
                        descriptionController.text.trim(),
                      );

                      if (!mounted) return;

                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            resource == null
                                ? 'Resource added successfully.'
                                : 'Resource updated successfully.',
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
      urlController.dispose();
      descriptionController.dispose();
    });
  }

  IconData getResourceIcon(String type) {
    switch (type) {
      case 'course':
        return Icons.school_outlined;
      case 'youtube':
        return Icons.play_circle_outline;
      case 'tutorial':
        return Icons.menu_book_outlined;
      case 'documentation':
        return Icons.description_outlined;
      case 'project':
        return Icons.code;
      default:
        return Icons.link;
    }
  }

  void showDeleteConfirmation(
      int resourceId,
      String title,
      ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete resource?'),
        content: Text(
          'Are you sure you want to delete "$title"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              deleteResource(resourceId);
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

  Widget resourceCard(Map<String, dynamic> resource) {
    final id = int.parse(resource['id'].toString());
    final title = resource['title']?.toString() ?? 'Untitled';
    final type = resource['resource_type']?.toString() ?? 'other';
    final url = resource['url']?.toString() ?? '';
    final description =
        resource['description']?.toString() ?? '';

    return Container(
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
                child: Icon(
                  getResourceIcon(type),
                  color: const Color(0xFF172B3A),
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
                    showResourceDialog(resource: resource);
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
            type.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF52606D),
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF52606D),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SelectableText(
            url,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blue,
              decoration: TextDecoration.underline,
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
          'Learning Resources',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadResources,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh resources',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showResourceDialog(),
        backgroundColor: const Color(0xFF172B3A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Resource'),
      ),
      body: SafeArea(
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
                  onPressed: loadResources,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        )
            : RefreshIndicator(
          onRefresh: loadResources,
          child: resources.isEmpty
              ? ListView(
            children: const [
              SizedBox(height: 150),
              Center(
                child: Text(
                  'No learning resources yet.\n'
                      'Tap Add Resource to create one.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          )
              : ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              90,
            ),
            children: [
              Text(
                'Learning Step: ${widget.stepTitle}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B3A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Total resources: ${resources.length}',
                style: const TextStyle(
                  color: Color(0xFF52606D),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ...resources.map(resourceCard),
            ],
          ),
        ),
      ),
    );
  }
}
