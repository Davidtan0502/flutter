import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/login/admin/admin_incident_report_screen.dart';
import 'user_management_service.dart';

class RadarAppUserCard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String searchQuery;
  final VoidCallback? onUserDeleted;

  const RadarAppUserCard({
    super.key, 
    required this.userData,
    this.searchQuery = '',
    this.onUserDeleted,
  });

  @override
  State<RadarAppUserCard> createState() => _RadarAppUserCardState();
}

class _RadarAppUserCardState extends State<RadarAppUserCard> {
  int _incidentCount = 0;
  bool _loadingIncidents = false;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadIncidentCount();
  }

  Future<void> _loadIncidentCount() async {
    setState(() => _loadingIncidents = true);
    try {
      final incidentsResponse = await _supabase
          .from('incidents')
          .select()
          .eq('user_id', widget.userData['id']);
      
      setState(() => _incidentCount = incidentsResponse.length);
    } catch (e) {
      debugPrint('Error loading incidents: $e');
    } finally {
      setState(() => _loadingIncidents = false);
    }
  }

  Future<void> _deleteUserAccount() async {
    await UserManagementService.deleteUserAccount(
      context: context,
      userId: widget.userData['id'],
      userEmail: widget.userData['email'] ?? 'Unknown User',
      collectionName: 'app_users', // Changed from 'users' to 'app_users'
      onSuccess: () {
        widget.onUserDeleted?.call();
      },
    );
  }

  void _viewUserDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Details'),
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
                title: 'Last Active:', 
                value: _formatTimestamp(widget.userData['last_active'])
              ),
              _DetailRow(
                title: 'Status:', 
                value: _getOnlineStatusText(widget.userData['last_active'])
              ),
              _DetailRow(
                title: 'Last Activity:', 
                value: _getTimeSinceLastActivity(widget.userData['last_active'])
              ),
              _DetailRow(title: 'Emergency Reports:', value: '${widget.userData['emergency_reports'] ?? 0}'),
              _DetailRow(title: 'Incidents Reported:', value: '$_incidentCount'),
              if (widget.userData['last_location'] != null) 
                _DetailRow(title: 'Last Location:', value: '${widget.userData['last_location']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _viewUserIncidents(context),
            child: const Text('View Incidents'),
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

  void _viewUserIncidents(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminIncidentReportScreen(
          userId: widget.userData['id'],
          userEmail: widget.userData['email'] ?? 'Unknown User',
          userName: widget.userData['name'] ?? 'Unknown Name',
          userAddress: widget.userData['address'] ?? 'No address provided',
        ),
      ),
    );
  }

  void _sendEmergencyAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Emergency alert sent to ${widget.userData['email']}'),
        backgroundColor: Colors.orange,
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
  bool _isUserOnline(dynamic lastActive) {
    if (lastActive == null) return false;
    
    DateTime lastActiveTime;
    
    // Handle different timestamp formats
    if (lastActive is String) {
      final parsed = DateTime.tryParse(lastActive);
      if (parsed == null) return false;
      lastActiveTime = parsed;
    } else if (lastActive is DateTime) {
      lastActiveTime = lastActive;
    } else {
      return false;
    }
    
    // Configurable time threshold (5 minutes for more accuracy)
    final timeThreshold = const Duration(minutes: 5);
    final thresholdTime = DateTime.now().subtract(timeThreshold);
    
    return lastActiveTime.isAfter(thresholdTime);
  }

  // Get online status text
  String _getOnlineStatusText(dynamic lastActive) {
    return _isUserOnline(lastActive) ? 'Online' : 'Offline';
  }

  // Get online status color
  Color _getOnlineStatusColor(dynamic lastActive) {
    return _isUserOnline(lastActive) ? Colors.green : Colors.grey;
  }

  // Get time since last activity
  String _getTimeSinceLastActivity(dynamic lastActive) {
    if (lastActive == null) return 'Never active';
    
    DateTime lastActivity;
    
    // Handle different timestamp formats
    if (lastActive is String) {
      final parsed = DateTime.tryParse(lastActive);
      if (parsed == null) return 'Never active';
      lastActivity = parsed;
    } else if (lastActive is DateTime) {
      lastActivity = lastActive;
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

  @override
  Widget build(BuildContext context) {
    final userData = _getUserData();
    
    return UserCardTemplate(
      email: userData.email,
      name: userData.name,
      role: userData.role,
      createdAt: userData.createdAt,
      lastLogin: userData.lastActive,
      additionalInfo: 'Emergencies: ${userData.emergencyReports} • Incidents: ${_loadingIncidents ? '...' : _incidentCount}',
      isUpdating: false,
      onRoleChanged: null,
      showRoleDropdown: false,
      statusIndicator: userData.onlineStatusColor,
      additionalActions: [
        IconButton(
          icon: const Icon(Icons.list_alt, size: 18),
          onPressed: () => _viewUserIncidents(context),
          tooltip: 'View incidents',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          onPressed: _deleteUserAccount,
          tooltip: 'Delete user',
          color: Colors.red,
        ),
        IconButton(
          icon: const Icon(Icons.info, size: 18),
          onPressed: () => _viewUserDetails(context),
          tooltip: 'View details',
        ),
      ],
    );
  }

  _RadarUserData _getUserData() {
    final email = widget.userData['email'] ?? 'No email';
    final name = widget.userData['name'] ?? 'No name';
    final role = widget.userData['role'] ?? 'user';
    final createdAt = widget.userData['created_at'];
    final lastActive = widget.userData['last_active'];
    final emergencyReports = widget.userData['emergency_reports'] ?? 0;
    final isOnline = _isUserOnline(lastActive);
    final onlineStatusColor = _getOnlineStatusColor(lastActive);
    final onlineStatusText = _getOnlineStatusText(lastActive);
    final timeSinceActivity = _getTimeSinceLastActivity(lastActive);

    return _RadarUserData(
      email: email,
      name: name,
      role: role,
      createdAt: createdAt,
      lastActive: lastActive,
      emergencyReports: emergencyReports,
      isOnline: isOnline,
      onlineStatusColor: onlineStatusColor,
      onlineStatusText: onlineStatusText,
      timeSinceActivity: timeSinceActivity,
    );
  }
}

class _RadarUserData {
  final String email;
  final String name;
  final String role;
  final dynamic createdAt;
  final dynamic lastActive;
  final int emergencyReports;
  final bool isOnline;
  final Color onlineStatusColor;
  final String onlineStatusText;
  final String timeSinceActivity;

  _RadarUserData({
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    required this.lastActive,
    required this.emergencyReports,
    required this.isOnline,
    required this.onlineStatusColor,
    required this.onlineStatusText,
    required this.timeSinceActivity,
  });
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;

  const _DetailRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class UserCardTemplate extends StatelessWidget {
  final String email;
  final String role;
  final dynamic createdAt;
  final dynamic lastLogin;
  final String? additionalInfo;
  final bool isUpdating;
  final Function(String?)? onRoleChanged;
  final bool showRoleDropdown;
  final Color? statusIndicator;
  final List<Widget>? additionalActions;
  final String? name;
  final String? department;

  const UserCardTemplate({
    super.key,
    required this.email,
    required this.role,
    this.createdAt,
    this.lastLogin,
    this.additionalInfo,
    required this.isUpdating,
    this.onRoleChanged,
    required this.showRoleDropdown,
    this.statusIndicator,
    this.additionalActions,
    this.name,
    this.department,
  });

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

  // Get time since last activity for radar users
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _buildCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (statusIndicator != null) ..._buildStatusSection(),
              _buildRoleIcon(),
              const SizedBox(width: 12),
              _buildUserInfoSection(context),
              _buildActionsSection(),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _buildCardDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
      ),
    );
  }

  List<Widget> _buildStatusSection() {
    return [
      Tooltip(
        message: statusIndicator == Colors.green ? 'Online' : 'Offline',
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: statusIndicator,
            shape: BoxShape.circle,
            boxShadow: [
              if (statusIndicator == Colors.green)
                BoxShadow(
                  color: statusIndicator!.withAlpha(128), // Fixed deprecated withOpacity
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
    ];
  }

  Widget _buildRoleIcon() {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isAdmin ? Colors.blue.withAlpha(51) : Colors.green.withAlpha(51), // Fixed deprecated withOpacity
        shape: BoxShape.circle,
      ),
      child: Icon(
        isAdmin ? Icons.admin_panel_settings : Icons.person,
        size: 20,
        color: isAdmin ? Colors.blue[800] : Colors.green[800],
      ),
    );
  }

  Widget _buildUserInfoSection(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            email,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (name != null && name!.isNotEmpty) ..._buildNameSection(context),
          ..._buildTimestampSection(),
          if (additionalInfo != null) ..._buildAdditionalInfoSection(),
          _buildStatusInfoSection(),
        ],
      ),
    );
  }

  List<Widget> _buildNameSection(BuildContext context) {
    return [
      const SizedBox(height: 2),
      Text(
        name!,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(179), // Fixed deprecated withOpacity
        ),
      ),
    ];
  }

  List<Widget> _buildTimestampSection() {
    return [
      const SizedBox(height: 2),
      Text(
        'Created: ${_formatTimestamp(createdAt)}',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
      if (lastLogin != null) ...[
        const SizedBox(height: 2),
        Text(
          'Last active: ${_formatTimestamp(lastLogin)}',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildAdditionalInfoSection() {
    return [
      const SizedBox(height: 2),
      Text(
        additionalInfo!,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.orange,
          fontWeight: FontWeight.bold,
        ),
      ),
    ];
  }

  Widget _buildStatusInfoSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusIndicator,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusIndicator == Colors.green ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              color: statusIndicator,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '• ${_getTimeSinceLastActivity(lastLogin)}',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    if (isUpdating) {
      return const SizedBox(
        width: 20, 
        height: 20, 
        child: CircularProgressIndicator(strokeWidth: 2)
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showRoleDropdown) _buildRoleDropdown(),
        if (additionalActions != null) ...additionalActions!,
      ],
    );
  }

  Widget _buildRoleDropdown() {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin ? Colors.blue.withAlpha(51) : Colors.grey.withAlpha(25), // Fixed deprecated withOpacity
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdmin ? Colors.blue[200]! : Colors.grey[300]!,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: role,
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          dropdownColor: Colors.white,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isAdmin ? Colors.blue[800] : Colors.black,
          ),
          onChanged: onRoleChanged,
          items: const [
            DropdownMenuItem(value: 'viewer', child: Text('VIEWER')),
            DropdownMenuItem(value: 'admin', child: Text('ADMIN')),
          ],
        ),
      ),
    );
  }
}