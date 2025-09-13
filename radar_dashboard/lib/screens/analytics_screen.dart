import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/components/section_header.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class AnalyticsScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const AnalyticsScreen({super.key, required this.onMenuPressed});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class EmergencyCase {
  final String day;
  final int count;

  EmergencyCase(this.day, this.count);
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedWeekOffset = 0;
  DateTimeRange? _dateRange;
  String _userRole = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastFilteredDocs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _userRole = (doc.data()?['role'] as String?) ?? 'user';
      });
    } catch (e) {
      debugPrint('Error getting user role: $e');
    }
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('incidents');

    if (_dateRange != null) {
      final start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
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
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
      helpText: 'Select Analytics Date Range',
      saveText: 'Apply',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[800]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
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

  String _dateRangeLabel() {
    if (_dateRange == null) return 'All Time';
    final f = DateFormat('MMM d, yyyy');
    return '${f.format(_dateRange!.start)} - ${f.format(_dateRange!.end)}';
  }

  Future<void> _exportCsv() async {
    try {
      if (_lastFilteredDocs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No data to export'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final rows = <List<dynamic>>[];
      rows.add([
        'ID',
        'Incident Type',
        'Location',
        'Status',
        'Reported By',
        'Contact Number',
        'Date',
        'Time',
        'Description',
        'Latitude',
        'Longitude',
        'Requires Review',
        'Suspicion Score'
      ]);

      final dfDate = DateFormat('yyyy-MM-dd');
      final dfTime = DateFormat('HH:mm:ss');

      for (final doc in _lastFilteredDocs) {
        final data = doc.data();
        final ts = data['timestamp'] as Timestamp?;
        final dateStr = ts != null ? dfDate.format(ts.toDate()) : 'N/A';
        final timeStr = ts != null ? dfTime.format(ts.toDate()) : 'N/A';
        final location = (data['address'] ?? '').toString();
        final type = (data['incidentType'] ?? '').toString();
        final status = (data['status'] ?? '').toString();
        final reporter = (data['name'] ?? data['reportedBy'] ?? 'Anonymous').toString();
        final contact = (data['contactNumber'] ?? '').toString();
        final description = (data['description'] ?? '').toString();
        final latitude = (data['latitude'] ?? 0.0).toString();
        final longitude = (data['longitude'] ?? 0.0).toString();
        final requiresReview = (data['requiresReview'] ?? false).toString();
        final suspicionScore = (data['suspicionScore'] ?? 0.0).toString();

        rows.add([
          doc.id.substring(0, 8),
          type,
          location,
          status,
          reporter,
          contact,
          dateStr,
          timeStr,
          description.replaceAll('\n', ' '),
          latitude,
          longitude,
          requiresReview,
          suspicionScore
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final safeFrom = _dateRange?.start != null
          ? DateFormat('yyyyMMdd').format(_dateRange!.start)
          : 'all';
      final safeTo = _dateRange?.end != null
          ? DateFormat('yyyyMMdd').format(_dateRange!.end)
          : 'all';
      final filename = 'radar_analytics_${safeFrom}_to_$safeTo.csv';
      final file = File('${dir.path}/$filename');

      await file.writeAsString(csv);
      await OpenFile.open(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('CSV exported successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Map<String, dynamic> _processIncidents(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int totalIncidents = docs.length;
    int resolvedToday = 0;
    int activeAlerts = 0;
    int underReview = 0;
    Map<String, int> typeCounts = {
      'Fire': 0,
      'Accident': 0,
      'Flood': 0,
      'Other': 0,
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var doc in docs) {
      final data = doc.data();
      final status = (data['status'] ?? 'pending').toString().toLowerCase();
      final typeRaw = (data['incidentType'] ?? '').toString().toLowerCase();

      // Type classification
      if (typeRaw.contains('fire')) {
        typeCounts['Fire'] = typeCounts['Fire']! + 1;
      } else if (typeRaw.contains('accident')) {
        typeCounts['Accident'] = typeCounts['Accident']! + 1;
      } else if (typeRaw.contains('flood')) {
        typeCounts['Flood'] = typeCounts['Flood']! + 1;
      } else {
        typeCounts['Other'] = typeCounts['Other']! + 1;
      }

      // Status counts
      if (status == 'resolved') {
        final resolvedTs = data['resolvedAt'] as Timestamp?;
        if (resolvedTs != null) {
          final resolvedDate = DateTime(
            resolvedTs.toDate().year,
            resolvedTs.toDate().month,
            resolvedTs.toDate().day,
          );
          if (resolvedDate == today) resolvedToday++;
        }
      } else if (status == 'under review') {
        underReview++;
      } else {
        activeAlerts++;
      }
    }

    return {
      'totalIncidents': totalIncidents,
      'resolvedToday': resolvedToday,
      'activeAlerts': activeAlerts,
      'underReview': underReview,
      'typeCounts': typeCounts,
    };
  }

  List<EmergencyCase> _getWeeklyData(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1 + (7 * _selectedWeekOffset.abs())));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    Map<String, int> weeklyData = {
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
      if (date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
          date.isBefore(endOfWeek.add(const Duration(days: 1)))) {
        final weekday = _weekdayName(date.weekday);
        weeklyData[weekday] = weeklyData[weekday]! + 1;
      }
    }

    return weeklyData.entries
        .map((e) => EmergencyCase(e.key, e.value))
        .toList();
  }

  String _weekdayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }

  String _getWeekLabel() {
    if (_selectedWeekOffset == 0) return "This Week";
    if (_selectedWeekOffset == -1) return "Last Week";
    return "${_selectedWeekOffset.abs()} Weeks Ago";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C5282),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: widget.onMenuPressed,
        ),
        title: const Text(
          'ANALYTICS DASHBOARD',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buildQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            _isLoading = false;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading data\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            _isLoading = false;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No incident data available',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          _lastFilteredDocs = docs;
          _isLoading = false;

          final analytics = _processIncidents(docs);
          final weeklyData = _getWeeklyData(docs);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeaderSection(),
                const SizedBox(height: 24),

                // Statistics Cards
                _buildStatisticsSection(analytics),
                const SizedBox(height: 32),

                // Charts Section
                _buildChartsSection(analytics['typeCounts'] as Map<String, int>, weeklyData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      children: [
        const Expanded(
          child: SectionHeader(
            icon: Icons.analytics,
            title: 'ANALYTICS OVERVIEW',
            subtitle: 'Real-time incident statistics and trends',
          ),
        ),
        // Date Range Picker
        OutlinedButton.icon(
          onPressed: _pickDateRange,
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(_dateRangeLabel()),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: Colors.blue[800]!),
          ),
        ),
        if (_dateRange != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.clear, size: 20),
            onPressed: _clearDateRange,
            tooltip: 'Clear date range',
          ),
        ],
        const SizedBox(width: 16),
        // Export Button
        if (_userRole == 'admin')
          ElevatedButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }

  Widget _buildStatisticsSection(Map<String, dynamic> analytics) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard(
          'Total Incidents',
          analytics['totalIncidents'].toString(),
          Icons.warning_amber,
          Colors.orange,
        ),
        _buildStatCard(
          'Active Alerts',
          analytics['activeAlerts'].toString(),
          Icons.error,
          Colors.red,
        ),
        _buildStatCard(
          'Resolved Today',
          analytics['resolvedToday'].toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Under Review',
          analytics['underReview'].toString(),
          Icons.visibility,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
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

  Widget _buildChartsSection(Map<String, int> typeCounts, List<EmergencyCase> weeklyData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weekly Chart
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Weekly Incident Trends',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _selectedWeekOffset,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('This Week')),
                        DropdownMenuItem(value: -1, child: Text('Last Week')),
                        DropdownMenuItem(value: -2, child: Text('2 Weeks Ago')),
                        DropdownMenuItem(value: -3, child: Text('3 Weeks Ago')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedWeekOffset = value);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getWeekLabel(),
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                    primaryYAxis: NumericAxis(
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                    series: <CartesianSeries>[
                      ColumnSeries<EmergencyCase, String>(
                        dataSource: weeklyData,
                        xValueMapper: (data, _) => data.day,
                        yValueMapper: (data, _) => data.count,
                        color: Colors.blue[800],
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                          textStyle: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Pie Chart
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Incident Type Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Breakdown by incident category',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: SfCircularChart(
                    legend: Legend(
                      isVisible: true,
                      overflowMode: LegendItemOverflowMode.wrap,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    series: <CircularSeries>[
                      PieSeries<MapEntry<String, int>, String>(
                        dataSource: typeCounts.entries.toList(),
                        xValueMapper: (entry, _) => entry.key,
                        yValueMapper: (entry, _) => entry.value,
                        dataLabelMapper: (entry, _) => '${entry.value}',
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                          textStyle: TextStyle(fontSize: 12),
                        ),
                        pointColorMapper: (entry, _) => _getColorForType(entry.key),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Fire':
        return Colors.red;
      case 'Accident':
        return Colors.orange;
      case 'Flood':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}