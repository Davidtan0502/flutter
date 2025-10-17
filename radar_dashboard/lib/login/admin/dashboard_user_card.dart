import 'package:flutter/material.dart';
import 'package:radar_dashboard/login/admin/security%20roles/admin_management_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'user_management_service.dart';

class DashboardUserCard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isMobile;
  final VoidCallback? onUserDeleted;

  const DashboardUserCard({
    super.key, 
    required this.userData,
    this.isMobile = false,
    this.onUserDeleted,
  });

  @override
  State<DashboardUserCard> createState() => _DashboardUserCardState();
}

class _DashboardUserCardState extends State<DashboardUserCard> {
  bool _updating = false;

  Future<void> _updateUserRole(String? newRole) async {
    if (newRole == null || newRole == widget.userData['role']) return;

    setState(() => _updating = true);
    
    try {
      // Use the secure admin service for role changes
      bool success;
      if (newRole == 'admin') {
        success = await AdminManagementService.promoteToAdmin(widget.userData['id']);
      } else {
        success = await AdminManagementService.demoteToUser(widget.userData['id']);
      }

      if (success) {
        _showSuccessSnackbar('User role updated to $newRole');
        // Refresh the user data
        widget.onUserDeleted?.call(); // This will trigger a refresh
      } else {
        _showErrorSnackbar('Failed to update role. Please try again.');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to update role: $e');
    } finally {
      setState(() => _updating = false);
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _deleteUserAccount() async {
    await UserManagementService.deleteUserAccount(
      context: context,
      userId: widget.userData['id'],
      userEmail: widget.userData['email'] ?? 'Unknown User',
      collectionName: 'dashboard_users',
      onSuccess: () {
        widget.onUserDeleted?.call();
      },
    );
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
              _DetailRow(title: 'Email:', value: widget.userData['email'] ?? 'N/A'),
              _DetailRow(title: 'User ID:', value: widget.userData['id'] ?? 'N/A'),
              _DetailRow(title: 'Role:', value: widget.userData['role'] ?? 'user'),
              _DetailRow(
                title: 'Created:', 
                value: _formatTimestamp(widget.userData['created_at'])
              ),
              _DetailRow(
                title: 'Last Login:', 
                value: _formatTimestamp(widget.userData['last_login'])
              ),
              _DetailRow(
                title: 'Status:', 
                value: _getOnlineStatusText(widget.userData['last_login'])
              ),
              if (widget.userData['name'] != null) 
                _DetailRow(title: 'Name:', value: widget.userData['name']),
              if (widget.userData['department'] != null) 
                _DetailRow(title: 'Department:', value: widget.userData['department']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: _deleteUserAccount,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Never';
    
    // Handle both string and DateTime formats
    if (timestamp is String) {
      final dateTime = DateTime.tryParse(timestamp);
      return dateTime != null ? DateFormat('MMM d, y - h:mm a').format(dateTime) : 'Invalid date';
    } else if (timestamp is DateTime) {
      return DateFormat('MMM d, y - h:mm a').format(timestamp);
    }
    
    return 'Never';
  }

  // Enhanced online/offline detection with configurable threshold
  bool _isUserOnline(dynamic lastLogin) {
    if (lastLogin == null) return false;
    
    DateTime lastLoginTime;
    
    // Handle different timestamp formats
    if (lastLogin is String) {
      final parsed = DateTime.tryParse(lastLogin);
      if (parsed == null) return false;
      lastLoginTime = parsed;
    } else if (lastLogin is DateTime) {
      lastLoginTime = lastLogin;
    } else {
      return false;
    }
    
    // Configurable time threshold (5 minutes for more accuracy)
    final timeThreshold = const Duration(minutes: 5);
    final thresholdTime = DateTime.now().subtract(timeThreshold);
    
    return lastLoginTime.isAfter(thresholdTime);
  }

  // Get online status text
  String _getOnlineStatusText(dynamic lastLogin) {
    return _isUserOnline(lastLogin) ? 'Online' : 'Offline';
  }

  // Get online status color
  Color _getOnlineStatusColor(dynamic lastLogin) {
    return _isUserOnline(lastLogin) ? Colors.green : Colors.grey;
  }

  // Get time since last activity
  String _getTimeSinceLastActivity(dynamic lastLogin) {
    if (lastLogin == null) return 'Never active';
    
    DateTime lastActivity;
    
    // Handle different timestamp formats
    if (lastLogin is String) {
      final parsed = DateTime.tryParse(lastLogin);
      if (parsed == null) return 'Never active';
      lastActivity = parsed;
    } else if (lastLogin is DateTime) {
      lastActivity = lastLogin;
    } else {
      return 'Never active';
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastActivity);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'user':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'user':
        return Icons.person;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = _getUserData();
    
    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: _buildCardDecoration(),
      child: widget.isMobile 
          ? _buildMobileLayout(userData)
          : _buildDesktopLayout(userData),
    );
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(widget.isMobile ? 10 : 12),
      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  _UserData _getUserData() {
    final email = widget.userData['email'] ?? 'No email';
    final role = widget.userData['role'] ?? 'user';
    final createdAt = widget.userData['created_at'];
    final lastLogin = widget.userData['last_login'];
    final name = widget.userData['name'] ?? '';
    final department = widget.userData['department'] ?? '';
    final isOnline = _isUserOnline(lastLogin);
    final onlineStatusColor = _getOnlineStatusColor(lastLogin);
    final onlineStatusText = _getOnlineStatusText(lastLogin);
    final timeSinceActivity = _getTimeSinceLastActivity(lastLogin);
    final roleColor = _getRoleColor(role);

    return _UserData(
      email: email,
      role: role,
      createdAt: createdAt,
      lastLogin: lastLogin,
      name: name,
      department: department,
      isOnline: isOnline,
      onlineStatusColor: onlineStatusColor,
      onlineStatusText: onlineStatusText,
      timeSinceActivity: timeSinceActivity,
      roleColor: roleColor,
    );
  }

  Widget _buildMobileLayout(_UserData userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStatusIndicator(userData.isOnline, userData.onlineStatusColor),
            const SizedBox(width: 6),
            _buildRoleIcon(userData.role, userData.roleColor),
            const SizedBox(width: 8),
            _buildUserInfo(userData, isMobile: true),
            _buildActions(userData.role, userData.roleColor, isMobile: true),
          ],
        ),
        const SizedBox(height: 8),
        _buildTimestamps(userData, isMobile: true),
        const SizedBox(height: 6),
        _buildRoleBadge(userData.role, userData.roleColor, isMobile: true),
      ],
    );
  }

  Widget _buildDesktopLayout(_UserData userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStatusIndicator(userData.isOnline, userData.onlineStatusColor),
            const SizedBox(width: 8),
            _buildRoleIcon(userData.role, userData.roleColor),
            const SizedBox(width: 12),
            _buildUserInfo(userData, isMobile: false),
            _buildActions(userData.role, userData.roleColor, isMobile: false),
          ],
        ),
        const SizedBox(height: 8),
        _buildRoleBadge(userData.role, userData.roleColor, isMobile: false),
      ],
    );
  }

  Widget _buildStatusIndicator(bool isOnline, Color statusColor) {
    return Tooltip(
      message: isOnline ? 'Online' : 'Offline',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: statusColor,
          shape: BoxShape.circle,
          boxShadow: [
            if (isOnline)
              BoxShadow(
                color: statusColor.withOpacity(0.5),
                blurRadius: 4,
                spreadRadius: 2,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleIcon(String role, Color roleColor) {
    return Container(
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
    );
  }

  Widget _buildUserInfo(_UserData userData, {required bool isMobile}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userData.email,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: isMobile ? 14 : 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (userData.name.isNotEmpty) ...[
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              userData.name,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (!isMobile && userData.department.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              userData.department,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (!isMobile) ..._buildDesktopTimestamps(userData),
        ],
      ),
    );
  }

  List<Widget> _buildDesktopTimestamps(_UserData userData) {
    return [
      const SizedBox(height: 4),
      Text(
        'Created: ${_formatTimestamp(userData.createdAt)}',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      if (userData.lastLogin != null) ...[
        const SizedBox(height: 2),
        Text(
          'Last login: ${_formatTimestamp(userData.lastLogin)}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
      const SizedBox(height: 2),
      Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: userData.onlineStatusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            userData.onlineStatusText,
            style: TextStyle(
              fontSize: 12,
              color: userData.onlineStatusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '• ${userData.timeSinceActivity}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildTimestamps(_UserData userData, {required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Created: ${_formatTimestamp(userData.createdAt)}',
          style: TextStyle(
            fontSize: isMobile ? 10 : 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        if (userData.lastLogin != null) ...[
          SizedBox(height: isMobile ? 2 : 4),
          Text(
            'Last login: ${_formatTimestamp(userData.lastLogin)}',
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
        SizedBox(height: isMobile ? 2 : 4),
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: userData.onlineStatusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              userData.onlineStatusText,
              style: TextStyle(
                fontSize: isMobile ? 9 : 11,
                color: userData.onlineStatusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(String role, Color roleColor, {required bool isMobile}) {
    if (_updating) {
      return SizedBox(
        width: isMobile ? 16 : 20,
        height: isMobile ? 16 : 20,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRoleDropdown(role, roleColor, isMobile: isMobile),
        SizedBox(width: isMobile ? 8 : 12),
        _buildDeleteButton(isMobile: isMobile),
        SizedBox(width: isMobile ? 4 : 8),
        _buildInfoButton(isMobile: isMobile),
      ],
    );
  }

  Widget _buildRoleDropdown(String role, Color roleColor, {required bool isMobile}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: isMobile ? 2 : 4),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: roleColor.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: role,
          icon: Icon(Icons.arrow_drop_down, size: isMobile ? 14 : 16),
          dropdownColor: Theme.of(context).colorScheme.surface,
          style: TextStyle(
            fontSize: isMobile ? 10 : 12,
            fontWeight: FontWeight.bold,
            color: roleColor,
          ),
          onChanged: _updateUserRole,
          items: const [
            DropdownMenuItem(value: 'user', child: Text('USER')),
            DropdownMenuItem(value: 'admin', child: Text('ADMIN')),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton({required bool isMobile}) {
    return IconButton(
      icon: Icon(Icons.delete_outline, size: isMobile ? 16 : 18),
      onPressed: _deleteUserAccount,
      tooltip: 'Delete user',
      color: Colors.red,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildInfoButton({required bool isMobile}) {
    return IconButton(
      icon: Icon(Icons.info_outline, size: isMobile ? 16 : 18),
      onPressed: () => _viewUserDetails(context),
      tooltip: 'View details',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildRoleBadge(String role, Color roleColor, {required bool isMobile}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        border: Border.all(color: roleColor.withOpacity(0.3)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: isMobile ? 8 : 10,
          fontWeight: FontWeight.bold,
          color: roleColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _UserData {
  final String email;
  final String role;
  final dynamic createdAt;
  final dynamic lastLogin;
  final String name;
  final String department;
  final bool isOnline;
  final Color onlineStatusColor;
  final String onlineStatusText;
  final String timeSinceActivity;
  final Color roleColor;

  _UserData({
    required this.email,
    required this.role,
    required this.createdAt,
    required this.lastLogin,
    required this.name,
    required this.department,
    required this.isOnline,
    required this.onlineStatusColor,
    required this.onlineStatusText,
    required this.timeSinceActivity,
    required this.roleColor,
  });
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