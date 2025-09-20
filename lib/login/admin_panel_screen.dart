import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Admin Panel",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2C5282),
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeaderSection(),
            const SizedBox(height: 24),
            
            // Statistics Cards
            _buildStatisticsSection(),
            const SizedBox(height: 24),
            
            // Users List
            Expanded(
              child: _buildUsersList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return const Row(
      children: [
        Icon(Icons.admin_panel_settings, size: 32, color: Color(0xFF2C5282)),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "User Management",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Manage user roles and permissions",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('dashboard_users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatCard(title: "Total Users", value: "--", icon: Icons.people),
              _StatCard(title: "Admins", value: "--", icon: Icons.admin_panel_settings),
              _StatCard(title: "Users", value: "--", icon: Icons.person),
            ],
          );
        }

        final users = snapshot.data!.docs;
        final adminCount = users.where((user) => user['role'] == 'admin').length;
        final userCount = users.where((user) => user['role'] == 'user').length;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatCard(title: "Total Users", value: users.length.toString(), icon: Icons.people),
            _StatCard(title: "Admins", value: adminCount.toString(), icon: Icons.admin_panel_settings),
            _StatCard(title: "Users", value: userCount.toString(), icon: Icons.person),
          ],
        );
      },
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dashboard_users')
          .orderBy('email')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  "Error loading users\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  "No users found",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Users will appear here once they register",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final users = snapshot.data!.docs;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "User List",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final data = user.data() as Map<String, dynamic>;
                      final email = data['email'] ?? 'No email';
                      final role = data['role'] ?? 'user';
                      final createdAt = data['createdAt'] as Timestamp?;
                      final lastLogin = data['lastLogin'] as Timestamp?;

                      return _UserCard(
                        userId: user.id,
                        email: email,
                        role: role,
                        createdAt: createdAt,
                        lastLogin: lastLogin,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Colors.blue[800]),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  final String userId;
  final String email;
  final String role;
  final Timestamp? createdAt;
  final Timestamp? lastLogin;

  const _UserCard({
    required this.userId,
    required this.email,
    required this.role,
    this.createdAt,
    this.lastLogin,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _updating = false;

  Future<void> _updateUserRole(String? newRole) async {
    if (newRole == null || newRole == widget.role) return;

    setState(() => _updating = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('dashboard_users')
          .doc(widget.userId)
          .update({'role': newRole});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User role updated to $newRole'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update role: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() => _updating = false);
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Never';
    return DateFormat('MMM d, y - h:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.role == 'admin' ? Colors.blue[50] : Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                  size: 20,
                  color: widget.role == 'admin' ? Colors.blue[800] : Colors.green[800],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.email,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Created: ${_formatTimestamp(widget.createdAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (widget.lastLogin != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Last login: ${_formatTimestamp(widget.lastLogin)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _updating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.role == 'admin' ? Colors.blue[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.role == 'admin' ? Colors.blue[200]! : Colors.grey[300]!,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: widget.role,
                          icon: const Icon(Icons.arrow_drop_down, size: 16),
                          dropdownColor: Colors.white,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.role == 'admin' ? Colors.blue[800] : Colors.grey[800],
                          ),
                          onChanged: _updateUserRole, // Fixed: Now accepts String?
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('USER'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('ADMIN'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Colors.grey[100],
          ),
        ],
      ),
    );
  }
}