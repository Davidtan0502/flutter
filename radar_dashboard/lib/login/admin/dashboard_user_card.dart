import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DashboardUserCard extends StatefulWidget {
  final QueryDocumentSnapshot user;
  final Map<String, dynamic> data;

  const DashboardUserCard({super.key, required this.user, required this.data});

  @override
  State<DashboardUserCard> createState() => _DashboardUserCardState();
}

class _DashboardUserCardState extends State<DashboardUserCard> {
  bool _updating = false;

  Future<void> _updateUserRole(String? newRole) async {
    if (newRole == null || newRole == widget.data['role']) return;

    setState(() => _updating = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('dashboard_users')
          .doc(widget.user.id)
          .update({'role': newRole});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User role updated to $newRole'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update role: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _updating = false);
    }
  }

  void _viewUserDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dashboard User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(title: 'Email:', value: widget.data['email'] ?? 'N/A'),
              _DetailRow(title: 'User ID:', value: widget.user.id),
              _DetailRow(title: 'Role:', value: widget.data['role'] ?? 'user'),
              _DetailRow(
                title: 'Created:', 
                value: _formatTimestamp(widget.data['createdAt'] as Timestamp?)
              ),
              _DetailRow(
                title: 'Last Login:', 
                value: _formatTimestamp(widget.data['lastLogin'] as Timestamp?)
              ),
              if (widget.data['name'] != null) 
                _DetailRow(title: 'Name:', value: widget.data['name']),
              if (widget.data['department'] != null) 
                _DetailRow(title: 'Department:', value: widget.data['department']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Never';
    return DateFormat('MMM d, y - h:mm a').format(timestamp.toDate());
  }

  bool _isUserOnline(Timestamp? lastLogin) {
    if (lastLogin == null) return false;
    final fifteenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 15));
    return lastLogin.toDate().isAfter(fifteenMinutesAgo);
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'moderator':
        return Colors.blue;
      case 'user': // Added user role
        return Colors.green;
      case 'viewer':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'moderator':
        return Icons.security;
      case 'user': // Added user role
        return Icons.person;
      case 'viewer':
        return Icons.visibility;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.data['email'] ?? 'No email';
    final role = widget.data['role'] ?? 'user';
    final createdAt = widget.data['createdAt'] as Timestamp?;
    final lastLogin = widget.data['lastLogin'] as Timestamp?;
    final name = widget.data['name'] ?? '';
    final department = widget.data['department'] ?? '';
    final isOnline = _isUserOnline(lastLogin);
    final roleColor = _getRoleColor(role);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Online Status Indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              
              // Role Icon with Color
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getRoleIcon(role),
                  size: 20,
                  color: roleColor,
                ),
              ),
              const SizedBox(width: 12),
              
              // User Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email
                    Text(
                      email,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Name (if available)
                    if (name.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    // Department (if available)
                    if (department.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        department,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    // Timestamps
                    const SizedBox(height: 4),
                    Text(
                      'Created: ${_formatTimestamp(createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    if (lastLogin != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Last login: ${_formatTimestamp(lastLogin)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                    
                    // Online Status
                    const SizedBox(height: 2),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Actions Section
              if (_updating) 
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else 
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Role Dropdown - FIXED: Added 'user' option
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: roleColor.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: role,
                          icon: const Icon(Icons.arrow_drop_down, size: 16),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                          onChanged: _updateUserRole,
                          // FIXED: Added 'user' option to match Firebase data
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('USER'),
                            ),
                            DropdownMenuItem(
                              value: 'viewer',
                              child: Text('VIEWER'),
                            ),
                            DropdownMenuItem(
                              value: 'moderator',
                              child: Text('MODERATOR'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('ADMIN'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Details Button
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 18),
                      onPressed: () => _viewUserDetails(context),
                      tooltip: 'View details',
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ],
                ),
            ],
          ),
          
          // Role Badge
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: roleColor.withOpacity(0.3)),
            ),
            child: Text(
              role.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: roleColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;

  const _DetailRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}