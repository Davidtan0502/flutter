import 'dart:typed_data'; // for Uint8List

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shimmer/shimmer.dart';

class EmergenciesScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;
  final String userRole;

  const EmergenciesScreen({
    super.key,
    required this.onMenuPressed,
    required this.userRole,
  });

  @override
  State<EmergenciesScreen> createState() => _EmergenciesScreenState();
}

class _EmergenciesScreenState extends State<EmergenciesScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'recent';
  DateTime? _selectedDate;
  final List<String> _selectedIncidents = [];
  bool _isMultiSelectMode = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasNewUpdates = false;

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
    if (showUndo && context.mounted) {
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
    if (context.mounted) {
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
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incident restored'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

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
    
    // Start animation after build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
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
        return const Color(0xFFFF9800); {}
      case 'under review':
        return const Color.fromRGBO(156, 39, 176, 1);
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
    
    // Simulate network request
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _isLoading = false;
    });
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedIncidents.clear();
      }
    });
  }

  void _selectIncident(String id) {
    setState(() {
      if (_selectedIncidents.contains(id)) {
        _selectedIncidents.remove(id);
      } else {
        _selectedIncidents.add(id);
      }
      
      if (_selectedIncidents.isEmpty) {
        _isMultiSelectMode = false;
      }
    });
  }

  Future<void> _batchUpdateStatus(String status) async {
    if (_selectedIncidents.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Batch Update'),
        content: Text('Update ${_selectedIncidents.length} incidents to "$status"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    final batch = FirebaseFirestore.instance.batch();
    
    for (final id in _selectedIncidents) {
      final docRef = FirebaseFirestore.instance.collection('incidents').doc(id);
      final updates = {
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      batch.update(docRef, updates);
    }
    
    try {
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated ${_selectedIncidents.length} incidents'),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {
        _selectedIncidents.clear();
        _isMultiSelectMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            colors: [Color.fromARGB(255, 225, 245, 255), Color.fromARGB(255, 153, 206, 255)],
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
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: widget.onMenuPressed,
      ),
      title: const Text('EMERGENCY INCIDENT REPORT'),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: const Color(0xFF2C5282),
      elevation: 4,
      centerTitle: true,
      actions: [
        if (widget.userRole == 'admin')
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
      ],
    );
  }

  Widget _buildSearchBar() {
    return Hero(
      tag: 'search_bar',
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(30),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search incidents by location or type...',
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
              label: const Text('Recent (24h)'),
              selected: _selectedFilter == 'recent',
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = 'recent';
                  _selectedDate = null;
                });
              },
              selectedColor: Colors.blue[800],
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: _selectedFilter == 'recent' ? Colors.white : Colors.black87,
              ),
            ),
            FilterChip(
              label: const Text('All Reports'),
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
            if (_selectedFilter == 'all')
              FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
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
                selectedColor: Colors.blue[800],
                checkmarkColor: Colors.white,
              ),
          ],
        ),
      ],
    );
  }

 Widget _buildBatchActions() {
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
            '${_selectedIncidents.length} selected',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showBatchDeleteConfirmation(),
            tooltip: 'Delete selected',
          ),
          // Status update dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'in progress',
                child: Row(
                  children: [
                    Icon(Icons.autorenew, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Mark as In Progress'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'resolved',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Mark as Resolved'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'under review',
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Mark as Under Review'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'declined',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Decline Selected'),
                  ],
                ),
              ),
            ],
            onSelected: _batchUpdateStatus,
          ),
        ],
      ),
    ),
  );
}
void _showBatchDeleteConfirmation() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Batch Delete'),
      content: Text('Are you sure you want to delete ${_selectedIncidents.length} incidents? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
  
  if (confirmed != true) return;
  
  // Store data for potential undo
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
  
  // Delete all selected incidents
  final batch = FirebaseFirestore.instance.batch();
  for (final id in _selectedIncidents) {
    final docRef = FirebaseFirestore.instance.collection('incidents').doc(id);
    batch.delete(docRef);
  }
  
  try {
    await batch.commit();
    
    // Show undo snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${_selectedIncidents.length} incidents'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () => _undoBatchDelete(incidentsToDelete),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
    
    setState(() {
      _selectedIncidents.clear();
      _isMultiSelectMode = false;
    });
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _undoBatchDelete(Map<String, Map<String, dynamic>> incidents) async {
  if (incidents.isEmpty) return;
  
  final batch = FirebaseFirestore.instance.batch();
  
  for (final entry in incidents.entries) {
    final docRef = FirebaseFirestore.instance
        .collection('incidents')
        .doc(entry.key);
    
    batch.set(docRef, entry.value);
  }
  
  try {
    await batch.commit();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incidents restored'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
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

Widget _buildEmergencyList() {
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

      final filteredDocs = _filterEmergencies(snapshot.data!.docs);

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
            
            if (!kIsWeb) {
              final imageUrls = data['imageUrls'] as List<dynamic>? ?? [];
              for (final url in imageUrls) {
                if (url is String) {
                  DefaultCacheManager().getSingleFile(url);
                }
              }
            }
            
            return _EmergencyCard(
              data: data,
              docId: doc.id,
              onTap: () => _showEmergencyDetails(doc),
              getStatusColor: _getStatusColor,
              getStatusIcon: _getStatusIcon,
              userRole: widget.userRole,
              isSelectable: _isMultiSelectMode,
              isSelected: _selectedIncidents.contains(doc.id),
              onSelect: () => _selectIncident(doc.id),
              onDelete: () => _deleteIncident(doc.id),
              showDeleteButton: _selectedFilter == 'all' && widget.userRole == 'admin',
            );
          },
        ),
      );
    },
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
          const Text(
            'No incidents found',
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

  List<QueryDocumentSnapshot> _filterEmergencies(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));
    
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final location = (data['address'] ?? '').toString().toLowerCase();
      final type = (data['incidentType'] ?? '').toString().toLowerCase();
      final timestamp = data['timestamp'] as Timestamp?;
      
      // Apply time filter
      if (_selectedFilter == 'recent' && timestamp != null) {
        final reportTime = timestamp.toDate();
        if (reportTime.isBefore(twentyFourHoursAgo)) {
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
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp?;
    final statusOptions = ['pending', 'in progress', 'resolved', 'under review', 'declined'];
    final imageUrls = data['imageUrls'] as List<dynamic>? ?? [];
    
    String currentStatus = (data['status'] ?? 'pending').toString().toLowerCase();
    if (!statusOptions.contains(currentStatus)) {
      currentStatus = 'pending';
    }
    
    final statusUpdates = data['statusUpdates'] as List<dynamic>? ?? [];

    if (kIsWeb) {
      // Web-optimized modal with larger width
      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 1.85,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: _EmergencyDetailsModal(
              data: data,
              timestamp: timestamp,
              currentStatus: currentStatus,
              statusOptions: statusOptions,
              statusUpdates: statusUpdates,
              imageUrls: imageUrls,
              getStatusColor: _getStatusColor,
              getStatusIcon: _getStatusIcon,
              userRole: widget.userRole,
              onStatusUpdated: () {
                setState(() {
                  _hasNewUpdates = true;
                });
              },
              docId: doc.id,
              isWeb: true,
            ),
          ),
        ),
      );
    } else {
      // Mobile modal
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _EmergencyDetailsModal(
          data: data,
          timestamp: timestamp,
          currentStatus: currentStatus,
          statusOptions: statusOptions,
          statusUpdates: statusUpdates,
          imageUrls: imageUrls,
          getStatusColor: _getStatusColor,
          getStatusIcon: _getStatusIcon,
          userRole: widget.userRole,
          onStatusUpdated: () {
            setState(() {
              _hasNewUpdates = true;
            });
          },
          docId: doc.id,
          isWeb: false,
        ),
      );
    }
  }

  Widget _buildFloatingActionButton() {
    if (_isMultiSelectMode && _selectedIncidents.isNotEmpty) {
      return FloatingActionButton(
        onPressed: () => _batchUpdateStatus('in progress'),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.check, color: Colors.white),
      );
    }
    
    return FloatingActionButton(
      onPressed: _refreshData,
      backgroundColor: Colors.blue,
      child: const Icon(Icons.refresh, color: Colors.white),
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

class _EmergencyDetailsModal extends StatefulWidget {
  final Map<String, dynamic> data;
  final Timestamp? timestamp;
  final String currentStatus;
  final List<String> statusOptions;
  final List<dynamic> statusUpdates;
  final List<dynamic> imageUrls;
  final Color Function(String) getStatusColor;
  final IconData Function(String) getStatusIcon;
  final String userRole;
  final VoidCallback onStatusUpdated;
  final String docId;
  final bool isWeb;

  const _EmergencyDetailsModal({
    required this.data,
    required this.timestamp,
    required this.currentStatus,
    required this.statusOptions,
    required this.statusUpdates,
    required this.imageUrls,
    required this.getStatusColor,
    required this.getStatusIcon,
    required this.userRole,
    required this.onStatusUpdated,
    required this.docId,
    this.isWeb = false,
  });

  @override
  _EmergencyDetailsModalState createState() => _EmergencyDetailsModalState();
}

class _EmergencyDetailsModalState extends State<_EmergencyDetailsModal> {
  late String _selectedStatus;
  final TextEditingController _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Map<String, Uint8List?> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
    _preloadImages();
  }

  Future<void> _preloadImages() async {
    for (final imageUrl in widget.imageUrls) {
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
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
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

  Widget _buildImagesSection() {
    if (widget.imageUrls.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTACHED IMAGES',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = widget.imageUrls[index]?.toString() ?? '';
              final imageData = _imageCache[imageUrl];
              
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: Material(
                  elevation: 2,
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
            child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
          ),
        );
      },
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
        borderRadius: BorderRadius.circular(16),
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
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue[800],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 32, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'INCIDENT DETAILS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 28, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column - Incident details
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailCard(),
                        const SizedBox(height: 32),
                        
                        // Details sections
                        _buildDetailSection(
                          icon: Icons.location_on,
                          title: 'Location',
                          content: widget.data['address']?.toString() ?? 'Unknown location',
                        ),
                        
                        _buildDetailSection(
                          icon: Icons.access_time,
                          title: 'Reported',
                          content: widget.timestamp != null
                              ? DateFormat('MMMM d, y - h:mm a')
                                  .format(widget.timestamp!.toDate())
                              : 'Unknown time',
                        ),
                        
                        _buildDetailSection(
                          icon: Icons.phone,
                          title: 'Contact',
                          content: widget.data['contactNumber']?.toString() ?? 'Not provided',
                        ),
                        
                        _buildDetailSection(
                          icon: Icons.person,
                          title: 'Reporter',
                          content: widget.data['name']?.toString() ?? 'Anonymous',
                        ),
                        
                        if (widget.data['description'] != null) ...[
                          const SizedBox(height: 24),
                          _buildDetailSection(
                            icon: Icons.description,
                            title: 'Description',
                            content: widget.data['description']!.toString(),
                            isDescription: true,
                          ),
                        ],
                        
                        // Images section
                        if (widget.imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          _buildImagesSection(),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 32),
                  
                  // Right column - Status and updates
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        // Status timeline
                        if (widget.statusUpdates.isNotEmpty) ...[
                          _buildStatusTimeline(),
                          const SizedBox(height: 32),
                        ],
                        
                        // Admin section or user view
                        widget.userRole == 'admin' 
                            ? _buildAdminSection()
                            : _buildUserSection(),
                      ],
                    ),
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
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Incident Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailCard(),
                  const SizedBox(height: 24),
                  
                  // Status timeline
                  if (widget.statusUpdates.isNotEmpty) ...[
                    _buildStatusTimeline(),
                    const SizedBox(height: 24),
                  ],
                  
                  // Details sections
                  _buildDetailSection(
                    icon: Icons.location_on,
                    title: 'Location',
                    content: widget.data['address']?.toString() ?? 'Unknown location',
                  ),
                  
                  _buildDetailSection(
                    icon: Icons.access_time,
                    title: 'Reported',
                    content: widget.timestamp != null
                        ? DateFormat('MMMM d, y - h:mm a')
                            .format(widget.timestamp!.toDate())
                        : 'Unknown time',
                  ),
                  
                  _buildDetailSection(
                    icon: Icons.phone,
                    title: 'Contact',
                    content: widget.data['contactNumber']?.toString() ?? 'Not provided',
                  ),
                  
                  _buildDetailSection(
                    icon: Icons.person,
                    title: 'Reporter',
                    content: widget.data['name']?.toString() ?? 'Anonymous',
                  ),
                  
                  if (widget.data['description'] != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      icon: Icons.description,
                      title: 'Description',
                      content: widget.data['description']!.toString(),
                      isDescription: true,
                    ),
                  ],
                  
                  // Images section
                  if (widget.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildImagesSection(),
                  ],
                  
                  // Admin section or user view
                  const SizedBox(height: 24),
                  widget.userRole == 'admin' 
                      ? _buildAdminSection()
                      : _buildUserSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard() {
    final incidentType = widget.data['incidentType']?.toString() ?? 'Unknown type';
    final iconColor = _getIncidentColor(incidentType);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[100]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue[100]!.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: iconColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incidentType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.data['address']?.toString() ?? 'Unknown location',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.timestamp != null)
                  Text(
                    DateFormat('MMM d, y - h:mm a').format(widget.timestamp!.toDate()),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 16),
        ...widget.statusUpdates.reversed.map((update) {
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
                    color: widget.getStatusColor(status).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.getStatusIcon(status),
                    color: widget.getStatusColor(status),
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
                          color: widget.getStatusColor(status),
                          fontWeight: FontWeight.bold,
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

  Widget _buildDetailSection({
    required IconData icon,
    required String title,
    required String content,
    bool isDescription = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Colors.blue[800]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    letterSpacing: 1,
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


  Widget _buildAdminSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPDATE STATUS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                icon: const Icon(Icons.keyboard_arrow_down),
                isExpanded: true,
                style: TextStyle(
                  color: widget.getStatusColor(_selectedStatus),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
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
                              child: const Text('Decline', style: TextStyle(color: Colors.red)),
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
                items: widget.statusOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Row(
                      children: [
                        Icon(
                          widget.getStatusIcon(status),
                          color: widget.getStatusColor(status),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(status.toUpperCase()),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADD NOTE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Add a note about this update...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    contentPadding: const EdgeInsets.all(16),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final note = _noteController.text.trim();
                  
                  try {
                    final docSnapshot = await FirebaseFirestore.instance
                        .collection('incidents')
                        .doc(widget.docId)
                        .get();

                    if (!docSnapshot.exists) {
                      throw Exception("Document does not exist");
                    }

                    final currentData = docSnapshot.data() as Map<String, dynamic>;
                    final currentUpdates = List<Map<String, dynamic>>.from(
                      currentData['statusUpdates'] ?? []
                    );

                    final newStatusUpdate = {
                      'status': _selectedStatus,
                      'timestamp': Timestamp.now(),
                      'note': note,
                      'updatedBy': 'Admin',
                    };

                    currentUpdates.add(newStatusUpdate);

                    await FirebaseFirestore.instance
                        .collection('incidents')
                        .doc(widget.docId)
                        .update({
                          'status': _selectedStatus,
                          'statusUpdates': currentUpdates,
                          'lastUpdated': FieldValue.serverTimestamp(),
                        });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Status updated successfully!"),
                        backgroundColor: Colors.green,
                      ),
                    );

                    widget.onStatusUpdated();
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update status: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'SAVE UPDATE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT STATUS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.getStatusColor(widget.currentStatus).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.getStatusColor(widget.currentStatus),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.getStatusIcon(widget.currentStatus),
                  color: widget.getStatusColor(widget.currentStatus),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Text(
                  widget.currentStatus.toUpperCase(),
                  style: TextStyle(
                    color: widget.getStatusColor(widget.currentStatus),
                    fontWeight: FontWeight.bold,
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

class _EmergencyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onTap;
  final Color Function(String) getStatusColor;
  final IconData Function(String) getStatusIcon;
  final String userRole;
  final bool isSelectable;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;
  final bool showDeleteButton;

  const _EmergencyCard({
    required this.data,
    required this.docId,
    required this.onTap,
    required this.getStatusColor,
    required this.getStatusIcon,
    required this.userRole,
    this.isSelectable = false,
    this.isSelected = false,
    required this.onSelect,
    this.onDelete,
    this.showDeleteButton = false,
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
    final hasImages = (data['imageUrls'] as List<dynamic>? ?? []).isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isSelectable ? onSelect : onTap,
      onLongPress: () {
        if (userRole == 'admin') {
          onSelect();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
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
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.blue : Colors.grey,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    incidentType,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Status label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: getStatusColor(status),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        getStatusIcon(status),
                        size: 14,
                        color: getStatusColor(status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: getStatusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete button (only admin, all reports, not selectable mode)
                if (showDeleteButton && !isSelectable) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: Colors.red,
                    onPressed: () => _showDeleteConfirmation(context, docId, onDelete),
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
                Icon(Icons.location_on, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            /// REPORTER + TIME
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 6),
                Text(
                  reporter,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const Spacer(),
                if (hasImages) ...[
                  Icon(Icons.image, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 4),
                ],
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            if (userRole == 'admin') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  'ADMIN VIEW',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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
  
  void _showDeleteConfirmation(BuildContext context, String docId, VoidCallback? onDelete) {
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
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    },
  );
}
}