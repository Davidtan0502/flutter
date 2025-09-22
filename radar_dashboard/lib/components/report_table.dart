import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/components/section_header.dart';

class ReportTableScreen extends StatefulWidget {
  final DateTimeRange? dateRange;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  const ReportTableScreen({
    super.key,
    required this.dateRange,
    required this.onDateRangeChanged,
  });

  @override
  State<ReportTableScreen> createState() => _ReportTableScreenState();
}

class _ReportTableScreenState extends State<ReportTableScreen> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedType = 'All';
  String _userRole = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastFilteredDocs = [];

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
    _getUserRole();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getUserRole() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _userRole = (doc.data()?['role'] as String?) ?? 'user';
      });
    }
  }

  String _capitalize(String input) =>
      input.isNotEmpty ? input[0].toUpperCase() + input.substring(1) : input;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('incidents');

    if (widget.dateRange != null) {
      // Use the user-selected range
      final start = DateTime(
        widget.dateRange!.start.year,
        widget.dateRange!.start.month,
        widget.dateRange!.start.day,
        0, 0, 0,
      );
      final end = DateTime(
        widget.dateRange!.end.year,
        widget.dateRange!.end.month,
        widget.dateRange!.end.day,
        23, 59, 59, 999,
      );

      q = q
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end));
    } else {
      // Default: incidents from today (midnight → now)
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);

      q = q
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(now));
    }

    // Always order by most recent first
    return q.orderBy('timestamp', descending: true);
  }

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
    lastDate: now, // Don't allow future dates
    initialDateRange: initial,
    helpText: 'Select Incident Date Range',
    saveText: 'Apply',
  );

  if (picked != null) {
    // Allow single day selection by checking if start and end are the same day
    if (picked.start.year == picked.end.year &&
        picked.start.month == picked.end.month &&
        picked.start.day == picked.end.day) {
      // Single day selected - use the same day for both start and end
      widget.onDateRangeChanged(picked);
    } else {
      // Multi-day range selected
      widget.onDateRangeChanged(picked);
    }
  }
}

  void _clearDateRange() {
    widget.onDateRangeChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final dailyStart = now.subtract(const Duration(hours: 24));
    
    final dateRange = widget.dateRange ?? DateTimeRange(start: dailyStart, end: now);
    
  final dateLabel = widget.dateRange == null 
      ? 'Today' 
      : _isSameDay(widget.dateRange!.start, widget.dateRange!.end)
          ? DateFormat('MMM d, yyyy').format(widget.dateRange!.start) // Single day
          : '${DateFormat('MMM d, yyyy').format(widget.dateRange!.start)} - ${DateFormat('MMM d, yyyy').format(widget.dateRange!.end)}'; // Date range

    return Card(
      color: Theme.of(context).cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    icon: Icons.warning_amber_outlined,
                    title: 'EMERGENCIES',
                    subtitle: '',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

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
                      dropdownColor: Theme.of(context).dialogBackgroundColor,
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

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading incidents: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final allDocs = snapshot.data!.docs;
                final today = DateTime.now();
                final yesterday = today.subtract(const Duration(days: 1));
                int resolvedToday = 0;
                int resolvedYesterday = 0;

                for (var doc in allDocs) {
                  final data = doc.data();
                  final status = (data['status'] ?? '').toString().toLowerCase();

                  if (status == 'resolved') {
                    // Use resolvedAt if available, otherwise fallback to main timestamp
                    final resolvedAt = data['resolvedAt'] as Timestamp?;
                    final ts = resolvedAt ?? data['timestamp'] as Timestamp?;
                    if (ts != null) {
                      final d = ts.toDate();
                      if (_isSameDay(d, today)) resolvedToday++;
                      if (_isSameDay(d, yesterday)) resolvedYesterday++;
                    }
                  }
                }

                final filtered = allDocs.where((doc) {
                  final data = doc.data();
                  final location = (data['address'] ?? '').toString().toLowerCase();
                  final type = (data['incidentType'] ?? '').toString().toLowerCase();
                  final contactNumber = (data['contactNumber'] ?? '').toString().toLowerCase();
                  final description = (data['description'] ?? '').toString().toLowerCase();

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

                _lastFilteredDocs = filtered;

                if (filtered.isEmpty) {
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        widget.dateRange == null 
                          ? 'No incidents in the last 24 hours'
                          : 'No matching incidents found',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ),
                  );
                }

                return Column(
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
                );
              },
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
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

  Widget _buildIncidentTable(List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered) {
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
                dataRowHeight: 60,
                headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) => Theme.of(context).dataTableTheme.headingRowColor?.resolve(states) ?? Colors.grey[100],
                ),
                dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) => Theme.of(context).dataTableTheme.dataRowColor?.resolve(states) ?? Colors.white,
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

  DataRow _buildDataRow(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('MMM d, yyyy').format(timestamp.toDate())
        : 'N/A';
    final time = timestamp != null
        ? DateFormat('h:mm a').format(timestamp.toDate())
        : 'N/A';
    final location = (data['address'] ?? 'Unknown').toString();
    final rawType = (data['incidentType'] ?? '').toString();
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final requiresReview = data['requiresReview'] ?? false;
    final suspicionScore = data['suspicionScore'] ?? 0.0;

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
                doc.id.substring(0, 6),
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
                  docId: doc.id, 
                  currentStatus: status,
                  requiresReview: requiresReview as bool,
                  suspicionScore: suspicionScore as double,
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: '${(progressValue * 100).toInt()}% complete',
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Progress bar (visible on hover)
              MouseRegion(
                child: AnimatedOpacity(
                  opacity: 0,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: 80,
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: progressColor.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ),
              ),
              // Icon (always visible)
              Icon(
                progressIcon,
                color: progressColor,
                size: 20,
              ),
              // Progress bar on hover
              MouseRegion(
                child: AnimatedOpacity(
                  opacity: 0,
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: 80,
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: progressColor.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    setState(() => _isUpdating = true);

    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
      };

      if (newStatus == 'resolved') {
        updateData['resolvedAt'] = FieldValue.serverTimestamp();
      }

      // Add to status updates timeline
      final statusUpdate = {
        'status': newStatus,
        'timestamp': FieldValue.serverTimestamp(),
        'note': 'Status updated by admin',
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      };

      await FirebaseFirestore.instance.collection('incidents').doc(widget.docId).update({
        ...updateData,
        'statusUpdates': FieldValue.arrayUnion([statusUpdate]),
      });

      setState(() => _selectedStatus = newStatus);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_selectedStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor),
      ),
      child: _isUpdating
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                icon: const Icon(Icons.arrow_drop_down, size: 18),
                dropdownColor: Theme.of(context).dialogBackgroundColor,
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