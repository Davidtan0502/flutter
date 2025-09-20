import 'package:flutter/material.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  List<Map<String, String>> users = [
    {'name': 'Juan Dela Cruz', 'role': 'Responder'},
    {'name': 'Maria Santos', 'role': 'Admin'},
  ];

  void _editUserRole(int index) {
    final roleController = TextEditingController(text: users[index]['role']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Role for ${users[index]['name']}'),
        content: TextField(
          controller: roleController,
          decoration: const InputDecoration(labelText: 'Role'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                users[index]['role'] = roleController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            title: Text(user['name']!),
            subtitle: Text(user['role']!),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editUserRole(index),
            ),
          );
        },
      ),
    );
  }
}
