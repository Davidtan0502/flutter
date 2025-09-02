import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/components/section_header.dart';

// NEW: CSV + file path helpers
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _searchQuery = '';
  String _selectedType = 'All';
  String _userRole = '';

  // NEW: Date range filter
  DateTimeRange? _dateRange;

  // Keep the latest filtered snapshot for CSV export
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastFilteredDocs = [];

  final List<String> _incidentTypes = const [
    'All',
    'Fire',
    'Accident',
    'Flood',
    'Other Accidents',
  ];

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _userRole = (doc.data()?['role'] as String?) ?? 'user';
      });
    }
  }

  String _capitalize(String input) =>
      input.isNotEmpty ? input[0].toUpperCase() + input.substring(1) : input;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // Build a Firestore query based on date range (server-side filtering)
  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('incidents');

    // If date range is set, apply where filters. Always orderBy timestamp when filtering by it.
    if (_dateRange != null) {
      final start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
        0,
        0,
        0,
      );
      final end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
        999,
      );
      q = q
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('timestamp', descending: true);
    } else {
      q = q.orderBy('timestamp', descending: true);
    }

    return q;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initial,
      helpText: 'Select Incident Date Range',
      saveText: 'Apply',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Colors.redAccent,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  void _clearDateRange() {
    setState(() => _dateRange = null);
  }

  Future<void> _exportCsv() async {
    try {
      if (_lastFilteredDocs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export.')),
          );
        }
        return;
      }

      // Build rows: header + data
      final rows = <List<dynamic>>[];
      rows.add([
        'ID',
        'Location',
        'Type',
        'Date',
        'Time',
        'Status',
        'Reporter',
      ]);

      final dfDate = DateFormat('MMM d, yyyy');
      final dfTime = DateFormat('h:mm a');

      for (final doc in _lastFilteredDocs) {
        final data = doc.data();
        final ts = data['timestamp'] as Timestamp?;
        final dateStr = ts != null ? dfDate.format(ts.toDate()) : 'N/A';
        final timeStr = ts != null ? dfTime.format(ts.toDate()) : 'N/A';
        final location = (data['address'] ?? '').toString();
        final type = (data['incidentType'] ?? '').toString();
        final status = (data['status'] ?? '').toString();
        final reporter = (data['reportedBy'] ?? data['reporter'] ?? '').toString();

        rows.add([
          doc.id,
          location,
          type,
          dateStr,
          timeStr,
          status,
          reporter,
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);

      // Choose a writable directory and file name
      final dir = await getApplicationDocumentsDirectory();
      final safeFrom = _dateRange?.start != null
          ? DateFormat('yyyyMMdd').format(_dateRange!.start)
          : 'all';
      final safeTo = _dateRange?.end != null
          ? DateFormat('yyyyMMdd').format(_dateRange!.end)
          : 'all';
      final filename = 'incidents_${safeFrom}_to_$safeTo.csv';

      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV exported: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = () {
      if (_dateRange == null) return 'All Dates';
      final f = DateFormat('MMM d, yyyy');
      return '${f.format(_dateRange!.start)}  —  ${f.format(_dateRange!.end)}';
    }();

    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + actions row
            Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    icon: Icons.warning_amber_outlined,
                    title: 'EMERGENCIES',
                  ),
                ),
                // Export button (always visible)
                Tooltip(
                  message: 'Export filtered results to CSV',
                  child: ElevatedButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.download),
                    label: const Text('Export CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Search + type filter + date filter row
            Row(
              children: [
                // Search
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by location or type',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Type dropdown
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      underline: const SizedBox(),
                      value: _selectedType,
                      icon: const Icon(Icons.arrow_drop_down),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedType = newValue!;
                        });
                      },
                      items: _incidentTypes
                          .map<DropdownMenuItem<String>>((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Date range selector
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDateRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            dateLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_dateRange != null)
                        Tooltip(
                          message: 'Clear date range',
                          child: IconButton(
                            onPressed: _clearDateRange,
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Stream + table + stats
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error loading incidents',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final allDocs = snapshot.data!.docs;

                // Stats (resolved today / yesterday)
                final today = DateTime.now();
                final yesterday = today.subtract(const Duration(days: 1));
                int resolvedToday = 0;
                int resolvedYesterday = 0;

                for (var doc in allDocs) {
                  final data = doc.data();
                  final resolvedAt = data['resolvedAt'] as Timestamp?;
                  if (resolvedAt != null) {
                    final d = resolvedAt.toDate();
                    if (_isSameDay(d, today)) resolvedToday++;
                    if (_isSameDay(d, yesterday)) resolvedYesterday++;
                  }
                }

                // Client-side filters: search + type
                final filtered = allDocs.where((doc) {
                  final data = doc.data();
                  final location =
                      (data['address'] ?? '').toString().toLowerCase();
                  final type =
                      (data['incidentType'] ?? '').toString().toLowerCase();

                  final matchesSearch = _searchQuery.isEmpty ||
                      location.contains(_searchQuery) ||
                      type.contains(_searchQuery);

                  final matchesType = _selectedType == 'All' ||
                      type == _selectedType.toLowerCase();

                  return matchesSearch && matchesType;
                }).toList();

                // Update last filtered cache for CSV export
                _lastFilteredDocs = filtered;

                if (filtered.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Text('No matching incidents found')),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats
                    Row(
                      children: [
                        _buildStatCard('Resolved Today', resolvedToday, Colors.green),
                        const SizedBox(width: 12),
                        _buildStatCard(
                            'Resolved Yesterday', resolvedYesterday, Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Table
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text('$count',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentTable(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered) {
    return SizedBox(
      height: 250,
      child: Scrollbar(
        controller: _verticalScrollController,
        child: SingleChildScrollView(
          controller: _verticalScrollController,
          scrollDirection: Axis.vertical,
          child: Scrollbar(
            controller: _horizontalScrollController,
            notificationPredicate: (n) => n.depth == 1,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 52,
                horizontalMargin: 16,
                headingRowHeight: 40,
                dataRowHeight: 56,
                columns: const [
                  DataColumn(
                      label: Text('ID',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      numeric: true),
                  DataColumn(
                      label: Text('LOCATION',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(
                      label: Text('TYPE',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(
                      label: Text('DATE',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(
                      label: Text('TIME',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(
                      label: Text('STATUS',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
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
    final normalizedType = rawType.toLowerCase();
    final status = (data['status'] ?? 'pending').toString().toLowerCase();

    final knownTypes = ['fire', 'accident', 'flood'];
    final incidentType =
        knownTypes.contains(normalizedType) ? _capitalize(normalizedType) : 'Others';

    Color statusColor;
    switch (status) {
      case 'resolved':
        statusColor = Colors.green;
        break;
      case 'in progress':
        statusColor = Colors.orange;
        break;
      case 'pending':
        statusColor = Colors.amber;
        break;
      default:
        statusColor = Colors.grey;
    }

    return DataRow(
      cells: [
        DataCell(Text(doc.id.substring(0, 4),
            style: const TextStyle(fontSize: 12, fontFamily: 'RobotoMono'))),
        DataCell(SizedBox(
          width: 170,
          child: Text(
            location,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        )),
        DataCell(SizedBox(
          width: 80,
          child: Text(
            incidentType,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        )),
        DataCell(Text(date, style: const TextStyle(fontSize: 12))),
        DataCell(Text(time, style: const TextStyle(fontSize: 12))),
        DataCell(
          _userRole == 'admin'
              ? _StatusDropdown(docId: doc.id, currentStatus: status)
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    _capitalize(status),
                    style: TextStyle(
                        fontSize: 12, color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatusDropdown extends StatefulWidget {
  final String currentStatus;
  final String docId;

  const _StatusDropdown({required this.currentStatus, required this.docId});

  @override
  State<_StatusDropdown> createState() => _StatusDropdownState();
}

class _StatusDropdownState extends State<_StatusDropdown> {
  final List<String> statusOptions = const ['Pending', 'In Progress', 'Resolved'];
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = _capitalize(widget.currentStatus);
  }

  static String _capitalize(String input) =>
      input.isNotEmpty ? input[0].toUpperCase() + input.substring(1) : input;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'in progress':
        return Colors.orange;
      case 'pending':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_selectedStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          onChanged: (String? newValue) async {
            if (newValue == null) return;

            setState(() {
              _selectedStatus = newValue;
            });

            final lower = newValue.toLowerCase();
            final update = <String, dynamic>{
              'status': lower,
              // set resolvedAt when moving to resolved; clear if moved away
              'resolvedAt': lower == 'resolved'
                  ? FieldValue.serverTimestamp()
                  : null,
            };

            // If you prefer to *not* delete resolvedAt when status changes away
            // from resolved, replace the 'null' above with FieldValue.delete().

            await FirebaseFirestore.instance
                .collection('incidents')
                .doc(widget.docId)
                .update(update);
          },
          items: statusOptions.map((String status) {
            return DropdownMenuItem<String>(
              value: status,
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(status),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
