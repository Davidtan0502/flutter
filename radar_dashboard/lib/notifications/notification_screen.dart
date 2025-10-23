import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class NotificationScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const NotificationScreen({super.key, required this.onMenuPressed});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'unread';
  final List<String> _selectedNotifications = [];
  bool _isMultiSelectMode = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _hasNewUpdates = false;
  List<Map<String, dynamic>> _currentNotifications = [];
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;
  int _unreadCount = 0;
  bool _isLoading = true;

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
    
    // Start listening to notifications
    _startNotificationListener();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _startNotificationListener() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initial fetch
      final initialResponse = await _supabase
          .from('incidents')
          .select()
          .order('timestamp', ascending: false);

      if (mounted) {
        setState(() {
          _currentNotifications = List<Map<String, dynamic>>.from(initialResponse);
          _unreadCount = _currentNotifications
              .where((incident) => incident['read'] != true)
              .length;
          _isLoading = false;
        });
      }

      // Real-time subscription
      _notificationSubscription = _supabase
          .from('incidents')
          .stream(primaryKey: ['id'])
          .order('timestamp', ascending: false)
          .listen((List<Map<String, dynamic>> incidents) {
        if (mounted) {
          setState(() {
            _currentNotifications = incidents;
            _unreadCount = incidents
                .where((incident) => incident['read'] != true)
                .length;
            _isLoading = false;
          });
        }
      }, onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        debugPrint('Notification stream error: $error');
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error fetching notifications: $e');
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return const Color(0xFF10B981);
      case 'in progress':
        return const Color(0xFF3B82F6);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'under review':
        return const Color(0xFF8B5CF6);
      case 'declined':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Icons.check_circle_rounded;
      case 'in progress':
        return Icons.autorenew_rounded;
      case 'pending':
        return Icons.access_time_rounded;
      case 'under review':
        return Icons.visibility_rounded;
      case 'declined':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _getIncidentColor(String? incidentType) {
    switch (incidentType?.toLowerCase()) {
      case 'fire':
        return const Color(0xFFDC2626);
      case 'accident':
        return const Color(0xFFEA580C);
      case 'flood':
        return const Color(0xFF2563EB);
      case 'medical':
        return const Color(0xFFDB2777);
      case 'crime':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF475569);
    }
  }

  IconData _getIncidentIcon(String? incidentType) {
    switch (incidentType?.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'accident':
        return Icons.car_crash_rounded;
      case 'flood':
        return Icons.water_damage_rounded;
      case 'medical':
        return Icons.medical_services_rounded;
      case 'crime':
        return Icons.security_rounded;
      default:
        return Icons.warning_rounded;
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _hasNewUpdates = false;
      _isLoading = true;
    });
    
    try {
      // Force refresh by re-fetching data
      final response = await _supabase
          .from('incidents')
          .select()
          .order('timestamp', ascending: false);

      if (mounted) {
        setState(() {
          _currentNotifications = List<Map<String, dynamic>>.from(response);
          _unreadCount = _currentNotifications
              .where((incident) => incident['read'] != true)
              .length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error refreshing data: $e');
    }
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedNotifications.clear();
      }
    });
  }

  void _selectNotification(String id) {
    setState(() {
      if (_selectedNotifications.contains(id)) {
        _selectedNotifications.remove(id);
      } else {
        _selectedNotifications.add(id);
      }
      
      if (_selectedNotifications.isEmpty) {
        _isMultiSelectMode = false;
      }
    });
  }

  void _selectAllNotifications() {
    setState(() {
      final filteredNotifications = _getFilteredNotifications();
      if (_selectedNotifications.length == filteredNotifications.length) {
        // If all are selected, deselect all
        _selectedNotifications.clear();
        _isMultiSelectMode = false;
      } else {
        // Select all current filtered notifications
        _selectedNotifications.clear();
        _selectedNotifications.addAll(filteredNotifications.map((incident) => incident['id'].toString()));
        _isMultiSelectMode = true;
      }
    });
  }

  Future<void> _markAsRead(List<String> ids, {bool showSnackbar = true}) async {
    if (ids.isEmpty) return;

    try {
      // Update all selected incidents to read
      for (final id in ids) {
        await _supabase
            .from('incidents')
            .update({
              'read': true,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', id);
      }

      if (mounted && showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked ${ids.length} notification${ids.length > 1 ? 's' : ''} as read'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      setState(() {
        _selectedNotifications.clear();
        _isMultiSelectMode = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as read: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _markAsUnread(List<String> ids) async {
    if (ids.isEmpty) return;

    try {
      for (final id in ids) {
        await _supabase
            .from('incidents')
            .update({
              'read': false,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked ${ids.length} notification${ids.length > 1 ? 's' : ''} as unread'),
            backgroundColor: const Color(0xFF3B82F6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      setState(() {
        _selectedNotifications.clear();
        _isMultiSelectMode = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as unread: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotifications(List<String> ids) async {
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${ids.length} notification${ids.length > 1 ? 's' : ''}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      for (final id in ids) {
        await _supabase
            .from('incidents')
            .delete()
            .eq('id', id);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${ids.length} notification${ids.length > 1 ? 's' : ''}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      
      setState(() {
        _selectedNotifications.clear();
        _isMultiSelectMode = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Get all incident IDs first
      final response = await _supabase
          .from('incidents')
          .select('id');

      // Delete all incidents
      for (final incident in response) {
        await _supabase
            .from('incidents')
            .delete()
            .eq('id', incident['id']);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All notifications cleared'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear notifications: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _supabase
          .from('incidents')
          .update({
            'read': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('read', false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All notifications marked as read'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark all as read: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showNotificationDetails(Map<String, dynamic> data, String docId) async {
    final timestamp = data['timestamp'];
    DateTime? reportTime;
    
    if (timestamp is DateTime) {
      reportTime = timestamp;
    } else if (timestamp is String) {
      reportTime = DateTime.tryParse(timestamp);
    }
    
    final time = reportTime != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(reportTime)
        : 'Unknown time';

    final location = data['address']?.toString() ?? 'Unknown location';
    final landmark = data['landmark']?.toString() ?? '';
    final incidentType = data['incident_type']?.toString() ?? 'Unknown type';
    final reporter = data['name']?.toString() ?? 'Anonymous';
    final contactNumber = data['contact_number']?.toString();
    final status = data['status']?.toString() ?? 'pending';
    final description = data['description']?.toString() ?? 'No description provided';
    final imageUrls = data['image_urls'] as List<dynamic>? ?? [];
    final isRead = data['read'] == true;

    // Mark as read when viewing details if it's unread
    if (!isRead) {
      await _markAsRead([docId], showSnackbar: false);
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _getIncidentColor(incidentType),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIncidentIcon(incidentType),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            incidentType.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            location,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getStatusIcon(status), size: 16, color: _getStatusColor(status)),
                            const SizedBox(width: 8),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Details Grid
                      _buildDetailGrid([
                        _buildDetailItem(Icons.access_time_rounded, 'Reported', time),
                        _buildDetailItem(Icons.person_rounded, 'Reporter', reporter),
                        if (contactNumber != null && contactNumber.isNotEmpty)
                          _buildDetailItem(Icons.phone_rounded, 'Contact', contactNumber),
                        if (landmark.isNotEmpty)
                          _buildDetailItem(Icons.place_rounded, 'Landmark', "Near $landmark"),
                      ]),
                      
                      const SizedBox(height: 24),
                      
                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                      
                      if (imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Attached Images',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: imageUrls.length,
                            itemBuilder: (context, index) {
                              final imageUrl = imageUrls[index]?.toString() ?? '';
                              return Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: const Color(0xFFF3F4F6),
                                ),
                                child: imageUrl.isNotEmpty 
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Center(
                                              child: Icon(Icons.broken_image_rounded, color: Color(0xFF9CA3AF)),
                                            );
                                          },
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                    : null,
                                                strokeWidth: 2,
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(Icons.image_not_supported_rounded, color: Color(0xFF9CA3AF)),
                                      ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailGrid(List<Widget> children) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: children,
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredNotifications() {
    final now = DateTime.now();
    
    return _currentNotifications.where((incident) {
      final location = (incident['address'] ?? '').toString().toLowerCase();
      final landmark = (incident['landmark'] ?? '').toString().toLowerCase();
      final type = (incident['incident_type'] ?? '').toString().toLowerCase();
      final timestamp = incident['timestamp'];
      final isRead = incident['read'] == true;
      
      DateTime? reportTime;
      if (timestamp is DateTime) {
        reportTime = timestamp;
      } else if (timestamp is String) {
        reportTime = DateTime.tryParse(timestamp);
      }
      
      // Apply filter logic
      switch (_selectedFilter) {
        case 'unread':
          if (isRead) return false;
          break;
        case 'today':
          if (reportTime == null || !_isSameDay(reportTime, now)) return false;
          break;
        case 'all':
          // No additional filtering needed
          break;
      }
      
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        if (!location.contains(_searchQuery) && 
            !landmark.contains(_searchQuery) && 
            !type.contains(_searchQuery)) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFF1F5F9),
            ],
          ),
        ),
        child: Column(
          children: [
            // Search and Filters Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildFilterSection(),
                ],
              ),
            ),
            
            // Notifications List
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (_isMultiSelectMode) ...[
                      _buildBatchActions(),
                      const SizedBox(height: 16),
                    ],
                    Expanded(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildNotificationList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Colors.white),
        onPressed: widget.onMenuPressed,
      ),
      title: Row(
        children: [
          const Text('NOTIFICATIONS'),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade400,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: const Color(0xFF2C5282),
      elevation: 4,
      centerTitle: true,
      actions: [
        if (_isMultiSelectMode)
          IconButton(
            icon: const Icon(Icons.select_all_rounded, color: Colors.white),
            onPressed: _selectAllNotifications,
            tooltip: 'Select all',
          ),
        IconButton(
          icon: Icon(
            _isMultiSelectMode ? Icons.cancel_rounded : Icons.select_all_rounded,
            color: Colors.white,
          ),
          onPressed: _toggleMultiSelectMode,
          tooltip: _isMultiSelectMode ? 'Cancel selection' : 'Select multiple',
        ),
        if (_hasNewUpdates)
          IconButton(
            icon: Badge(
              smallSize: 8,
              backgroundColor: Colors.amber,
              child: const Icon(Icons.new_releases_rounded, color: Colors.white),
            ),
            onPressed: _refreshData,
            tooltip: 'New updates available',
          ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'mark_all_read') {
              _markAllAsRead();
            } else if (value == 'clear_all') {
              _clearAllNotifications();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'mark_all_read',
              child: Row(
                children: [
                  Icon(Icons.mark_email_read_rounded, color: Color(0xFF10B981)),
                  SizedBox(width: 12),
                  Text('Mark all as read'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear_all',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
                  SizedBox(width: 12),
                  Text('Clear all notifications'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search notifications by location, landmark or type...',
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.blue.shade700),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.blue.shade700),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('Unread', 'unread'),
          const SizedBox(width: 8),
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Today', 'today'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF374151),
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: Colors.blue.shade600,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.blue.shade600 : const Color(0xFFE5E7EB),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    );
  }

  Widget _buildBatchActions() {
    final filteredNotifications = _getFilteredNotifications();
    final allSelected = _selectedNotifications.length == filteredNotifications.length && filteredNotifications.isNotEmpty;
    final hasUnreadSelected = _selectedNotifications.any((id) {
      final incident = _currentNotifications.firstWhere((incident) => incident['id'].toString() == id);
      return incident['read'] != true;
    });
    final hasReadSelected = _selectedNotifications.any((id) {
      final incident = _currentNotifications.firstWhere((incident) => incident['id'].toString() == id);
      return incident['read'] == true;
    });
    
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Text(
                _selectedNotifications.length.toString(),
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_selectedNotifications.length} selected',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF374151),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                color: const Color(0xFF6B7280),
              ),
              onPressed: _selectAllNotifications,
              tooltip: allSelected ? 'Deselect all' : 'Select all',
            ),
            if (hasUnreadSelected)
              IconButton(
                icon: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF10B981)),
                onPressed: () => _markAsRead(_selectedNotifications),
                tooltip: 'Mark as read',
              ),
            if (hasReadSelected)
              IconButton(
                icon: const Icon(Icons.markunread_rounded, color: Color(0xFF3B82F6)),
                onPressed: () => _markAsUnread(_selectedNotifications),
                tooltip: 'Mark as unread',
              ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
              onPressed: () => _deleteNotifications(_selectedNotifications),
              tooltip: 'Delete selected',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    final filteredNotifications = _getFilteredNotifications();

    if (filteredNotifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      backgroundColor: Colors.white,
      color: Colors.blue.shade600,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 20, top: 8),
        itemCount: filteredNotifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final incident = filteredNotifications[index];
          final isRead = incident['read'] == true;
          
          return _NotificationCard(
            data: incident,
            docId: incident['id'].toString(),
            getStatusColor: _getStatusColor,
            getStatusIcon: _getStatusIcon,
            getIncidentColor: _getIncidentColor,
            getIncidentIcon: _getIncidentIcon,
            isSelectable: _isMultiSelectMode,
            isSelected: _selectedNotifications.contains(incident['id'].toString()),
            isRead: isRead,
            onSelect: () => _selectNotification(incident['id'].toString()),
            onTap: () => _showNotificationDetails(incident, incident['id'].toString()),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20, top: 8),
      itemCount: 6,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF3F4F6),
      highlightColor: const Color(0xFFE5E7EB),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        height: 140,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_rounded,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          const Text(
            'No notifications found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
                _selectedFilter = 'all';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _refreshData,
      backgroundColor: Colors.blue.shade600,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.refresh_rounded),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final Color Function(String) getStatusColor;
  final IconData Function(String) getStatusIcon;
  final Color Function(String?) getIncidentColor;
  final IconData Function(String?) getIncidentIcon;
  final bool isSelectable;
  final bool isSelected;
  final bool isRead;
  final VoidCallback onSelect;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.data,
    required this.docId,
    required this.getStatusColor,
    required this.getStatusIcon,
    required this.getIncidentColor,
    required this.getIncidentIcon,
    this.isSelectable = false,
    this.isSelected = false,
    this.isRead = false,
    required this.onSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = data['timestamp'];
    DateTime? reportTime;
    
    if (timestamp is DateTime) {
      reportTime = timestamp;
    } else if (timestamp is String) {
      reportTime = DateTime.tryParse(timestamp);
    }
    
    final time = reportTime != null
        ? DateFormat('MMM d, h:mm a').format(reportTime)
        : 'Unknown time';

    final location = data['address']?.toString() ?? 'Unknown location';
    final landmark = data['landmark']?.toString() ?? '';
    final incidentType = data['incident_type']?.toString() ?? 'Unknown type';
    final reporter = data['name']?.toString() ?? 'Anonymous';
    final status = data['status']?.toString() ?? 'pending';
    final iconColor = getIncidentColor(data['incident_type']);
    final statusColor = getStatusColor(status);
    final hasImages = (data['image_urls'] as List<dynamic>? ?? []).isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isSelectable ? onSelect : onTap,
      onLongPress: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : (isRead ? Colors.white : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
              ? Border.all(color: Colors.blue.shade500, width: 2)
              : Border.all(color: const Color(0xFFF3F4F6), width: 2),
          boxShadow: [
            if (!isRead)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Unread indicator
            if (!isRead)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red.shade500,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// HEADER
                Row(
                  children: [
                    if (isSelectable)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.shade500 : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.blue.shade500 : const Color(0xFFD1D5DB),
                          ),
                        ),
                        child: Icon(
                          isSelected ? Icons.check_rounded : Icons.circle_outlined,
                          size: 20,
                          color: isSelected ? Colors.white : const Color(0xFFD1D5DB),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconColor.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          getIncidentIcon(data['incident_type']),
                          color: iconColor,
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        incidentType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isRead ? const Color(0xFF6B7280) : const Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: isRead ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                /// LOCATION & LANDMARK
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 16, color: const Color(0xFF6B7280)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 14,
                              color: isRead ? const Color(0xFF9CA3AF) : const Color(0xFF374151),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (landmark.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place_rounded, size: 14, color: const Color(0xFF9CA3AF)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Near $landmark",
                              style: TextStyle(
                                fontSize: 13,
                                color: isRead ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                /// REPORTER & IMAGES
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 16, color: const Color(0xFF6B7280)),
                    const SizedBox(width: 6),
                    Text(
                      reporter,
                      style: TextStyle(
                        fontSize: 14,
                        color: isRead ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                    const Spacer(),
                    if (hasImages)
                      Row(
                        children: [
                          Icon(Icons.image_rounded, size: 16, color: const Color(0xFF6B7280)),
                          const SizedBox(width: 4),
                          Text(
                            '${(data['image_urls'] as List<dynamic>? ?? []).length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                /// DESCRIPTION
                if (data['description'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    data['description']!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isRead ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                /// STATUS & ACTIONS
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            getStatusIcon(status),
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!isSelectable)
                      IconButton(
                        icon: Icon(
                          Icons.visibility_rounded,
                          size: 18,
                          color: const Color(0xFF6B7280),
                        ),
                        onPressed: onTap,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'View details',
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}