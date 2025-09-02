import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/components/section_header.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

// CSV + path helpers
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const AnalyticsScreen({super.key, required this.onMenuPressed});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedWeekOffset = 0; // 0 = this week, -1 = last week, etc.
  DateTimeRange? _dateRange; // optional date range filter
  String _userRole = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // cache of last filtered docs for CSV export
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastFilteredDocs = [];

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    setState(() {
      _userRole = (doc.data()?['role'] as String?) ?? 'user';
    });
  }

  // Build Firestore query using dateRange if present
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
          start: now.subtract(const Duration(days: 6)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initial,
      helpText: 'Select date range for analytics',
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

  String _dateRangeLabel() {
    if (_dateRange == null) return 'All Dates';
    final f = DateFormat('MMM d, yyyy');
    return '${f.format(_dateRange!.start)} — ${f.format(_dateRange!.end)}';
  }

  // CSV export of _lastFilteredDocs
  Future<void> _exportCsv() async {
    try {
      if (_lastFilteredDocs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export.')),
        );
        return;
      }

      final rows = <List<dynamic>>[];
      rows.add(['ID', 'Location', 'Type', 'Date', 'Time', 'Status', 'Reporter']);

      final dfDate = DateFormat('yyyy-MM-dd');
      final dfTime = DateFormat('HH:mm');

      for (final doc in _lastFilteredDocs) {
        final data = doc.data();
        final ts = data['timestamp'] as Timestamp?;
        final dateStr = ts != null ? dfDate.format(ts.toDate()) : 'N/A';
        final timeStr = ts != null ? dfTime.format(ts.toDate()) : 'N/A';
        final location = (data['address'] ?? '').toString();
        final type = (data['incidentType'] ?? '').toString();
        final status = (data['status'] ?? '').toString();
        final reporter = (data['reportedBy'] ?? data['reporter'] ?? '').toString();

        rows.add([doc.id, location, type, dateStr, timeStr, status, reporter]);
      }

      final csv = const ListToCsvConverter().convert(rows);

      final dir = await getApplicationDocumentsDirectory();
      final safeFrom = _dateRange?.start != null
          ? DateFormat('yyyyMMdd').format(_dateRange!.start)
          : 'all';
      final safeTo = _dateRange?.end != null
          ? DateFormat('yyyyMMdd').format(_dateRange!.end)
          : 'all';
      final filename = 'analytics_incidents_${safeFrom}_to_$safeTo.csv';
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C5282),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: widget.onMenuPressed,
        ),
        title: const Text(
          'Analytics Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buildQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading incidents: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          // Cache docs for CSV export AFTER client-side filtering is applied
          // (we will filter further in client-side pipeline below)
          // For now take the server-side docs and process
          int totalIncidents = docs.length;
          int resolvedToday = 0;
          List<EmergencyAlert> activeAlerts = [];
          Map<String, int> typeCounts = {
            'Fire': 0,
            'Accident': 0,
            'Flood': 0,
            'Other': 0,
          };

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          // Client-side final list (we may want to further filter by something later)
          final clientFiltered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          for (var doc in docs) {
            final data = doc.data();
            final ts = data['timestamp'] as Timestamp?;
            final date = ts?.toDate() ?? DateTime.now();
            final typeRaw = (data['incidentType'] ?? '').toString().toLowerCase();
            final type = typeRaw;
            final status = (data['status'] ?? 'pending').toString().toLowerCase();
            final location = (data['address'] ?? 'Unknown').toString();

            // Type counts
            if (type.contains('fire')) {
              typeCounts['Fire'] = typeCounts['Fire']! + 1;
            } else if (type.contains('accident')) {
              typeCounts['Accident'] = typeCounts['Accident']! + 1;
            } else if (type.contains('flood')) {
              typeCounts['Flood'] = typeCounts['Flood']! + 1;
            } else {
              typeCounts['Other'] = typeCounts['Other']! + 1;
            }

            // resolved today
            final resolvedTs = data['resolvedAt'] as Timestamp?;
            if (status == 'resolved' && resolvedTs != null) {
              final resolvedDate = DateTime(
                  resolvedTs.toDate().year,
                  resolvedTs.toDate().month,
                  resolvedTs.toDate().day);
              if (resolvedDate == today) resolvedToday++;
            }

            // active alerts
            if (status != 'resolved') {
              activeAlerts.add(EmergencyAlert(
                _capitalize(type),
                location,
                status,
                Icons.warning,
                Colors.orange,
              ));
            }

            // Add to final client list
            clientFiltered.add(doc);
          }

          // Cache the clientFiltered docs for CSV export (map to Map<String,dynamic> typed list)
          _lastFilteredDocs = clientFiltered;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header + actions (date range picker + export)
                Row(
                  children: [
                    const Expanded(
                      child: SectionHeader(
                        icon: Icons.analytics_outlined,
                        title: 'ANALYTICS',
                      ),
                    ),
                    // Date range display + pick/clear buttons
                    OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(_dateRangeLabel()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_dateRange != null)
                      IconButton(
                        onPressed: _clearDateRange,
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear date range',
                      ),
                    const SizedBox(width: 8),
                    // Export button - only for admin
                    if (_userRole == 'admin')
                      ElevatedButton.icon(
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
                  ],
                ),
                const SizedBox(height: 8),

                _buildTopStats(activeAlerts.length, resolvedToday, totalIncidents),
                const SizedBox(height: 24),
                _buildChartsSection(clientFiltered, typeCounts),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Top stats row ---
  Widget _buildTopStats(int activeCount, int resolvedToday, int totalIncidents) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard("Active Emergencies", activeCount.toString(),
            Icons.warning, Colors.orange),
        _buildStatCard("Resolved Today", resolvedToday.toString(),
            Icons.check_circle, Colors.green),
        _buildStatCard("Total Incidents", totalIncidents.toString(),
            Icons.list_alt, Colors.blue),
        if (_userRole == 'admin')
          _buildStatCard("Export Allowed", "Yes", Icons.lock_open, Colors.teal)
        else
          _buildStatCard("Export Allowed", "No", Icons.lock, Colors.grey),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // --- Charts ---
  Widget _buildChartsSection(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      Map<String, int> typeCounts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Week start and end for selected offset
    final startOfWeek = today
        .subtract(Duration(days: today.weekday - 1))
        .add(Duration(days: 7 * _selectedWeekOffset));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    // Weekly buckets
    Map<String, int> weekly = {
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };

    for (var doc in docs) {
      final data = doc.data();
      final ts = data['timestamp'] as Timestamp?;
      if (ts == null) continue;
      final date = ts.toDate();

      // If user set a date range, the stream already filtered server-side,
      // and docs reflect that range. However we still must ensure the weekly
      // chart only counts items that fall within startOfWeek..endOfWeek
      if (date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
          date.isBefore(endOfWeek.add(const Duration(days: 1)))) {
        final weekday = _weekdayName(date.weekday);
        weekly[weekday] = (weekly[weekday] ?? 0) + 1;
      }
    }

    final weeklyCases =
        weekly.entries.map((e) => EmergencyCase(e.key, e.value)).toList();

    final weekLabel = _selectedWeekOffset == 0
        ? "This Week"
        : _selectedWeekOffset == -1
            ? "Last Week"
            : "${_selectedWeekOffset.abs()} Weeks Ago";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Emergency Cases",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            DropdownButton<int>(
              value: _selectedWeekOffset,
              items: const [
                DropdownMenuItem(value: 0, child: Text("This Week")),
                DropdownMenuItem(value: -1, child: Text("Last Week")),
                DropdownMenuItem(value: -2, child: Text("2 Weeks Ago")),
                DropdownMenuItem(value: -3, child: Text("3 Weeks Ago")),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedWeekOffset = val);
                }
              },
            ),
          ],
        ),
        Text("Showing: $weekLabel (${_formatDate(startOfWeek)} - ${_formatDate(endOfWeek)})",
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: SfCartesianChart(
            primaryXAxis: CategoryAxis(),
            series: <CartesianSeries>[
              ColumnSeries<EmergencyCase, String>(
                dataSource: weeklyCases,
                xValueMapper: (EmergencyCase data, _) => data.day,
                yValueMapper: (EmergencyCase data, _) => data.count,
                color: Colors.red,
                dataLabelSettings: const DataLabelSettings(isVisible: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text("Incident Types Breakdown",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: SfCircularChart(
            legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
            series: <CircularSeries>[
              PieSeries<MapEntry<String, int>, String>(
                dataSource: typeCounts.entries.toList(),
                xValueMapper: (entry, _) => entry.key,
                yValueMapper: (entry, _) => entry.value,
                dataLabelMapper: (entry, _) => "${entry.key}: ${entry.value}",
                dataLabelSettings: const DataLabelSettings(isVisible: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _weekdayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }

  String _formatDate(DateTime date) {
    return "${date.month}/${date.day}";
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}

class EmergencyAlert {
  final String title;
  final String location;
  final String status;
  final IconData icon;
  final Color color;

  EmergencyAlert(this.title, this.location, this.status, this.icon, this.color);
}

class EmergencyCase {
  final String day;
  final int count;

  EmergencyCase(this.day, this.count);
}
