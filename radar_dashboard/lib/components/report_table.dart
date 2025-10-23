import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/components/section_header.dart';

class ReportTableScreen extends StatefulWidget {
  final DateTimeRange? dateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final List<Map<String, dynamic>> incidents;

  const ReportTableScreen({
    super.key,
    required this.dateRange,
    required this.onDateRangeChanged,
    required this.incidents,
  });

  @override
  State<ReportTableScreen> createState() => _ReportTableScreenState();
}

class _ReportTableScreenState extends State<ReportTableScreen> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedType = 'All';
  String _userRole = 'user';
  bool _hasNewUpdates = false;
  int _refreshCounter = 0;

  // Real-time data management like IncidentReportScreen
  final Map<String, Map<String, dynamic>> _incidentsMap = {};
  final List<Map<String, dynamic>> _displayedIncidents = [];
  
  StreamSubscription? _incidentsSubscription;
  StreamSubscription? _statusUpdatesSubscription;

  final List<String> _incidentTypes = const [
    'All',
    'Fire',
    'Accident',
    'Flood',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _getUserRole();
    _searchController.addListener(_onSearchChanged);
    _setupRealTimeSubscriptions();
  }

  void _initializeData() {
    // Start with the incidents provided by parent and populate the map
    for (final incident in widget.incidents) {
      final id = incident['id'].toString();
      _incidentsMap[id] = incident;
    }
    _updateDisplayedIncidents();
    debugPrint('📋 ReportTableScreen initialized with ${_incidentsMap.length} incidents');
  }

  void _setupRealTimeSubscriptions() {
    _setupIncidentsSubscription();
    _setupStatusUpdatesSubscription();
  }

  void _setupIncidentsSubscription() {
    _incidentsSubscription?.cancel();
    
    _incidentsSubscription = _supabase
        .from('incidents')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .handleError((error) {
      debugPrint('❌ ReportTableScreen incidents stream error: $error');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _setupIncidentsSubscription();
      });
    }).listen(_handleIncidentsUpdate);

    debugPrint('🎯 ReportTableScreen real-time listener started');
  }

  void _setupStatusUpdatesSubscription() {
    _statusUpdatesSubscription?.cancel();
    
    _statusUpdatesSubscription = _supabase
        .from('incident_status_updates')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .handleError((error) {
      debugPrint('❌ ReportTableScreen status updates stream error: $error');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _setupStatusUpdatesSubscription();
      });
    }).listen(_handleStatusUpdates);
  }

  void _handleIncidentsUpdate(List<Map<String, dynamic>> incidents) {
    debugPrint('🔄 ReportTableScreen received ${incidents.length} incidents from stream');
    
    bool hasChanges = false;
    
    for (final incident in incidents) {
      final id = incident['id'].toString();
      final eventType = incident['type'] as String?;
      final newData = incident['new'] as Map<String, dynamic>?;
      final oldData = incident['old'] as Map<String, dynamic>?;

      switch (eventType) {
        case 'INSERT':
          if (newData != null) {
            _incidentsMap[id] = newData;
            hasChanges = true;
            _hasNewUpdates = true;
            debugPrint('➕ ReportTableScreen: NEW incident - $id');
            _showNewIncidentNotification(newData);
          }
          break;
        case 'UPDATE':
          if (newData != null) {
            _incidentsMap[id] = {
              ..._incidentsMap[id] ?? {},
              ...newData,
            };
            hasChanges = true;
            debugPrint('✏️ ReportTableScreen: UPDATED incident - $id');
          }
          break;
        case 'DELETE':
          if (oldData != null) {
            _incidentsMap.remove(id);
            hasChanges = true;
            debugPrint('🗑️ ReportTableScreen: DELETED incident - $id');
          }
          break;
        default:
          // Initial data or full refresh
          _incidentsMap[id] = incident;
          hasChanges = true;
      }
    }

    if (hasChanges && mounted) {
      _updateDisplayedIncidents();
      debugPrint('📊 ReportTableScreen total incidents in map: ${_incidentsMap.length}');
    }
  }

  void _handleStatusUpdates(List<Map<String, dynamic>> statusUpdates) {
    debugPrint('🔄 ReportTableScreen received ${statusUpdates.length} status updates from stream');
    
    bool hasChanges = false;
    
    for (final update in statusUpdates) {
      final eventType = update['type'] as String?;
      final newData = update['new'] as Map<String, dynamic>?;
      
      if (eventType == 'INSERT' && newData != null) {
        final incidentId = newData['incident_id'].toString();
        final status = newData['status'].toString();
        final timestamp = newData['created_at'] as String?;
        
        if (_incidentsMap.containsKey(incidentId)) {
          // Update the incident with latest status
          _incidentsMap[incidentId] = {
            ..._incidentsMap[incidentId]!,
            'latest_status': status,
            'status_updated_at': timestamp,
          };
          hasChanges = true;
          debugPrint('🔄 ReportTableScreen status updated for incident $incidentId: $status');
        }
      }
    }
    
    if (hasChanges && mounted) {
      _updateDisplayedIncidents();
    }
  }

  void _updateDisplayedIncidents() {
    // Convert map to list and sort by timestamp (newest first)
    _displayedIncidents.clear();
    _displayedIncidents.addAll(_incidentsMap.values.toList());
    _displayedIncidents.sort((a, b) {
      final timeA = a['timestamp'] as String?;
      final timeB = b['timestamp'] as String?;
      if (timeA == null || timeB == null) return 0;
      return timeB.compareTo(timeA);
    });
    
    if (mounted) {
      setState(() {
        _refreshCounter++;
      });
    }
  }

  void _showNewIncidentNotification(Map<String, dynamic> incident) {
    final type = incident['incident_type'] ?? 'Unknown';
    final location = incident['address'] ?? 'Unknown location';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New $type incident reported at $location'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearNewUpdates() {
    setState(() {
      _hasNewUpdates = false;
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  @override
  void didUpdateWidget(ReportTableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Sync with parent data when it changes
    if (widget.incidents != oldWidget.incidents) {
      debugPrint('📥 ReportTableScreen: Parent data updated - ${widget.incidents.length} incidents');
      
      // Merge parent data with our real-time updates
      for (final incident in widget.incidents) {
        final id = incident['id'].toString();
        if (!_incidentsMap.containsKey(id)) {
          _incidentsMap[id] = incident;
        }
      }
      
      _updateDisplayedIncidents();
    }
    
    if (oldWidget.dateRange != widget.dateRange) {
      debugPrint('📅 ReportTableScreen: Date range changed');
      setState(() {
        _refreshCounter++;
      });
    }
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _searchController.dispose();
    _incidentsSubscription?.cancel();
    _statusUpdatesSubscription?.cancel();
    super.dispose();
    debugPrint('🔴 ReportTableScreen disposed');
  }

  Future<void> _getUserRole() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _userRole = 'user');
        return;
      }

      final response = await _supabase
          .from('app_users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      if (response != null && mounted) {
        setState(() {
          _userRole = (response['role'] as String?) ?? 'user';
        });
      }
    } catch (e) {
      debugPrint('⚠️ User role fallback to "user": $e');
      if (mounted) {
        setState(() => _userRole = 'user');
      }
    }
  }

  String _capitalize(String input) =>
      input.isNotEmpty ? input[0].toUpperCase() + input.substring(1) : input;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = widget.dateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 1)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: now,
      initialDateRange: initial,
      helpText: 'Select Incident Date Range',
      saveText: 'Apply',
    );

    if (picked != null) {
      widget.onDateRangeChanged(picked);
    }
  }

  void _clearDateRange() {
    widget.onDateRangeChanged(null);
  }

List<Map<String, dynamic>> _getFilteredIncidents() {
  final now = DateTime.now();
  DateTime start, end;

  if (widget.dateRange != null) {
    start = DateTime(
      widget.dateRange!.start.year,
      widget.dateRange!.start.month,
      widget.dateRange!.start.day,
    );
    end = DateTime(
      widget.dateRange!.end.year,
      widget.dateRange!.end.month,
      widget.dateRange!.end.day,
      23, 59, 59, 999,
    );
  } else {
    // For "Today" view, use local date
    final today = DateTime(now.year, now.month, now.day);
    start = today;
    end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  // First filter by date
  final dateFiltered = _displayedIncidents.where((incident) {
    final timestamp = incident['timestamp'];
    if (timestamp == null) return false;
    
    try {
      final incidentDate = DateTime.parse(timestamp).toLocal();
      return incidentDate.isAfter(start.subtract(const Duration(seconds: 1))) && 
             incidentDate.isBefore(end.add(const Duration(seconds: 1)));
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
      return false;
    }
  }).toList();

  // Apply status filtering ONLY when no date range is selected (Today view)
  final statusFiltered = widget.dateRange == null 
      ? dateFiltered.where((incident) {
          // In Today view: filter out resolved and declined incidents
          final status = (incident['latest_status'] ?? incident['status'] ?? 'pending').toString().toLowerCase();
          return status != 'resolved' && status != 'declined';
        }).toList()
      : dateFiltered; // When date range is selected: show ALL statuses

  // Then apply search and type filters
  final searchFiltered = statusFiltered.where((doc) {
    final location = (doc['address'] ?? '').toString().toLowerCase();
    final type = (doc['incident_type'] ?? '').toString().toLowerCase();
    final contactNumber = (doc['contact_number'] ?? '').toString().toLowerCase();
    final description = (doc['description'] ?? '').toString().toLowerCase();

    final matchesSearch = _searchQuery.isEmpty ||
        location.contains(_searchQuery) ||
        type.contains(_searchQuery) ||
        contactNumber.contains(_searchQuery) ||
        description.contains(_searchQuery);

    final matchesType = _selectedType == 'All' ||
        (_selectedType == 'Other' ? 
         !['fire', 'accident', 'flood'].contains(type) : 
         type == _selectedType.toLowerCase());

    return matchesSearch && matchesType;
  }).toList();

  debugPrint('🔍 ReportTableScreen filtered ${_displayedIncidents.length} → ${searchFiltered.length} incidents');
  debugPrint('📅 Date range: ${widget.dateRange != null ? "Custom" : "Today"} - Status filter: ${widget.dateRange == null ? "Active only" : "All statuses"}');
  return searchFiltered;
}
 

@override
Widget build(BuildContext context) {
  final filtered = _getFilteredIncidents();
  
  debugPrint('🎨 ReportTableScreen building #$_refreshCounter - ${_displayedIncidents.length} total, ${filtered.length} filtered');

  final dateLabel = widget.dateRange == null 
      ? 'Today' 
      : _isSameDay(widget.dateRange!.start, widget.dateRange!.end)
          ? DateFormat('MMM d, yyyy').format(widget.dateRange!.start)
          : '${DateFormat('MMM d, yyyy').format(widget.dateRange!.start)} - ${DateFormat('MMM d, yyyy').format(widget.dateRange!.end)}';

  // In the build method, replace the resolved stats calculation:
          final today = DateTime.now();
          final yesterday = today.subtract(const Duration(days: 1));
          int resolvedToday = 0;
          int resolvedYesterday = 0;

          // Calculate resolved stats from ALL incidents (not filtered)
          for (var doc in _displayedIncidents) {
            final status = (doc['latest_status'] ?? doc['status'] ?? 'pending').toString().toLowerCase();
            if (status == 'resolved') {
              final resolvedAt = doc['resolvedAt'] as String?;
              final ts = resolvedAt ?? doc['timestamp'] as String?;
              if (ts != null) {
                try {
                  final d = DateTime.parse(ts).toLocal();
                  if (_isSameDay(d, today)) resolvedToday++;
                  if (_isSameDay(d, yesterday)) resolvedYesterday++;
                } catch (e) {
                  debugPrint('Error parsing resolved timestamp: $e');
                }
              }
            }
          }
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with update indicator
            Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    icon: Icons.warning_amber_outlined,
                    title: 'EMERGENCIES',
                    subtitle: '',
                  ),
                ),
                // Update indicator
                if (_hasNewUpdates)
                  GestureDetector(
                    onTap: _clearNewUpdates,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'UPDATED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Filters
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: 'Search by location, type, or description...',
                      hintStyle: TextStyle(color: Theme.of(context).hintColor),
                      prefixIcon: Icon(Icons.search, color: Theme.of(context).hintColor),
                      filled: true,
                      fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      underline: const SizedBox(),
                      value: _selectedType,
                      icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).iconTheme.color),
                      dropdownColor: Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedType = newValue!;
                        });
                      },
                      items: _incidentTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDateRange,
                          icon: Icon(Icons.calendar_today, size: 18, color: Theme.of(context).iconTheme.color),
                          label: Text(
                            'Filter: $dateLabel',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                            backgroundColor: Theme.of(context).cardColor,
                          ),
                        ),
                      ),
                      if (widget.dateRange != null)
                        IconButton(
                          onPressed: _clearDateRange,
                          icon: Icon(Icons.clear, size: 18, color: Theme.of(context).iconTheme.color),
                          tooltip: 'Clear date filter',
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (filtered.isEmpty)
              _buildEmptyState()
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildStatCard('Resolved Today', resolvedToday, Colors.green),
                      const SizedBox(width: 12),
                      _buildStatCard('Resolved Yesterday', resolvedYesterday, Colors.blue),
                      const SizedBox(width: 12),
                      _buildStatCard('Total Incidents', filtered.length, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildIncidentTable(filtered),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // KEEP ALL EXISTING UI WIDGET METHODS EXACTLY AS THEY ARE
  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Theme.of(context).hintColor),
            const SizedBox(height: 16),
            Text(
              widget.dateRange == null 
                ? 'No incidents in the last 24 hours'
                : 'No matching incidents found',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 8),
            Text(
              'New incidents will appear automatically',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(76)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentTable(List<Map<String, dynamic>> filtered) {
    return SizedBox(
      height: 300,
      child: Scrollbar(
        controller: _verticalScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalScrollController,
          child: Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 25,
                horizontalMargin: 16,
                headingRowHeight: 48,
                dataRowMinHeight: 60,
                dataRowMaxHeight: 60,
                headingRowColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) => Theme.of(context).dataTableTheme.headingRowColor?.resolve(states) ?? Colors.grey[100],
                ),
                dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) => Theme.of(context).dataTableTheme.dataRowColor?.resolve(states) ?? Colors.white,
                ),
                columns: [
                  DataColumn(
                    label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    numeric: false,
                  ),
                  DataColumn(
                    label: Text('LOCATION', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    numeric: false,
                  ),
                  DataColumn(
                    label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    numeric: false,
                  ),
                  DataColumn(
                    label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    numeric: false,
                  ),
                  DataColumn(
                    label: Text('TIME', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    numeric: false,
                  ),
                  DataColumn(
                    label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    numeric: false,
                  ),
                  DataColumn(
                    label: SizedBox(
                      width: 80,
                      child: Text('PROGRESS', 
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    numeric: false,
                  ),
                ],
                rows: filtered.map((doc) => _buildDataRow(doc)).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> doc) {
    final timestamp = doc['timestamp'] as String?;
    
    // Convert to local timezone
    final localDateTime = timestamp != null 
        ? DateTime.parse(timestamp).toLocal()
        : null;
    
    final date = localDateTime != null
        ? DateFormat('MMM d, yyyy').format(localDateTime)
        : 'N/A';
    final time = localDateTime != null
        ? DateFormat('h:mm a').format(localDateTime)
        : 'N/A';
    
    final location = (doc['address'] ?? 'Unknown').toString();
    final rawType = (doc['incident_type'] ?? '').toString();
    final status = (doc['latest_status'] ?? doc['status'] ?? 'pending').toString().toLowerCase();
    final requiresReview = doc['requiresReview'] ?? false;
    final suspicionScore = doc['suspicionScore'] ?? 0.0;
    final docId = doc['id'] as String? ?? '';

    Color statusColor;
    switch (status) {
      case 'resolved':
        statusColor = Colors.green;
        break;
      case 'in progress':
        statusColor = const Color(0xFF2196F3);
        break;
      case 'pending':
        statusColor = Colors.amber;
        break;
      case 'under review':
        statusColor = const Color.fromRGBO(156, 39, 176, 1);
        break;
      case 'declined':
        statusColor = const Color.fromARGB(255, 176, 39, 39);
        break;
      default:
        statusColor = Colors.grey;
    }

    final isSuspicious = requiresReview == true || (suspicionScore as double) > 0.5;

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Text(
                docId.isNotEmpty ? docId.substring(0, 6) : 'N/A',
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 12, color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              if (isSuspicious)
                const Padding(
                  padding: EdgeInsets.only(left: 4.0),
                  child: Icon(Icons.warning, color: Colors.red, size: 16),
                ),
            ],
          ),
        ),
        DataCell(
          SizedBox(
            width: 200,
            child: Text(
              location,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
          ),
        ),
        DataCell(
          Text(_capitalize(rawType), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        ),
        DataCell(
          Text(date, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        ),
        DataCell(
          Text(time, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        ),
        DataCell(
          _userRole == 'admin'
              ? _StatusDropdown(
                  docId: docId, 
                  currentStatus: status,
                  requiresReview: requiresReview as bool,
                  suspicionScore: suspicionScore as double,
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    _capitalize(status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
        ),
        DataCell(
          SizedBox(
            width: 80,
            child: _buildProgressIndicator(status),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(String status) {
    double progressValue;
    IconData progressIcon;
    Color progressColor;

    switch (status) {
      case 'resolved':
        progressValue = 1.0;
        progressIcon = Icons.check_circle;
        progressColor = Colors.green;
        break;
      case 'in progress':
        progressValue = 0.6;
        progressIcon = Icons.autorenew;
        progressColor = const Color(0xFF2196F3);
        break;
      case 'under review':
        progressValue = 0.3;
        progressIcon = Icons.visibility;
        progressColor = const Color.fromRGBO(156, 39, 176, 1);
        break;
      case 'declined':
        progressValue = 0.0;
        progressIcon = Icons.cancel;
        progressColor = const Color.fromARGB(255, 176, 39, 39);
        break;
      case 'pending':
      default:
        progressValue = 0.1;
        progressIcon = Icons.access_time;
        progressColor = Colors.amber;
    }

    return Tooltip(
      message: '${(progressValue * 100).toInt()}% complete',
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              progressIcon,
              color: progressColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// KEEP _StatusDropdown EXACTLY THE SAME
class _StatusDropdown extends StatefulWidget {
  final String docId;
  final String currentStatus;
  final bool requiresReview;
  final double suspicionScore;

  const _StatusDropdown({
    required this.docId,
    required this.currentStatus,
    required this.requiresReview,
    required this.suspicionScore,
  });

  @override
  State<_StatusDropdown> createState() => _StatusDropdownState();
}

class _StatusDropdownState extends State<_StatusDropdown> {
  late String _selectedStatus;
  bool _isUpdating = false;

  final List<String> statusOptions = ['pending', 'in progress', 'resolved', 'under review'];
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.green;
      case 'in progress':
        return const Color(0xFF2196F3);
      case 'pending':
        return Colors.amber;
      case 'declined':
        return const Color.fromARGB(255, 176, 39, 39);
      case 'under review':
        return const Color.fromRGBO(156, 39, 176, 1);
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (!mounted) return;
    
    setState(() => _isUpdating = true);

    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
      };

      if (newStatus == 'resolved') {
        updateData['resolvedAt'] = DateTime.now().toIso8601String();
      }

      final statusUpdate = {
        'status': newStatus,
        'timestamp': DateTime.now().toIso8601String(),
        'note': 'Status updated by admin',
        'updatedBy': _supabase.auth.currentUser?.id,
      };

      final currentDoc = await _supabase
          .from('incidents')
          .select('statusUpdates')
          .eq('id', widget.docId)
          .single();

      final currentUpdates = (currentDoc['statusUpdates'] as List?) ?? [];
      final updatedStatusUpdates = [...currentUpdates, statusUpdate];

      await _supabase
          .from('incidents')
          .update({
            ...updateData,
            'statusUpdates': updatedStatusUpdates,
          })
          .eq('id', widget.docId);

      if (mounted) {
        setState(() => _selectedStatus = newStatus);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_selectedStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor),
      ),
      child: _isUpdating
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                icon: const Icon(Icons.arrow_drop_down, size: 18),
                dropdownColor: Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                onChanged: (String? newValue) {
                  if (newValue != null && newValue != _selectedStatus) {
                    _updateStatus(newValue);
                  }
                },
                items: statusOptions.map((String status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(
                      _capitalize(status),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  String _capitalize(String input) =>
      input.isNotEmpty ? input[0].toUpperCase() + input.substring(1) : input;
}