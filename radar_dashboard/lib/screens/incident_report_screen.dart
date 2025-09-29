import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shimmer/shimmer.dart';

// Constants and Configuration
class IncidentReportConstants {
  static const Map<String, Color> colorScheme = {
    'primary': Color(0xFF2C5282),
    'primaryLight': Color(0xFFE1F5FF),
    'primaryDark': Color(0xFF1A365D),
    'secondary': Color(0xFF99CEFF),
    'success': Color(0xFF4CAF50),
    'warning': Color(0xFFFF9800),
    'error': Color(0xFFF44336),
    'info': Color(0xFF2196F3),
    'purple': Color(0xFF9C27B0),
  };

  static const List<String> statusOptions = [
    'pending',
    'in progress',
    'resolved',
    'under review',
    'declined'
  ];

  static const List<String> filterOptions = ['recent', 'all'];
}

// Data Models
class IncidentData {
  final String id;
  final String? incidentType;
  final String? address;
  final String? name;
  final String? contactNumber;
  final String? description;
  final String status;
  final Timestamp? timestamp;
  final List<dynamic> imageUrls;
  final List<dynamic> statusUpdates;

  IncidentData({
    required this.id,
    required this.incidentType,
    required this.address,
    required this.name,
    required this.contactNumber,
    required this.description,
    required this.status,
    required this.timestamp,
    required this.imageUrls,
    required this.statusUpdates,
  });

  factory IncidentData.fromDocument(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IncidentData(
      id: doc.id,
      incidentType: data['incidentType']?.toString(),
      address: data['address']?.toString(),
      name: data['name']?.toString(),
      contactNumber: data['contactNumber']?.toString(),
      description: data['description']?.toString(),
      status: (data['status'] ?? 'pending').toString(),
      timestamp: data['timestamp'] as Timestamp?,
      imageUrls: data['imageUrls'] as List<dynamic>? ?? [],
      statusUpdates: data['statusUpdates'] as List<dynamic>? ?? [],
    );
  }
}

// Service Classes
class IncidentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<QuerySnapshot> getIncidentsStream() {
    return _firestore
        .collection('incidents')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  static Future<void> deleteIncident(String id) async {
    await _firestore.collection('incidents').doc(id).delete();
  }

  static Future<void> updateIncidentStatus(
    String id, {
    required String status,
    required String note,
    required String updatedBy,
  }) async {
    final doc = await _firestore.collection('incidents').doc(id).get();
    if (!doc.exists) throw Exception("Document does not exist");

    final currentData = doc.data() as Map<String, dynamic>;
    final currentUpdates = List<Map<String, dynamic>>.from(
      currentData['statusUpdates'] ?? [],
    );

    final newStatusUpdate = {
      'status': status,
      'timestamp': Timestamp.now(),
      'note': note,
      'updatedBy': updatedBy,
    };

    currentUpdates.add(newStatusUpdate);

    await _firestore.collection('incidents').doc(id).update({
      'status': status,
      'statusUpdates': currentUpdates,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> batchUpdateStatus(
    List<String> ids,
    String status,
  ) async {
    final batch = _firestore.batch();
    final updateTime = FieldValue.serverTimestamp();

    for (final id in ids) {
      final docRef = _firestore.collection('incidents').doc(id);
      batch.update(docRef, {
        'status': status,
        'lastUpdated': updateTime,
      });
    }

    await batch.commit();
  }

  static Future<void> batchDeleteIncidents(List<String> ids) async {
    final batch = _firestore.batch();
    for (final id in ids) {
      final docRef = _firestore.collection('incidents').doc(id);
      batch.delete(docRef);
    }
    await batch.commit();
  }
}

class StyleService {
  static Map<String, dynamic> getStatusStyle(String status) {
    final statusLower = status.toLowerCase();
    final colors = IncidentReportConstants.colorScheme;

    final Map<String, Map<String, dynamic>> styles = {
      'resolved': {
        'color': colors['success']!,
        'icon': Icons.check_circle_rounded,
        'bgColor': colors['success']!.withOpacity(0.1),
        'label': 'Resolved',
      },
      'in progress': {
        'color': colors['info']!,
        'icon': Icons.autorenew_rounded,
        'bgColor': colors['info']!.withOpacity(0.1),
        'label': 'In Progress',
      },
      'pending': {
        'color': colors['warning']!,
        'icon': Icons.access_time_rounded,
        'bgColor': colors['warning']!.withOpacity(0.1),
        'label': 'Pending',
      },
      'under review': {
        'color': colors['purple']!,
        'icon': Icons.visibility_rounded,
        'bgColor': colors['purple']!.withOpacity(0.1),
        'label': 'Under Review',
      },
      'declined': {
        'color': colors['error']!,
        'icon': Icons.cancel_rounded,
        'bgColor': colors['error']!.withOpacity(0.1),
        'label': 'Declined',
      },
    };

    return styles[statusLower] ?? {
      'color': Colors.grey,
      'icon': Icons.help_outline_rounded,
      'bgColor': Colors.grey.withOpacity(0.1),
      'label': 'Unknown',
    };
  }

  static Map<String, dynamic> getIncidentStyle(String? incidentType) {
    final typeLower = incidentType?.toLowerCase() ?? 'unknown';
    final colors = IncidentReportConstants.colorScheme;

    final Map<String, Map<String, dynamic>> styles = {
      'fire': {
        'color': colors['error']!,
        'icon': Icons.local_fire_department_rounded,
        'gradient': LinearGradient(
          colors: [colors['error']!, const Color(0xFFFF6B35)],
        ),
      },
      'accident': {
        'color': colors['warning']!,
        'icon': Icons.car_crash_rounded,
        'gradient': LinearGradient(
          colors: [colors['warning']!, const Color(0xFFFFB74D)],
        ),
      },
      'flood': {
        'color': colors['info']!,
        'icon': Icons.water_damage_rounded,
        'gradient': LinearGradient(
          colors: [colors['info']!, const Color(0xFF4FC3F7)],
        ),
      },
      'medical': {
        'color': const Color(0xFFE91E63),
        'icon': Icons.medical_services_rounded,
        'gradient': LinearGradient(
          colors: [const Color(0xFFE91E63), const Color(0xFFF48FB1)],
        ),
      },
      'crime': {
        'color': colors['purple']!,
        'icon': Icons.security_rounded,
        'gradient': LinearGradient(
          colors: [colors['purple']!, const Color(0xFFCE93D8)],
        ),
      },
    };

    return styles[typeLower] ?? {
      'color': Colors.grey,
      'icon': Icons.warning_rounded,
      'gradient': LinearGradient(
        colors: [Colors.grey, Colors.grey.shade400],
      ),
    };
  }
}

class IncidentReportScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;
  final String userRole;

  const IncidentReportScreen({
    super.key,
    required this.onMenuPressed,
    required this.userRole,
  });

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _selectedIncidents = [];
  final List<QueryDocumentSnapshot> _currentDocs = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String _searchQuery = '';
  String _selectedFilter = 'recent';
  DateTime? _selectedDate;
  bool _isMultiSelectMode = false;
  bool _isLoading = false;
  bool _hasNewUpdates = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _initializeControllers() {
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutQuart,
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  void _disposeControllers() {
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
  }

  // Selection Management
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) _selectedIncidents.clear();
    });
  }

  void _selectIncident(String id) {
    setState(() {
      if (_selectedIncidents.contains(id)) {
        _selectedIncidents.remove(id);
      } else {
        _selectedIncidents.add(id);
      }
      if (_selectedIncidents.isEmpty) _isMultiSelectMode = false;
    });
  }

  void _selectAllIncidents() {
    setState(() {
      if (_selectedIncidents.length == _currentDocs.length) {
        _selectedIncidents.clear();
        _isMultiSelectMode = false;
      } else {
        _selectedIncidents.clear();
        _selectedIncidents.addAll(_currentDocs.map((doc) => doc.id));
        _isMultiSelectMode = true;
      }
    });
  }

  // Delete Operations
  Future<void> _deleteIncident(String id, {bool showUndo = true}) async {
    try {
      // Get the document data before deleting for potential undo
      final docSnapshot = await FirebaseFirestore.instance
          .collection('incidents')
          .doc(id)
          .get();
      
      final incidentData = docSnapshot.data();
      
      // Delete the document
      await FirebaseFirestore.instance
          .collection('incidents')
          .doc(id)
          .delete();
      
      // Show undo snackbar if requested
      if (showUndo && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Incident deleted'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () => _undoDelete(id, incidentData),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _undoDelete(String id, Map<String, dynamic>? data) async {
    if (data == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('incidents')
          .doc(id)
          .set(data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident restored'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Batch Operations
  Future<void> _batchUpdateStatus(String status) async {
    if (_selectedIncidents.isEmpty) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Confirm Batch Update',
      content:
          'Update ${_selectedIncidents.length} incidents to "${StyleService.getStatusStyle(status)['label']}"?',
      confirmColor: StyleService.getStatusStyle(status)['color'] as Color,
    );

    if (confirmed != true) return;

    try {
      await IncidentService.batchUpdateStatus(_selectedIncidents, status);
      _showSuccessSnackbar(
          'Updated ${_selectedIncidents.length} incidents to ${StyleService.getStatusStyle(status)['label']}');
      _clearSelection();
    } catch (e) {
      _showErrorSnackbar('Failed to update: $e');
    }
  }

  Future<void> _showBatchDeleteConfirmation() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Confirm Batch Delete',
      content:
          'Are you sure you want to delete ${_selectedIncidents.length} incidents? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: IncidentReportConstants.colorScheme['error']!,
    );

    if (confirmed != true) return;

    final incidentsToDelete = <String, Map<String, dynamic>>{};
    for (final id in _selectedIncidents) {
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('incidents')
            .doc(id)
            .get();

        if (docSnapshot.exists) {
          incidentsToDelete[id] = docSnapshot.data()!;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error getting document $id: $e');
        }
      }
    }

    try {
      await IncidentService.batchDeleteIncidents(_selectedIncidents);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${_selectedIncidents.length} incidents'),
            backgroundColor: IncidentReportConstants.colorScheme['error'],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () => _undoBatchDelete(incidentsToDelete),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      _clearSelection();
    } catch (e) {
      _showErrorSnackbar('Failed to delete: $e');
    }
  }

  Future<void> _undoBatchDelete(Map<String, Map<String, dynamic>> incidents) async {
    if (incidents.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final entry in incidents.entries) {
      final docRef = FirebaseFirestore.instance.collection('incidents').doc(entry.key);
      batch.set(docRef, entry.value);
    }

    try {
      await batch.commit();
      _showSuccessSnackbar('Incidents restored');
    } catch (e) {
      _showErrorSnackbar('Failed to restore: $e');
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedIncidents.clear();
      _isMultiSelectMode = false;
    });
  }

  // UI Components
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              IncidentReportConstants.colorScheme['primaryLight']!,
              IncidentReportConstants.colorScheme['secondary']!
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 20),
              _buildFilterSection(),
              const SizedBox(height: 16),
              if (_isMultiSelectMode) _buildBatchActions(),
              const SizedBox(height: 16),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildEmergencyList(),
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
        icon: const Icon(Icons.menu_rounded, color: Colors.white),
        onPressed: widget.onMenuPressed,
      ),
      title: const Text(
        'EMERGENCY INCIDENT REPORT',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      backgroundColor: IncidentReportConstants.colorScheme['primary'],
      elevation: 8,
      centerTitle: true,
      actions: [
        if (widget.userRole == 'admin')
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
              backgroundColor: Colors.amber,
              child: const Icon(Icons.new_releases_rounded, color: Colors.white),
            ),
            onPressed: _refreshData,
            tooltip: 'New updates available',
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Hero(
      tag: 'search_bar',
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(25),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search incidents by location or type...',
            prefixIcon:
                Icon(Icons.search_rounded, color: IncidentReportConstants.colorScheme['primary']),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: IncidentReportConstants.colorScheme['primary']),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
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
            _buildFilterChip(
              label: 'Recent',
              selected: _selectedFilter == 'recent',
              onSelected: () => setState(() {
                _selectedFilter = 'recent';
                _selectedDate = null;
              }),
            ),
            _buildFilterChip(
              label: 'All Reports',
              selected: _selectedFilter == 'all',
              onSelected: () => setState(() => _selectedFilter = 'all'),
            ),
            if (_selectedFilter == 'all')
              _buildDateFilterChip(),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: IncidentReportConstants.colorScheme['primary'],
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildDateFilterChip() {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_rounded, size: 16),
          const SizedBox(width: 4),
          Text(
            _selectedDate == null
                ? "Date"
                : DateFormat('MMM d').format(_selectedDate!),
          ),
        ],
      ),
      selected: _selectedDate != null,
      onSelected: (_) async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (pickedDate != null) {
          setState(() {
            _selectedDate = pickedDate;
          });
        }
      },
      selectedColor: IncidentReportConstants.colorScheme['primary'],
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildBatchActions() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _selectedIncidents.length == _currentDocs.length && _currentDocs.isNotEmpty,
                onChanged: (value) => _selectAllIncidents(),
                activeColor: IncidentReportConstants.colorScheme['primary'],
              ),
              const SizedBox(width: 12),
              Text(
                '${_selectedIncidents.length} selected',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_rounded,
                    color: IncidentReportConstants.colorScheme['error']),
                onPressed: _showBatchDeleteConfirmation,
                tooltip: 'Delete selected',
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: IncidentReportConstants.colorScheme['primary']),
                itemBuilder: (context) => IncidentReportConstants.statusOptions.map((status) {
                  final style = StyleService.getStatusStyle(status);
                  return PopupMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Icon(style['icon'] as IconData, color: style['color'] as Color),
                        const SizedBox(width: 12),
                        Text(style['label'] as String),
                      ],
                    ),
                  );
                }).toList(),
                onSelected: _batchUpdateStatus,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyList() {
    return StreamBuilder<QuerySnapshot>(
      stream: IncidentService.getIncidentsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _buildLoadingState();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final filteredDocs = _filterEmergencies(snapshot.data!.docs);
        _currentDocs.clear();
        _currentDocs.addAll(filteredDocs);

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        // Group by date for All Reports view
        final Map<String, List<QueryDocumentSnapshot>> groupedDocs = {};
        if (_selectedFilter == 'all') {
          for (final doc in filteredDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final dateKey = timestamp != null
                ? DateFormat('yyyy-MM-dd').format(timestamp.toDate())
                : 'Unknown Date';
            
            if (!groupedDocs.containsKey(dateKey)) {
              groupedDocs[dateKey] = [];
            }
            groupedDocs[dateKey]!.add(doc);
          }
        }

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: _selectedFilter == 'all' 
              ? _buildGroupedList(groupedDocs)
              : _buildRegularList(filteredDocs),
        );
      },
    );
  }

  Widget _buildGroupedList(Map<String, List<QueryDocumentSnapshot>> groupedDocs) {
    final sortedDates = groupedDocs.keys.toList()..sort((a, b) => b.compareTo(a));
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _calculateGroupedItemCount(groupedDocs, sortedDates),
      itemBuilder: (context, index) {
        var currentIndex = 0;
        
        for (final date in sortedDates) {
          final docs = groupedDocs[date]!;
          
          // Date header
          if (index == currentIndex) {
            return _buildDateHeader(date);
          }
          currentIndex++;
          
          // Documents for this date
          for (int i = 0; i < docs.length; i++) {
            if (index == currentIndex) {
              final doc = docs[i];
              final incident = IncidentData.fromDocument(doc);
              
              if (!kIsWeb) {
                for (final url in incident.imageUrls) {
                  if (url is String) {
                    DefaultCacheManager().getSingleFile(url);
                  }
                }
              }
              
              return IncidentCard(
                incident: incident,
                onTap: () => _showEmergencyDetails(doc),
                userRole: widget.userRole,
                isSelectable: _isMultiSelectMode,
                isSelected: _selectedIncidents.contains(doc.id),
                onSelect: () => _selectIncident(doc.id),
                onDelete: () => _deleteIncident(doc.id),
                showDeleteButton: _selectedFilter == 'all' && widget.userRole == 'admin',
              );
            }
            currentIndex++;
          }
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  int _calculateGroupedItemCount(Map<String, List<QueryDocumentSnapshot>> groupedDocs, List<String> sortedDates) {
    int count = groupedDocs.length; // Date headers
    for (final docs in groupedDocs.values) {
      count += docs.length; // Documents
    }
    return count;
  }

  Widget _buildDateHeader(String dateKey) {
    final date = dateKey == 'Unknown Date' 
        ? 'Unknown Date'
        : DateFormat('MMMM d, yyyy').format(DateTime.parse(dateKey));
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: IncidentReportConstants.colorScheme['primaryLight'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: IncidentReportConstants.colorScheme['secondary']!),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 16, color: IncidentReportConstants.colorScheme['primary']),
          const SizedBox(width: 8),
          Text(
            date,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: IncidentReportConstants.colorScheme['primary'],
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            _getDaySuffix(DateTime.parse(dateKey)),
            style: TextStyle(
              color: IncidentReportConstants.colorScheme['primaryDark'],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getDaySuffix(DateTime date) {
    final day = date.day;
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1: return '${day}st';
      case 2: return '${day}nd';
      case 3: return '${day}rd';
      default: return '${day}th';
    }
  }

  Widget _buildRegularList(List<QueryDocumentSnapshot> filteredDocs) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: filteredDocs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = filteredDocs[index];
        final incident = IncidentData.fromDocument(doc);
        
        if (!kIsWeb) {
          for (final url in incident.imageUrls) {
            if (url is String) {
              DefaultCacheManager().getSingleFile(url);
            }
          }
        }
        
        return IncidentCard(
          incident: incident,
          onTap: () => _showEmergencyDetails(doc),
          userRole: widget.userRole,
          isSelectable: _isMultiSelectMode,
          isSelected: _selectedIncidents.contains(doc.id),
          onSelect: () => _selectIncident(doc.id),
          onDelete: () => _deleteIncident(doc.id),
          showDeleteButton: _selectedFilter == 'all' && widget.userRole == 'admin',
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 64, color: IncidentReportConstants.colorScheme['error']),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: IncidentReportConstants.colorScheme['primary'],
            ),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
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
        height: 120,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 64, color: IncidentReportConstants.colorScheme['primary']),
          const SizedBox(height: 16),
          const Text(
            'No incidents found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: IncidentReportConstants.colorScheme['primary'],
            ),
            child: const Text('Clear Filters', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterEmergencies(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final location = (data['address'] ?? '').toString().toLowerCase();
      final type = (data['incidentType'] ?? '').toString().toLowerCase();
      final timestamp = data['timestamp'] as Timestamp?;
      
      // Apply time filter
      if (_selectedFilter == 'recent' && timestamp != null) {
        final reportTime = timestamp.toDate();
        if (reportTime.isBefore(startOfToday)) {
          return false;
        }
      }
      
      // Apply date filter if selected
      if (_selectedDate != null && timestamp != null) {
        final reportDate = timestamp.toDate();
        if (!DateUtils.isSameDay(reportDate, _selectedDate)) {
          return false;
        }
      }
      
      // Apply search filter
      return _searchQuery.isEmpty ||
          location.contains(_searchQuery) ||
          type.contains(_searchQuery);
    }).toList();
  }

  void _showEmergencyDetails(QueryDocumentSnapshot doc) {
    final incident = IncidentData.fromDocument(doc);

    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: IncidentDetailsModal(
              incident: incident,
              userRole: widget.userRole,
              onStatusUpdated: () {
                setState(() {
                  _hasNewUpdates = true;
                });
              },
              isWeb: true,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => IncidentDetailsModal(
          incident: incident,
          userRole: widget.userRole,
          onStatusUpdated: () {
            setState(() {
              _hasNewUpdates = true;
            });
          },
          isWeb: false,
        ),
      );
    }
  }

  Widget _buildFloatingActionButton() {
    if (_isMultiSelectMode && _selectedIncidents.isNotEmpty) {
      return FloatingActionButton(
        onPressed: () => _batchUpdateStatus('in progress'),
        backgroundColor: IncidentReportConstants.colorScheme['primary'],
        child: const Icon(Icons.check_rounded, color: Colors.white),
      );
    }

    return FloatingActionButton(
      onPressed: _refreshData,
      backgroundColor: IncidentReportConstants.colorScheme['primary'],
      child: const Icon(Icons.refresh_rounded, color: Colors.white),
    );
  }

  // Utility Methods
  Future<bool?> _showConfirmationDialog({
    required String title,
    required String content,
    String confirmText = 'Confirm',
    Color? confirmColor,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? IncidentReportConstants.colorScheme['primary'],
            ),
            child: Text(confirmText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: IncidentReportConstants.colorScheme['success'],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: IncidentReportConstants.colorScheme['error'],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
}

// Incident Card Widget
class IncidentCard extends StatelessWidget {
  final IncidentData incident;
  final VoidCallback onTap;
  final String userRole;
  final bool isSelectable;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;
  final bool showDeleteButton;

  const IncidentCard({
    super.key,
    required this.incident,
    required this.onTap,
    required this.userRole,
    required this.isSelectable,
    required this.isSelected,
    required this.onSelect,
    this.onDelete,
    this.showDeleteButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final incidentStyle = StyleService.getIncidentStyle(incident.incidentType);
    final statusStyle = StyleService.getStatusStyle(incident.status);
    final hasImages = incident.imageUrls.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isSelectable ? onSelect : onTap,
      onLongPress: userRole == 'admin' ? onSelect : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? (incidentStyle['color'] as Color).withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: incidentStyle['color'] as Color, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// INCIDENT HEADER
            Row(
              children: [
                if (isSelectable)
                  _buildSelectionIndicator(incidentStyle['color'] as Color)
                else
                  _buildIncidentIcon(incidentStyle),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (incident.incidentType ?? 'Unknown type').toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: incidentStyle['color'] as Color,
                    ),
                  ),
                ),
                _buildStatusBadge(statusStyle),
                if (showDeleteButton && !isSelectable) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, size: 20),
                    color: IncidentReportConstants.colorScheme['error'],
                    onPressed: () => _showDeleteConfirmation(context, onDelete),
                    tooltip: 'Delete Incident',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            /// LOCATION
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 16, color: Colors.blueGrey.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    incident.address ?? 'Unknown location',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            /// REPORTER + TIME
            Row(
              children: [
                Icon(Icons.person_rounded, size: 16, color: Colors.blueGrey.shade700),
                const SizedBox(width: 6),
                Text(
                  incident.name ?? 'Anonymous',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blueGrey.shade700,
                  ),
                ),
                const Spacer(),
                if (hasImages) ...[
                  Icon(Icons.image_rounded, size: 16, color: Colors.blueGrey.shade700),
                  const SizedBox(width: 4),
                ],
                Text(
                  incident.timestamp != null
                      ? DateFormat('MMM d, h:mm a').format(incident.timestamp!.toDate())
                      : 'Unknown time',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),

            if (userRole == 'admin') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: IncidentReportConstants.colorScheme['primaryLight'],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: IncidentReportConstants.colorScheme['secondary']!),
                ),
                child: Text(
                  'ADMIN VIEW',
                  style: TextStyle(
                    fontSize: 10,
                    color: IncidentReportConstants.colorScheme['primaryDark'],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator(Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: isSelected ? color : Colors.grey.shade400),
      ),
      child: Icon(
        isSelected ? Icons.check_rounded : Icons.circle_outlined,
        size: 20,
        color: isSelected ? Colors.white : Colors.grey.shade400,
      ),
    );
  }

  Widget _buildIncidentIcon(Map<String, dynamic> incidentStyle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: incidentStyle['gradient'] as Gradient,
        shape: BoxShape.circle,
      ),
      child: Icon(
        incidentStyle['icon'] as IconData,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> statusStyle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusStyle['bgColor'] as Color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusStyle['icon'] as IconData, size: 14, color: statusStyle['color'] as Color),
          const SizedBox(width: 4),
          Text(
            (statusStyle['label'] as String).toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: statusStyle['color'] as Color,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, VoidCallback? onDelete) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this incident report? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onDelete != null) {
                  onDelete();
                }
              },
              child: Text(
                "Delete",
                style: TextStyle(color: IncidentReportConstants.colorScheme['error']),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Incident Details Modal
class IncidentDetailsModal extends StatefulWidget {
  final IncidentData incident;
  final String userRole;
  final VoidCallback onStatusUpdated;
  final bool isWeb;

  const IncidentDetailsModal({
    super.key,
    required this.incident,
    required this.userRole,
    required this.onStatusUpdated,
    required this.isWeb,
  });

  @override
  State<IncidentDetailsModal> createState() => _IncidentDetailsModalState();
}

class _IncidentDetailsModalState extends State<IncidentDetailsModal> {
  late String _selectedStatus;
  final TextEditingController _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Map<String, Uint8List?> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.incident.status;
    _preloadImages();
  }

  Future<void> _preloadImages() async {
    for (final imageUrl in widget.incident.imageUrls) {
      if (imageUrl is String && imageUrl.isNotEmpty) {
        _loadImageForWeb(imageUrl);
      }
    }
  }

  Future<void> _loadImageForWeb(String imageUrl) async {
    try {
      if (_imageCache.containsKey(imageUrl)) return;

      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      final imageData = await ref.getData();

      setState(() {
        _imageCache[imageUrl] = imageData;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading image: $e');
      }
      _imageCache[imageUrl] = null;
    }
  }

  void _showImagePreview(String imageUrl) {
    final imageData = _imageCache[imageUrl];
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Stack(
            children: [
              PhotoView(
                imageProvider: imageData != null
                    ? MemoryImage(imageData)
                    : NetworkImage(imageUrl) as ImageProvider,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isWeb) {
      return _buildWebLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildWebLayout() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildIncidentDetails(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildStatusSection(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 60,
            height: 6,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIncidentDetails(),
                  const SizedBox(height: 24),
                  _buildStatusSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: IncidentReportConstants.colorScheme['primary'],
        borderRadius: widget.isWeb
            ? const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              )
            : null,
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 32, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'INCIDENT DETAILS',
              style: TextStyle(
                fontSize: widget.isWeb ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentDetails() {
    final incidentStyle = StyleService.getIncidentStyle(widget.incident.incidentType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: incidentStyle['gradient'] as Gradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  incidentStyle['icon'] as IconData,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (widget.incident.incidentType ?? 'Unknown type').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.incident.address ?? 'Unknown location',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildDetailSection(
          icon: Icons.location_on_rounded,
          title: 'Location',
          content: widget.incident.address ?? 'Unknown location',
        ),
        _buildDetailSection(
          icon: Icons.access_time_rounded,
          title: 'Reported',
          content: widget.incident.timestamp != null
              ? DateFormat('MMMM d, y - h:mm a').format(widget.incident.timestamp!.toDate())
              : 'Unknown time',
        ),
        if (widget.incident.contactNumber != null)
          _buildDetailSection(
            icon: Icons.phone_rounded,
            title: 'Contact',
            content: widget.incident.contactNumber!,
          ),
        _buildDetailSection(
          icon: Icons.person_rounded,
          title: 'Reporter',
          content: widget.incident.name ?? 'Anonymous',
        ),
        if (widget.incident.description != null)
          _buildDetailSection(
            icon: Icons.description_rounded,
            title: 'Description',
            content: widget.incident.description!,
            isDescription: true,
          ),
        if (widget.incident.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildImagesSection(),
        ],
        if (widget.incident.statusUpdates.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildStatusTimeline(),
        ],
      ],
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required String title,
    required String content,
    bool isDescription = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: IncidentReportConstants.colorScheme['primary']),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: isDescription ? 15 : 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTACHED IMAGES',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: IncidentReportConstants.colorScheme['primaryDark'],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.incident.imageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = widget.incident.imageUrls[index]?.toString() ?? '';
              final imageData = _imageCache[imageUrl];

              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onTap: () => _showImagePreview(imageUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[200],
                        child: _buildImageWidget(imageUrl, imageData),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageWidget(String imageUrl, Uint8List? imageData) {
    if (imageData == null) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Image.memory(
      imageData,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
          ),
        );
      },
    );
  }

  Widget _buildStatusTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATUS HISTORY',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: IncidentReportConstants.colorScheme['primaryDark'],
          ),
        ),
        const SizedBox(height: 16),
        ...widget.incident.statusUpdates.reversed.map((update) {
          final status = update['status']?.toString() ?? '';
          final note = update['note']?.toString() ?? '';
          final timestamp = update['timestamp'];
          
          DateTime? time;
          if (timestamp is Timestamp) {
            time = timestamp.toDate();
          }
          
          final timeString = time != null 
              ? DateFormat('MMM d, h:mm a').format(time)
              : 'Unknown time';
          
          final statusStyle = StyleService.getStatusStyle(status);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusStyle['bgColor'] as Color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusStyle['icon'] as IconData,
                    color: statusStyle['color'] as Color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusStyle['color'] as Color,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          note,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        timeString,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatusSection() {
    if (widget.userRole == 'admin') {
      return _buildAdminStatusSection();
    } else {
      return _buildUserStatusSection();
    }
  }

  Widget _buildAdminStatusSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPDATE STATUS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: IncidentReportConstants.colorScheme['primaryDark'],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            items: IncidentReportConstants.statusOptions.map((status) {
              final style = StyleService.getStatusStyle(status);
              return DropdownMenuItem(
                value: status,
                child: Row(
                  children: [
                    Icon(style['icon'] as IconData, color: style['color'] as Color),
                    const SizedBox(width: 12),
                    Text(style['label'] as String),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) async {
              if (value != null && value != _selectedStatus) {
                if (value == 'declined') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Decline'),
                      content: const Text('Are you sure you want to decline this incident? This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Decline', style: TextStyle(color: IncidentReportConstants.colorScheme['error'])),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirmed != true) {
                    return;
                  }
                }
                
                setState(() {
                  _selectedStatus = value;
                });
              }
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADD NOTE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Add a note about this update...",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please add a note';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _updateStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: IncidentReportConstants.colorScheme['primary'],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('SAVE UPDATE', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatusSection() {
    final statusStyle = StyleService.getStatusStyle(widget.incident.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT STATUS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: IncidentReportConstants.colorScheme['primaryDark'],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusStyle['bgColor'] as Color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusStyle['color'] as Color, width: 2),
            ),
            child: Row(
              children: [
                Icon(statusStyle['icon'] as IconData, color: statusStyle['color'] as Color, size: 32),
                const SizedBox(width: 16),
                Text(
                  (statusStyle['label'] as String).toUpperCase(),
                  style: TextStyle(
                    color: statusStyle['color'] as Color,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus() async {
    if (_formKey.currentState!.validate()) {
      final note = _noteController.text.trim();
      
      try {
        await IncidentService.updateIncidentStatus(
          widget.incident.id,
          status: _selectedStatus,
          note: note,
          updatedBy: 'Admin',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onStatusUpdated();
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}