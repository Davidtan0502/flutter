
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/components/section_header.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedType = 'All';
  String _userRole = '';
  DateTimeRange? _dateRange;
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
          start: DateTime(now.year, now.month - 1, now.day),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initial,
      helpText: 'Select Incident Date Range',
      saveText: 'Apply',
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

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dateRange == null 
        ? 'All Dates' 
        : '${DateFormat('MMM d, yyyy').format(_dateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_dateRange!.end)}';

    return Card(
      color: Colors.white,
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
                    title: 'EMERGENCIES', subtitle: '',
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
                    decoration: InputDecoration(
                      hintText: 'Search by location, type, or description...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[50],
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
                      color: Colors.grey[50],
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
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            dateLabel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (_dateRange != null)
                        IconButton(
                          onPressed: _clearDateRange,
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Clear date range',
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
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'No matching incidents found',
                        style: TextStyle(color: Colors.grey),
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
        child: SingleChildScrollView(
          controller: _verticalScrollController,
          child: Scrollbar(
            controller: _horizontalScrollController,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                horizontalMargin: 16,
                headingRowHeight: 48,
                dataRowHeight: 60,
                columns: const [
                  DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('LOCATION', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('TIME', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
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
                style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 12),
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
            ),
          ),
        ),
        DataCell(Text(_capitalize(rawType))),
        DataCell(Text(date)),
        DataCell(Text(time)),
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
          IconButton(
            icon: const Icon(Icons.visibility, size: 18),
            onPressed: () {
              // Add view details functionality
              _showIncidentDetails(doc);
            },
          ),
        ),
      ],
    );
  }

  void _showIncidentDetails(DocumentSnapshot<Map<String, dynamic>> doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Incident Details'),
        content: SingleChildScrollView(
          child: Text('Details for incident: ${doc.id}'),
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