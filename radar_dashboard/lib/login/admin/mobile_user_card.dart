import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/login/admin/admin_incident_report_screen.dart';
import 'user_management_service.dart';

class RadarAppUserCard extends StatefulWidget {
  final QueryDocumentSnapshot user;
  final Map<String, dynamic> data;
  final String searchQuery;
  final VoidCallback? onUserDeleted;

  const RadarAppUserCard({
    super.key, 
    required this.user, 
    required this.data,
    this.searchQuery = '',
    this.onUserDeleted,
  });

  @override
  State<RadarAppUserCard> createState() => _RadarAppUserCardState();
}

class _RadarAppUserCardState extends State<RadarAppUserCard> {
  int _incidentCount = 0;
  bool _loadingIncidents = false;

  @override
  void initState() {
    super.initState();
    _loadIncidentCount();
  }

  Future<void> _loadIncidentCount() async {
    setState(() => _loadingIncidents = true);
    try {
      final incidentsSnapshot = await FirebaseFirestore.instance
          .collection('incidents')
          .where('userId', isEqualTo: widget.user.id)
          .get();
      
      setState(() => _incidentCount = incidentsSnapshot.docs.length);
    } catch (e) {
      debugPrint('Error loading incidents: $e');
    } finally {
      setState(() => _loadingIncidents = false);
    }
  }

  Future<void> _deleteUserAccount() async {
    await UserManagementService.deleteUserAccount(
      context: context,
      userId: widget.user.id,
      userEmail: widget.data['email'] ?? 'Unknown User',
      collectionName: 'users',
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
              _DetailRow(title: 'Email:', value: widget.data['email'] ?? 'N/A'),
              _DetailRow(title: 'User ID:', value: widget.user.id),
              _DetailRow(title: 'Role:', value: widget.data['role'] ?? 'user'),
              _DetailRow(
                title: 'Created:', 
                value: _formatTimestamp(widget.data['createdAt'] as Timestamp?)
              ),
              _DetailRow(
                title: 'Last Active:', 
                value: _formatTimestamp(widget.data['lastActive'] as Timestamp?)
              ),
              _DetailRow(
                title: 'Status:', 
                value: _getOnlineStatusText(widget.data['lastActive'] as Timestamp?)
              ),
              _DetailRow(
                title: 'Last Activity:', 
                value: _getTimeSinceLastActivity(widget.data['lastActive'] as Timestamp?)
              ),
              _DetailRow(title: 'Emergency Reports:', value: '${widget.data['emergencyReports'] ?? 0}'),
              _DetailRow(title: 'Incidents Reported:', value: '$_incidentCount'),
              if (widget.data['lastLocation'] != null) 
                _DetailRow(title: 'Last Location:', value: '${widget.data['lastLocation']}'),
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
          userId: widget.user.id,
          userEmail: widget.data['email'] ?? 'Unknown User',
          userName: widget.data['name'] ?? 'Unknown Name',
          userAddress: widget.data['address'] ?? 'No address provided',
        ),
      ),
    );
  }

  void _sendEmergencyAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Emergency alert sent to ${widget.data['email']}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Never';
    return DateFormat('MMM d, y - h:mm a').format(timestamp.toDate());
  }

  // Enhanced online/offline detection with configurable threshold
  bool _isUserOnline(Timestamp? lastActive) {
    if (lastActive == null) return false;
    
    // Configurable time threshold (5 minutes for more accuracy)
    final timeThreshold = const Duration(minutes: 5);
    final thresholdTime = DateTime.now().subtract(timeThreshold);
    
    return lastActive.toDate().isAfter(thresholdTime);
  }

  // Get online status text
  String _getOnlineStatusText(Timestamp? lastActive) {
    return _isUserOnline(lastActive) ? 'Online' : 'Offline';
  }

  // Get online status color
  Color _getOnlineStatusColor(Timestamp? lastActive) {
    return _isUserOnline(lastActive) ? Colors.green : Colors.grey;
  }

  // Get time since last activity
  String _getTimeSinceLastActivity(Timestamp? lastActive) {
    if (lastActive == null) return 'Never active';
    
    final now = DateTime.now();
    final lastActivity = lastActive.toDate();
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
          icon: const Icon(Icons.warning, size: 18),
          onPressed: _sendEmergencyAlert,
          tooltip: 'Send emergency alert',
        ),
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
    final email = widget.data['email'] ?? 'No email';
    final name = widget.data['name'] ?? 'No name';
    final role = widget.data['role'] ?? 'user';
    final createdAt = widget.data['createdAt'] as Timestamp?;
    final lastActive = widget.data['lastActive'] as Timestamp?;
    final emergencyReports = widget.data['emergencyReports'] ?? 0;
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
  final Timestamp? createdAt;
  final Timestamp? lastActive;
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
  final Timestamp? createdAt;
  final Timestamp? lastLogin;
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Never';
    return DateFormat('MMM d, y - h:mm a').format(timestamp.toDate());
  }

  // Get time since last activity for radar users
  String _getTimeSinceLastActivity(Timestamp? lastLogin) {
    if (lastLogin == null) return 'Never active';
    
    final now = DateTime.now();
    final lastActivity = lastLogin.toDate();
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
                  color: statusIndicator!.withOpacity(0.5),
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
        color: isAdmin ? Colors.blue[50] : Colors.green[50],
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
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
        color: isAdmin ? Colors.blue[50] : Colors.grey[100],
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
            DropdownMenuItem(value: 'moderator', child: Text('MODERATOR')),
            DropdownMenuItem(value: 'admin', child: Text('ADMIN')),
          ],
        ),
      ),
    );
  }
}