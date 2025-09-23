import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/login/admin/admin_incident_report_screen.dart';


class RadarAppUserCard extends StatefulWidget {
  final QueryDocumentSnapshot user;
  final Map<String, dynamic> data;
  final String searchQuery;

  const RadarAppUserCard({
    super.key, 
    required this.user, 
    required this.data,
    this.searchQuery = '',
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
      print('Error loading incidents: $e');
    } finally {
      setState(() => _loadingIncidents = false);
    }
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

  bool _isUserOnline(Timestamp? lastActive) {
    if (lastActive == null) return false;
    final fifteenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 15));
    return lastActive.toDate().isAfter(fifteenMinutesAgo);
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty || text.isEmpty) {
      return Text(
        text.isNotEmpty ? text : 'N/A',
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    final textLower = text.toLowerCase();
    final queryLower = query.toLowerCase();
    
    if (!textLower.contains(queryLower)) {
      return Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    final matches = <TextSpan>[];
    int start = 0;
    int index = textLower.indexOf(queryLower);

    while (index >= 0) {
      if (index > start) {
        matches.add(TextSpan(
          text: text.substring(start, index),
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Colors.black,
          ),
        ));
      }

      matches.add(TextSpan(
        text: text.substring(index, index + queryLower.length),
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: Colors.blue,
          backgroundColor: Color(0xFFFFEB3B),
        ),
      ));

      start = index + queryLower.length;
      index = textLower.indexOf(queryLower, start);
    }

    if (start < text.length) {
      matches.add(TextSpan(
        text: text.substring(start),
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: Colors.black,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: matches),
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.data['email'] ?? 'No email';
    final name = widget.data['name'] ?? 'No name';
    final role = widget.data['role'] ?? 'user';
    final createdAt = widget.data['createdAt'] as Timestamp?;
    final lastActive = widget.data['lastActive'] as Timestamp?;
    final emergencyReports = widget.data['emergencyReports'] ?? 0;
    final isOnline = _isUserOnline(lastActive);

    return UserCardTemplate(
      email: email,
      name: name,
      role: role,
      createdAt: createdAt,
      lastLogin: lastActive,
      additionalInfo: 'Emergencies: $emergencyReports • Incidents: ${_loadingIncidents ? '...' : _incidentCount}',
      isUpdating: false,
      onRoleChanged: null,
      showRoleDropdown: false,
      statusIndicator: isOnline ? Colors.green : Colors.grey,
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
          icon: const Icon(Icons.info, size: 18),
          onPressed: () => _viewUserDetails(context),
          tooltip: 'View details',
        ),
      ],
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

// Updated UserCardTemplate with fixed DropdownButton
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (statusIndicator != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusIndicator,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: role == 'admin' ? Colors.blue[50] : Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                  size: 20,
                  color: role == 'admin' ? Colors.blue[800] : Colors.green[800],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                    if (name != null && name!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        name!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
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
                        'Last active: ${_formatTimestamp(lastLogin)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                    if (additionalInfo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        additionalInfo!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isUpdating) 
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else 
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showRoleDropdown) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: role == 'admin' ? Colors.blue[50] : Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: role == 'admin' ? Colors.blue[200]! : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: role,
                            icon: const Icon(Icons.arrow_drop_down, size: 16),
                            dropdownColor: Theme.of(context).colorScheme.surface,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: role == 'admin' ? Colors.blue[800] : Theme.of(context).colorScheme.onSurface,
                            ),
                            onChanged: onRoleChanged,
                            // FIXED: No duplicate values
                            items: const [
                              DropdownMenuItem(value: 'viewer', child: Text('VIEWER')),
                              DropdownMenuItem(value: 'moderator', child: Text('MODERATOR')),
                              DropdownMenuItem(value: 'admin', child: Text('ADMIN')),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (additionalActions != null) ...additionalActions!,
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}