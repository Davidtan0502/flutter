import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  DateTime? _selectedDate;
  final List<String> _selectedNotifications = [];
  bool _isMultiSelectMode = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasNewUpdates = false;
  List<QueryDocumentSnapshot> _currentNotifications = [];
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
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

  void _startNotificationListener() {
    _notificationSubscription = FirebaseFirestore.instance
        .collection('incidents')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      // Check for new notifications
      if (mounted) {
        setState(() {
          _unreadCount = snapshot.docs
              .where((doc) => (doc.data() as Map<String, dynamic>)['read'] != true)
              .length;
        });
      }
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return const Color(0xFF4CAF50);
      case 'in progress':
        return const Color(0xFF2196F3);
      case 'pending':
        return const Color(0xFFFF9800);
      case 'under review':
        return const Color(0xFF9C27B0);
      case 'declined':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Icons.check_circle;
      case 'in progress':
        return Icons.autorenew;
      case 'pending':
        return Icons.access_time;
      case 'under review':
        return Icons.visibility;
      case 'declined':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _hasNewUpdates = false;
    });
    
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _isLoading = false;
    });
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
      if (_selectedNotifications.length == _currentNotifications.length) {
        // If all are selected, deselect all
        _selectedNotifications.clear();
        _isMultiSelectMode = false;
      } else {
        // Select all current notifications
        _selectedNotifications.clear();
        _selectedNotifications.addAll(_currentNotifications.map((doc) => doc.id));
        _isMultiSelectMode = true;
      }
    });
  }

  Future<void> _markAsRead(List<String> ids) async {
    if (ids.isEmpty) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final previousStates = <String, bool>{};

      for (final id in ids) {
        final docRef = FirebaseFirestore.instance.collection('incidents').doc(id);
        final snapshot = await docRef.get();
        previousStates[id] = snapshot['read'] == true; // save old state

        batch.update(docRef, {
          'read': true,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked ${ids.length} as read'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                final undoBatch = FirebaseFirestore.instance.batch();
                for (final entry in previousStates.entries) {
                  final docRef = FirebaseFirestore.instance.collection('incidents').doc(entry.key);
                  undoBatch.update(docRef, {'read': entry.value});
                }
                await undoBatch.commit();
              },
            ),
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
            backgroundColor: Colors.red,
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
        content: Text('Are you sure you want to delete ${ids.length} notification${ids.length > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final id in ids) {
        final docRef = FirebaseFirestore.instance.collection('incidents').doc(id);
        batch.delete(docRef);
      }
      
      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${ids.length} notification${ids.length > 1 ? 's' : ''}'),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {
        _selectedNotifications.clear();
        _isMultiSelectMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('incidents')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications cleared'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear notifications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('incidents')
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark all as read: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showNotificationDetails(Map<String, dynamic> data, String docId) async {
    final timestamp = data['timestamp'] as Timestamp?;
    final time = timestamp != null
        ? DateFormat('MMM d, yyyy h:mm a').format(timestamp.toDate())
        : 'Unknown time';

    final location = data['address']?.toString() ?? 'Unknown location';
    final incidentType = data['incidentType']?.toString() ?? 'Unknown type';
    final reporter = data['name']?.toString() ?? 'Anonymous';
    final status = data['status']?.toString() ?? 'pending';
    final description = data['description']?.toString() ?? 'No description provided';
    final priority = data['priority']?.toString() ?? 'medium';

    // Mark as read when viewing details
    if (data['read'] != true) {
      await FirebaseFirestore.instance
          .collection('incidents')
          .doc(docId)
          .update({
            'read': true,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(incidentType.toUpperCase()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(Icons.access_time, time),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.location_on, location),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.person, reporter),
              const SizedBox(height: 8),
              _buildStatusRow(status),
              const SizedBox(height: 8),
              _buildPriorityRow(priority),
              const SizedBox(height: 16),
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(description),
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

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _buildStatusRow(String status) {
    final statusColor = _getStatusColor(status);
    return Row(
      children: [
        Icon(Icons.circle, size: 20, color: statusColor),
        const SizedBox(width: 8),
        Text('Status: '),
        Text(
          status.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityRow(String priority) {
    Color priorityColor;
    switch (priority.toLowerCase()) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      case 'low':
        priorityColor = Colors.green;
        break;
      default:
        priorityColor = Colors.grey;
    }

    return Row(
      children: [
        Icon(Icons.flag, size: 20, color: priorityColor),
        const SizedBox(width: 8),
        const Text('Priority: '),
        Text(
          priority.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: priorityColor,
          ),
        ),
      ],
    );
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
              Color(0xFFF8F9FA),
              Color(0xFFE9ECEF),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildFilterSection(),
              const SizedBox(height: 16),
              if (_isMultiSelectMode) _buildBatchActions(),
              const SizedBox(height: 16),
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
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: widget.onMenuPressed,
      ),
      title: Row(
        children: [
          const Text('NOTIFICATIONS'),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
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
            icon: const Icon(Icons.select_all, color: Colors.white),
            onPressed: _selectAllNotifications,
            tooltip: 'Select all',
          ),
        IconButton(
          icon: Icon(
            _isMultiSelectMode ? Icons.cancel : Icons.select_all,
            color: Colors.white,
          ),
          onPressed: _toggleMultiSelectMode,
          tooltip: _isMultiSelectMode ? 'Cancel selection' : 'Select multiple',
        ),
        if (_hasNewUpdates)
          IconButton(
            icon: const Icon(Icons.new_releases, color: Colors.amber),
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
              child: Text('Mark all as read'),
            ),
            const PopupMenuItem(
              value: 'clear_all',
              child: Text('Clear all notifications'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Hero(
      tag: 'notification_search_bar',
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(30),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search notifications by location or type...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: Icon(Icons.search, color: Colors.blue[800]),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.blue[800]),
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
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Unread'),
              selected: _selectedFilter == 'unread',
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = 'unread';
                });
              },
              selectedColor: Colors.blue[800],
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: _selectedFilter == 'unread' ? Colors.white : Colors.black87,
              ),
            ),
            FilterChip(
              label: const Text('All'),
              selected: _selectedFilter == 'all',
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = 'all';
                });
              },
              selectedColor: Colors.blue[800],
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: _selectedFilter == 'all' ? Colors.white : Colors.black87,
              ),
            ),
            FilterChip(
              label: const Text('High Priority'),
              selected: _selectedFilter == 'high',
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = 'high';
                });
              },
              selectedColor: Colors.blue[800],
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: _selectedFilter == 'high' ? Colors.white : Colors.black87,
              ),
            ),
            FilterChip(
              label: const Text('Today'),
              selected: _selectedFilter == 'today',
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = 'today';
                });
              },
              selectedColor: Colors.blue[800],
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: _selectedFilter == 'today' ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBatchActions() {
    final allSelected = _selectedNotifications.length == _currentNotifications.length;
    
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              '${_selectedNotifications.length} selected',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                allSelected ? Icons.deselect : Icons.select_all,
                color: Colors.blue[800],
              ),
              onPressed: _selectAllNotifications,
              tooltip: allSelected ? 'Deselect all' : 'Select all',
            ),
            IconButton(
              icon: const Icon(Icons.mark_email_read, color: Colors.green),
              onPressed: () => _markAsRead(_selectedNotifications),
              tooltip: 'Mark as read',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteNotifications(_selectedNotifications),
              tooltip: 'Delete selected',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('incidents')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _buildLoadingState();
        }

        final filteredDocs = _filterNotifications(snapshot.data!.docs);
        _currentNotifications = filteredDocs;

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: filteredDocs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['read'] == true;
              
              return _NotificationCard(
                data: data,
                docId: doc.id,
                getStatusColor: _getStatusColor,
                getStatusIcon: _getStatusIcon,
                isSelectable: _isMultiSelectMode,
                isSelected: _selectedNotifications.contains(doc.id),
                isRead: isRead,
                onSelect: () => _selectNotification(doc.id),
                onTap: () => _showNotificationDetails(data, doc.id),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
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
          Icon(Icons.notifications_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No notifications found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
                _selectedDate = null;
              });
            },
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterNotifications(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));
    
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final location = (data['address'] ?? '').toString().toLowerCase();
      final type = (data['incidentType'] ?? '').toString().toLowerCase();
      final status = (data['status'] ?? 'pending').toString().toLowerCase();
      final priority = (data['priority'] ?? 'medium').toString().toLowerCase();
      final timestamp = data['timestamp'] as Timestamp?;
      final isRead = data['read'] == true;
      
      // Apply filter logic
      if (_selectedFilter == 'unread' && isRead) {
        return false;
      } else if (_selectedFilter == 'high' && priority != 'high') {
        return false;
      } else if (_selectedFilter == 'today' && timestamp != null) {
        final reportTime = timestamp.toDate();
        if (!DateUtils.isSameDay(reportTime, now)) {
          return false;
        }
      }
      
      // Apply search filter
      return _searchQuery.isEmpty ||
          location.contains(_searchQuery) ||
          type.contains(_searchQuery);
    }).toList();
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _refreshData,
      backgroundColor: Colors.blue,
      child: const Icon(Icons.refresh, color: Colors.white),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final Color Function(String) getStatusColor;
  final IconData Function(String) getStatusIcon;
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
    this.isSelectable = false,
    this.isSelected = false,
    this.isRead = false,
    required this.onSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = data['timestamp'] as Timestamp?;
    final time = timestamp != null
        ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
        : 'Unknown time';

    final location = data['address']?.toString() ?? 'Unknown location';
    final incidentType = data['incidentType']?.toString() ?? 'Unknown type';
    final reporter = data['name']?.toString() ?? 'Anonymous';
    final status = data['status']?.toString() ?? 'pending';
    final iconColor = _getIncidentColor(data['incidentType']);
    final statusColor = getStatusColor(status);

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: isSelectable ? onSelect : onTap,
      onLongPress: () {
        if (!isSelectable) {
          onSelect();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2FD) : (isRead ? Colors.grey[50] : Colors.white),
          borderRadius: BorderRadius.circular(15),
          border: isSelected 
              ? Border.all(color: const Color(0xFF2C5282), width: 2)
              : Border.all(color: Colors.grey[100]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (status == 'pending' && !isRead)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(15),
                      bottomLeft: Radius.circular(15),
                    ),
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
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
                      Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? const Color(0xFF2C5282) : Colors.grey[400],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications,
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
                          color: isRead ? Colors.grey[600] : const Color(0xFF2D3436),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                /// LOCATION
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                /// REPORTER
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      reporter,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                /// DESCRIPTION
                if (data['description'] != null)
                  Text(
                    data['description']!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isRead ? Colors.grey[600] : const Color(0xFF2D3436),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 8),

                /// STATUS BADGE
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getIncidentColor(String? incidentType) {
    switch (incidentType?.toLowerCase()) {
      case 'fire':
        return const Color(0xFFF44336);
      case 'accident':
        return const Color(0xFFFF9800);
      case 'flood':
        return const Color(0xFF2196F3);
      case 'medical':
        return const Color(0xFFE91E63);
      case 'crime':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF607D8B);
    }
  }
}