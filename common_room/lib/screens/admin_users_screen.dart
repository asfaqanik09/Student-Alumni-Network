
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminUsersScreen extends StatefulWidget {
  final String adminEmail;

  const AdminUsersScreen({
    super.key,
    required this.adminEmail,
  });

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const String apiUrl =
      'http://172.20.10.3/common_room_api';

  List<Map<String, dynamic>> users = [];
  bool isLoading = true;
  String errorMessage = '';
  String searchText = '';
  String selectedRole = 'all';

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse(
          '$apiUrl/admin_get_users.php'
              '?email=${Uri.encodeComponent(widget.adminEmail)}',
        ),
      ).timeout(const Duration(seconds: 20));

      final result =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 &&
          result['success'] == true) {
        final List<dynamic> data = result['users'] ?? [];

        if (!mounted) return;

        setState(() {
          users = data
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception(
          result['message'] ?? 'Could not load users.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Could not load users. Check your connection.';
      });
    }
  }

  List<Map<String, dynamic>> get filteredUsers {
    return users.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();

      final matchesSearch =
          name.contains(searchText.toLowerCase()) ||
              email.contains(searchText.toLowerCase());

      final matchesRole =
          selectedRole == 'all' || role == selectedRole;

      return matchesSearch && matchesRole;
    }).toList();
  }

  Color roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return Colors.blue;
      case 'alumni':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  Widget userCard(Map<String, dynamic> user) {
    final name = (user['name'] ?? 'Unknown User').toString();
    final email = (user['email'] ?? '').toString();
    final role = (user['role'] ?? 'pending').toString();
    final verified = user['email_verified'] == 1 ||
        user['email_verified'] == true;

    final color = roleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F7),
        border: Border.all(color: const Color(0xFFE1E5DF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: const Color(0xFFE6ECE2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
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
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172B3A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF52606D),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      verified ? 'Email verified' : 'Not verified',
                      style: TextStyle(
                        fontSize: 10,
                        color: verified ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
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
          'Manage Users',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh users',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        searchText = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name or email',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Filter by role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All users'),
                      ),
                      DropdownMenuItem(
                        value: 'student',
                        child: Text('Students'),
                      ),
                      DropdownMenuItem(
                        value: 'alumni',
                        child: Text('Alumni'),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending accounts'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value ?? 'all';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Total users: ${users.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF172B3A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage.isNotEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: loadUsers,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
                  : filteredUsers.isEmpty
                  ? const Center(
                child: Text('No users found.'),
              )
                  : RefreshIndicator(
                onRefresh: loadUsers,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    return userCard(filteredUsers[index]);
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
