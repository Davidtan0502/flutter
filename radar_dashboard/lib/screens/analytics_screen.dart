import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/components/section_header.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

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
  Timer? _debounce;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _getUserRole();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      setState(() {
        _isOffline = (result.isEmpty || result.contains(ConnectivityResult.none));
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _userRole = (doc.data()?['role'] as String?) ?? 'user';
      });
    } catch (e) {
      debugPrint('Error getting user role: $e');
    }
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('incidents');

    if (_dateRange != null) {
      final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
      final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 23, 59, 59);

      q = q
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('timestamp', descending: true);
    } else {
      // Limit to last 90 days if no date range selected to avoid huge data loads
      final recentLimitDate = DateTime.now().subtract(const Duration(days: 90));
      q = q
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(recentLimitDate))
          .orderBy('timestamp', descending: true);
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
      // Debounce to avoid rapid query changes
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        setState(() {
          _dateRange = picked;
        });
      });
    }
  }

  void _clearDateRange() {
    setState(() => _dateRange = null);
  }

  String _dateRangeLabel() {
    if (_dateRange == null) return 'Last 90 Days';
    final f = DateFormat('MMM d, yyyy');
    return '${f.format(_dateRange!.start)} - ${f.format(_dateRange!.end)}';
  }

  Map<String, dynamic> _processIncidents(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int totalIncidents = docs.length;
    int resolvedToday = 0;
    int activeAlerts = 0;
    int underReview = 0;
    int criticalAlerts = 0;
    Map<String, int> typeCounts = {
      'Fire': 0,
      'Accident': 0,
      'Flood': 0,
      'Earthquake': 0,
      'Tsunami': 0,
      'Hurricane': 0,
      'Medical Emergency': 0,
      'Civil Unrest': 0,
      'Infrastructure Failure': 0,
      'Environmental Hazard': 0,
      'Other': 0,
    };
    Map<String, int> severityCounts = {
      'Critical': 0,
      'High': 0,
      'Medium': 0,
      'Low': 0,
      'Unknown': 0,
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    double totalResponseTime = 0;
    int respondedIncidents = 0;
    List<Map<String, dynamic>> recentCriticalIncidents = [];

    for (var doc in docs) {
      final data = doc.data();
      final status = (data['status'] ?? 'pending').toString().toLowerCase();
      final typeRaw = (data['incidentType'] ?? '').toString().toLowerCase();
      final severity = (data['severity'] ?? 'unknown').toString().toLowerCase();
      final reportedTs = data['timestamp'] as Timestamp?;
      final resolvedTs = data['resolvedAt'] as Timestamp?;

      // Type classification
      if (typeRaw.contains('fire')) {
        typeCounts['Fire'] = typeCounts['Fire']! + 1;
      } else if (typeRaw.contains('accident') || typeRaw.contains('crash')) {
        typeCounts['Accident'] = typeCounts['Accident']! + 1;
      } else if (typeRaw.contains('flood') || typeRaw.contains('flooding')) {
        typeCounts['Flood'] = typeCounts['Flood']! + 1;
      } else if (typeRaw.contains('earthquake') || typeRaw.contains('quake')) {
        typeCounts['Earthquake'] = typeCounts['Earthquake']! + 1;
      } else if (typeRaw.contains('tsunami')) {
        typeCounts['Tsunami'] = typeCounts['Tsunami']! + 1;
      } else if (typeRaw.contains('hurricane') || typeRaw.contains('typhoon') || typeRaw.contains('cyclone')) {
        typeCounts['Hurricane'] = typeCounts['Hurricane']! + 1;
      } else if (typeRaw.contains('medical') || typeRaw.contains('health') || typeRaw.contains('injury')) {
        typeCounts['Medical Emergency'] = typeCounts['Medical Emergency']! + 1;
      } else if (typeRaw.contains('unrest') || typeRaw.contains('riot') || typeRaw.contains('protest')) {
        typeCounts['Civil Unrest'] = typeCounts['Civil Unrest']! + 1;
      } else if (typeRaw.contains('infrastructure') || typeRaw.contains('power') || typeRaw.contains('water') || typeRaw.contains('bridge')) {
        typeCounts['Infrastructure Failure'] = typeCounts['Infrastructure Failure']! + 1;
      } else if (typeRaw.contains('environmental') || typeRaw.contains('chemical') || typeRaw.contains('spill') || typeRaw.contains('pollution')) {
        typeCounts['Environmental Hazard'] = typeCounts['Environmental Hazard']! + 1;
      } else {
        typeCounts['Other'] = typeCounts['Other']! + 1;
      }

      // Severity classification
      if (severity.contains('critical')) {
        severityCounts['Critical'] = severityCounts['Critical']! + 1;
        if (status != 'resolved') {
          criticalAlerts++;
        }
      } else if (severity.contains('high')) {
        severityCounts['High'] = severityCounts['High']! + 1;
      } else if (severity.contains('medium')) {
        severityCounts['Medium'] = severityCounts['Medium']! + 1;
      } else if (severity.contains('low')) {
        severityCounts['Low'] = severityCounts['Low']! + 1;
      } else {
        severityCounts['Unknown'] = severityCounts['Unknown']! + 1;
      }

      // Response time calculation
      if (reportedTs != null && resolvedTs != null) {
        final responseTime = resolvedTs.toDate().difference(reportedTs.toDate()).inMinutes;
        totalResponseTime += responseTime;
        respondedIncidents++;
      }

      // Critical incident tracking
      if (severity == 'critical' && reportedTs != null) {
        final incidentTime = reportedTs.toDate();
        final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));

        if (incidentTime.isAfter(twentyFourHoursAgo)) {
          recentCriticalIncidents.add({
            'id': doc.id,
            'type': data['incidentType'],
            'location': data['address'],
            'time': incidentTime,
          });
        }
      }

      // Status counts
      if (status == 'resolved') {
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

    final averageResponseTime = respondedIncidents > 0 ? totalResponseTime / respondedIncidents : 0;

    return {
      'totalIncidents': totalIncidents,
      'resolvedToday': resolvedToday,
      'activeAlerts': activeAlerts,
      'underReview': underReview,
      'criticalAlerts': criticalAlerts,
      'typeCounts': typeCounts,
      'severityCounts': severityCounts,
      'averageResponseTime': averageResponseTime,
      'respondedIncidents': respondedIncidents,
      'recentCriticalIncidents': recentCriticalIncidents,
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

    return weeklyData.entries.map((e) => EmergencyCase(e.key, e.value)).toList();
  }

  Map<String, int> _getMonthlyData(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    Map<String, int> monthlyData = {};

    for (var doc in docs) {
      final data = doc.data();
      final ts = data['timestamp'] as Timestamp?;
      if (ts == null) continue;

      final date = ts.toDate();
      final monthKey = DateFormat('yyyy-MM').format(date); // e.g., "2024-06"

      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + 1;
    }

    return monthlyData;
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
        bottom: _isOffline
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Container(
                  color: Colors.red,
                  height: 24,
                  alignment: Alignment.center,
                  child: const Text(
                    'You are offline',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            : null,
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
          final monthlyData = _getMonthlyData(docs);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section with Critical Alerts
                _buildHeaderSection(analytics),
                const SizedBox(height: 24),

                // Statistics Cards
                _buildStatisticsSection(analytics),
                const SizedBox(height: 32),

                // Charts Section
                _buildChartsSection(
                  analytics['typeCounts'] as Map<String, int>,
                  analytics['severityCounts'] as Map<String, int>,
                  weeklyData,
                  monthlyData,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection(Map<String, dynamic> analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analytics['criticalAlerts'] > 0)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red[800]),
                const SizedBox(width: 8),
                Text(
                  '${analytics['criticalAlerts']} CRITICAL ALERTS ACTIVE',
                  style: TextStyle(
                    color: Colors.red[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        Row(
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
          ],
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
        _buildStatCard(
          'Critical Alerts',
          analytics['criticalAlerts'].toString(),
          Icons.warning,
          Colors.red[800]!,
        ),
        _buildStatCard(
          'Avg Response Time',
          '${(analytics['averageResponseTime'] as double).toStringAsFixed(1)} min',
          Icons.timer,
          Colors.blue,
        ),
        _buildStatCard(
          'Responded Incidents',
          analytics['respondedIncidents'].toString(),
          Icons.emergency,
          Colors.green,
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

 Widget _buildChartsSection(
  Map<String, int> typeCounts,
  Map<String, int> severityCounts,
  List<EmergencyCase> weeklyData,
  Map<String, int> monthlyData,
) {
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

      // Monthly Chart
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Incident Trends',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Incidents reported per month',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: SfCartesianChart(
                  primaryXAxis: CategoryAxis(
                    labelRotation: 45,
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                  primaryYAxis: NumericAxis(
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                  series: <CartesianSeries>[
                    ColumnSeries<MapEntry<String, int>, String>(
                      dataSource: monthlyData.entries.toList()
                        ..sort((a, b) => a.key.compareTo(b.key)),
                      xValueMapper: (entry, _) => entry.key,
                      yValueMapper: (entry, _) => entry.value,
                      color: Colors.teal[700],
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

      // Incident Type Distribution Chart
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
      const SizedBox(height: 24),

      // User Count Section (added here)
      _buildUserCountSection(),
    ],
  );
}
  
Widget _buildUserCountSection() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('users').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text('Error loading user data: ${snapshot.error}'),
            ),
          ),
        );
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: const Center(child: CircularProgressIndicator()),
          ),
        );
      }

      final userCount = snapshot.data?.docs.length ?? 0;

      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'App Users',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Number of registered users in the app',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  userCount.toString(),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
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
      case 'Earthquake':
        return Colors.brown;
      case 'Tsunami':
        return Colors.blue[900]!;
      case 'Hurricane':
        return Colors.purple;
      case 'Medical Emergency':
        return Colors.pink;
      case 'Civil Unrest':
        return Colors.red[900]!;
      case 'Infrastructure Failure':
        return Colors.grey;
      case 'Environmental Hazard':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getColorForSeverity(String severity) {
    switch (severity) {
      case 'Critical':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Medium':
        return Colors.yellow;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}