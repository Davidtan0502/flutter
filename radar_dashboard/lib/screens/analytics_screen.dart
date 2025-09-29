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

// Data Models
class EmergencyCase {
  final String day;
  final int count;

  EmergencyCase(this.day, this.count);
}

class MonthlyCase {
  final String month;
  final int count;

  MonthlyCase(this.month, this.count);
}

class IncidentTypeCase {
  final String type;
  final int count;
  final Color color;

  IncidentTypeCase(this.type, this.count, this.color);
}

class AnalyticsData {
  final int totalIncidents;
  final int activeAlerts;
  final int resolvedToday;
  final int underReview;
  final int criticalAlerts;
  final double averageResponseTime;
  final int respondedIncidents;
  final Map<String, int> typeCounts;
  final Map<String, int> severityCounts;
  final List<Map<String, dynamic>> recentCriticalIncidents;

  AnalyticsData({
    required this.totalIncidents,
    required this.activeAlerts,
    required this.resolvedToday,
    required this.underReview,
    required this.criticalAlerts,
    required this.averageResponseTime,
    required this.respondedIncidents,
    required this.typeCounts,
    required this.severityCounts,
    required this.recentCriticalIncidents,
  });
}

// Service Classes
class AnalyticsService {
  static AnalyticsData processIncidents(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int totalIncidents = docs.length;
    int resolvedToday = 0;
    int activeAlerts = 0;
    int underReview = 0;
    int criticalAlerts = 0;
    
    // Simplified incident types: Fire, Flood, Accidents, Others
    final Map<String, int> typeCounts = {
      'Fire': 0,
      'Flood': 0,
      'Accidents': 0,
      'Others': 0,
    };
    
    final Map<String, int> severityCounts = {
      'Critical': 0,
      'High': 0,
      'Medium': 0,
      'Low': 0,
      'Unknown': 0,
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    double totalResponseTime = 0.0;
    int respondedIncidents = 0;
    final List<Map<String, dynamic>> recentCriticalIncidents = [];

    for (var doc in docs) {
      final data = doc.data();
      final status = (data['status'] ?? 'pending').toString().toLowerCase();
      final typeRaw = (data['incidentType'] ?? '').toString().toLowerCase();
      final severity = (data['severity'] ?? 'unknown').toString().toLowerCase();
      final reportedTs = data['timestamp'] as Timestamp?;
      final resolvedTs = data['resolvedAt'] as Timestamp?;

      // Simplified incident type classification
      _classifyIncidentType(typeRaw, typeCounts);
      
      // Classify severity
      _classifySeverity(severity, severityCounts);

      // Count critical alerts (critical severity + not resolved)
      if (severity.contains('critical') && status != 'resolved') {
        criticalAlerts++;
      }

      // Calculate response time
      final responseTime = _calculateResponseTime(
        reportedTs: reportedTs,
        resolvedTs: resolvedTs,
        status: status,
        currentTime: now,
      );
      
      if (responseTime != null) {
        totalResponseTime += responseTime;
        respondedIncidents++;
      }

      // Track recent critical incidents
      _trackCriticalIncidents(
        data: data,
        docId: doc.id,
        severity: severity,
        status: status,
        reportedTs: reportedTs,
        currentTime: now,
        recentCriticalIncidents: recentCriticalIncidents,
      );

      // Update status counts
      _updateStatusCounts(
        status: status,
        resolvedTs: resolvedTs,
        today: today,
        resolvedToday: () => resolvedToday++,
        underReview: () => underReview++,
        activeAlerts: () => activeAlerts++,
      );
    }

    final averageResponseTime = respondedIncidents > 0 ? totalResponseTime / respondedIncidents : 0.0;

    return AnalyticsData(
      totalIncidents: totalIncidents,
      activeAlerts: activeAlerts,
      resolvedToday: resolvedToday,
      underReview: underReview,
      criticalAlerts: criticalAlerts,
      averageResponseTime: averageResponseTime,
      respondedIncidents: respondedIncidents,
      typeCounts: typeCounts,
      severityCounts: severityCounts,
      recentCriticalIncidents: recentCriticalIncidents,
    );
  }

  static void _classifyIncidentType(String typeRaw, Map<String, int> typeCounts) {
    if (typeRaw.contains('fire')) {
      typeCounts['Fire'] = typeCounts['Fire']! + 1;
    } else if (typeRaw.contains('flood')) {
      typeCounts['Flood'] = typeCounts['Flood']! + 1;
    } else if (typeRaw.contains('accident') || typeRaw.contains('crash')) {
      typeCounts['Accidents'] = typeCounts['Accidents']! + 1;
    } else {
      typeCounts['Others'] = typeCounts['Others']! + 1;
    }
  }

  static void _classifySeverity(String severity, Map<String, int> severityCounts) {
    if (severity.contains('critical')) {
      severityCounts['Critical'] = severityCounts['Critical']! + 1;
    } else if (severity.contains('high')) {
      severityCounts['High'] = severityCounts['High']! + 1;
    } else if (severity.contains('medium')) {
      severityCounts['Medium'] = severityCounts['Medium']! + 1;
    } else if (severity.contains('low')) {
      severityCounts['Low'] = severityCounts['Low']! + 1;
    } else {
      severityCounts['Unknown'] = severityCounts['Unknown']! + 1;
    }
  }

  static double? _calculateResponseTime({
    required Timestamp? reportedTs,
    required Timestamp? resolvedTs,
    required String status,
    required DateTime currentTime,
  }) {
    if (reportedTs == null) return null;

    if (status == 'resolved' && resolvedTs != null) {
      final responseTimeMinutes = resolvedTs.toDate().difference(reportedTs.toDate()).inMinutes;
      return responseTimeMinutes.toDouble();
    } else if (status != 'resolved') {
      final timeSinceReported = currentTime.difference(reportedTs.toDate()).inMinutes;
      return timeSinceReported.toDouble();
    }
    
    return null;
  }

  static void _trackCriticalIncidents({
    required Map<String, dynamic> data,
    required String docId,
    required String severity,
    required String status,
    required Timestamp? reportedTs,
    required DateTime currentTime,
    required List<Map<String, dynamic>> recentCriticalIncidents,
  }) {
    if (severity.contains('critical') && reportedTs != null) {
      final incidentTime = reportedTs.toDate();
      final twentyFourHoursAgo = currentTime.subtract(const Duration(hours: 24));

      if (incidentTime.isAfter(twentyFourHoursAgo) && status != 'resolved') {
        recentCriticalIncidents.add({
          'id': docId,
          'type': data['incidentType'] ?? 'Unknown',
          'location': data['address'] ?? 'Unknown location',
          'time': incidentTime,
          'severity': severity,
          'status': status,
        });
      }
    }
  }

  static void _updateStatusCounts({
    required String status,
    required Timestamp? resolvedTs,
    required DateTime today,
    required VoidCallback resolvedToday,
    required VoidCallback underReview,
    required VoidCallback activeAlerts,
  }) {
    if (status == 'resolved') {
      if (resolvedTs != null) {
        final resolvedDate = DateTime(
          resolvedTs.toDate().year,
          resolvedTs.toDate().month,
          resolvedTs.toDate().day,
        );
        if (resolvedDate == today) resolvedToday();
      }
    } else if (status == 'under review') {
      underReview();
    } else if (status == 'pending' || status == 'in progress') {
      activeAlerts();
    }
  }

  static List<EmergencyCase> getWeeklyData(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int selectedWeekOffset,
  ) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1 + (7 * selectedWeekOffset.abs())));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    // Initialize with all days of the week
    final Map<String, int> weeklyData = {};
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dayName = _weekdayName(date.weekday);
      weeklyData[dayName] = 0;
    }

    for (var doc in docs) {
      final data = doc.data();
      final ts = data['timestamp'] as Timestamp?;
      if (ts == null) continue;

      final date = ts.toDate();
      if (date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
          date.isBefore(endOfWeek.add(const Duration(days: 1)))) {
        final weekday = _weekdayName(date.weekday);
        weeklyData[weekday] = (weeklyData[weekday] ?? 0) + 1;
      }
    }

    // Convert to list in correct order
    final List<EmergencyCase> result = [];
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dayName = _weekdayName(date.weekday);
      result.add(EmergencyCase(dayName, weeklyData[dayName]!));
    }

    return result;
  }

  static List<MonthlyCase> getMonthlyData(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int selectedMonthOffset,
  ) {
    final Map<String, int> monthlyData = {};
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final targetMonth = DateTime(currentMonth.year, currentMonth.month + selectedMonthOffset);

    for (var doc in docs) {
      final data = doc.data();
      final ts = data['timestamp'] as Timestamp?;
      if (ts == null) continue;

      final date = ts.toDate();
      final incidentMonth = DateTime(date.year, date.month);

      if (incidentMonth.year == targetMonth.year && incidentMonth.month == targetMonth.month) {
        final monthKey = DateFormat('MMM yyyy').format(date);
        monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + 1;
      }
    }

    // Ensure we always return at least one entry for the target month
    final monthKey = DateFormat('MMM yyyy').format(targetMonth);
    if (monthlyData.isEmpty) {
      return [MonthlyCase(monthKey, 0)];
    }

    return [MonthlyCase(monthKey, monthlyData[monthKey]!)];
  }

  static List<IncidentTypeCase> getIncidentTypeData(Map<String, int> typeCounts) {
    return [
      IncidentTypeCase('Fire', typeCounts['Fire']!, Colors.red),
      IncidentTypeCase('Flood', typeCounts['Flood']!, Colors.blue),
      IncidentTypeCase('Accidents', typeCounts['Accidents']!, Colors.orange),
      IncidentTypeCase('Others', typeCounts['Others']!, Colors.grey),
    ];
  }

  static String _weekdayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }
}

class UserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<String> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return 'user';
    
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return (doc.data()?['role'] as String?) ?? 'user';
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return 'user';
    }
  }

  static Stream<QuerySnapshot> getUserCountStream() {
    return _firestore.collection('users').snapshots();
  }
}

class DateRangeService {
  static String getDateRangeLabel(DateTimeRange? dateRange) {
    if (dateRange == null) return 'Last 90 Days';
    final formatter = DateFormat('MMM d, yyyy');
    return '${formatter.format(dateRange.start)} - ${formatter.format(dateRange.end)}';
  }

  static Future<DateTimeRange?> pickDateRange(BuildContext context, DateTimeRange? currentRange) async {
    final now = DateTime.now();
    final initial = currentRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: now, // Prevent selecting dates in the future
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

    return picked;
  }
}

class QueryBuilder {
  static Query<Map<String, dynamic>> buildQuery(DateTimeRange? dateRange) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('incidents');

    if (dateRange != null) {
      final start = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
      final end = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59);

      // Ensure end date doesn't exceed current time
      final actualEnd = end.isAfter(DateTime.now()) ? DateTime.now() : end;

      q = q
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(actualEnd))
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
}

// Main Screen State
class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedWeekOffset = 0;
  int _selectedMonthOffset = 0;
  DateTimeRange? _dateRange;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastFilteredDocs = [];
  bool _isLoading = true;
  Timer? _debounce;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      if (mounted) {
        setState(() {
          _isOffline = (result.isEmpty || result.contains(ConnectivityResult.none));
        });
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await DateRangeService.pickDateRange(context, _dateRange);
    
    if (picked != null) {
      // Debounce to avoid rapid query changes
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _dateRange = picked;
          });
        }
      });
    }
  }

  void _clearDateRange() {
    setState(() => _dateRange = null);
  }

  void _handleWeekOffsetChange(int? value) {
    if (value != null) {
      setState(() => _selectedWeekOffset = value);
    }
  }

  void _handleMonthOffsetChange(int? value) {
    if (value != null) {
      setState(() => _selectedMonthOffset = value);
    }
  }

  String _getWeekLabel() {
    if (_selectedWeekOffset == 0) return "This Week";
    if (_selectedWeekOffset == -1) return "Last Week";
    return "${_selectedWeekOffset.abs()} Weeks Ago";
  }

  String _getMonthLabel() {
    final now = DateTime.now();
    final targetMonth = DateTime(now.year, now.month + _selectedMonthOffset);
    return DateFormat('MMMM yyyy').format(targetMonth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: QueryBuilder.buildQuery(_dateRange).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
            return _buildLoadingState();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;
          _lastFilteredDocs.clear();
          _lastFilteredDocs.addAll(docs);
          _isLoading = false;

          final analytics = AnalyticsService.processIncidents(docs);
          final weeklyData = AnalyticsService.getWeeklyData(docs, _selectedWeekOffset);
          final monthlyData = AnalyticsService.getMonthlyData(docs, _selectedMonthOffset);
          final incidentTypeData = AnalyticsService.getIncidentTypeData(analytics.typeCounts);

          return _buildContent(analytics, weeklyData, monthlyData, incidentTypeData);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
    );
  }

  Widget _buildErrorState(String error) {
    _isLoading = false;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading data\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState() {
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

  Widget _buildContent(AnalyticsData analytics, List<EmergencyCase> weeklyData, List<MonthlyCase> monthlyData, List<IncidentTypeCase> incidentTypeData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(analytics),
          const SizedBox(height: 24),
          _buildStatisticsSection(analytics),
          const SizedBox(height: 32),
          _buildChartsSection(weeklyData, monthlyData, incidentTypeData),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(AnalyticsData analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analytics.criticalAlerts > 0)
          _buildCriticalAlertsBanner(analytics.criticalAlerts),
        
        Row(
          children: [
            const Expanded(
              child: SectionHeader(
                icon: Icons.analytics,
                title: 'ANALYTICS OVERVIEW',
                subtitle: 'Real-time incident statistics and trends',
              ),
            ),
            _buildDateRangePicker(),
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

  Widget _buildCriticalAlertsBanner(int criticalAlerts) {
    return Container(
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
            '$criticalAlerts CRITICAL ALERTS ACTIVE',
            style: TextStyle(
              color: Colors.red[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return OutlinedButton.icon(
      onPressed: _pickDateRange,
      icon: const Icon(Icons.calendar_today, size: 18),
      label: Text(DateRangeService.getDateRangeLabel(_dateRange)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(color: Colors.blue[800]!),
      ),
    );
  }

  Widget _buildStatisticsSection(AnalyticsData analytics) {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCompactStatCard(
                  'Total Incidents',
                  analytics.totalIncidents.toString(),
                  Icons.warning_amber,
                  Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildCompactStatCard(
                  'Active Alerts',
                  analytics.activeAlerts.toString(),
                  Icons.error,
                  Colors.red,
                ),
                const SizedBox(width: 16),
                _buildCompactStatCard(
                  'Resolved Today',
                  analytics.resolvedToday.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildCompactStatCard(
                  'Under Review',
                  analytics.underReview.toString(),
                  Icons.visibility,
                  Colors.purple,
                ),
                const SizedBox(width: 16),
                _buildCompactStatCard(
                  'Critical Alerts',
                  analytics.criticalAlerts.toString(),
                  Icons.warning,
                  Colors.red[800]!,
                ),
                const SizedBox(width: 16),
                _buildCompactStatCard(
                  'Avg Response Time',
                  _formatResponseTime(analytics.averageResponseTime),
                  Icons.timer,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildCompactStatCard(
                  'Responded Incidents',
                  analytics.respondedIncidents.toString(),
                  Icons.emergency,
                  Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
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

  String _formatResponseTime(double minutes) {
    if (minutes < 1) {
      return '<1 min';
    } else if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)} min';
    } else if (minutes < 1440) {
      final hours = minutes / 60;
      return '${hours.toStringAsFixed(1)} h';
    } else {
      final days = minutes / 1440;
      return '${days.toStringAsFixed(1)} d';
    }
  }

  Widget _buildChartsSection(
    List<EmergencyCase> weeklyData,
    List<MonthlyCase> monthlyData,
    List<IncidentTypeCase> incidentTypeData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWeeklyChart(weeklyData),
        const SizedBox(height: 24),
        _buildMonthlyChart(monthlyData),
        const SizedBox(height: 24),
        _buildIncidentTypeChart(incidentTypeData),
        const SizedBox(height: 24),
        _buildUserCountSection(),
      ],
    );
  }

  Widget _buildWeeklyChart(List<EmergencyCase> weeklyData) {
    return Card(
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
                  onChanged: _handleWeekOffsetChange,
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
                  minimum: 0,
                ),
                series: <CartesianSeries>[
                  LineSeries<EmergencyCase, String>(
                    dataSource: weeklyData,
                    xValueMapper: (data, _) => data.day,
                    yValueMapper: (data, _) => data.count,
                    color: Colors.blue[800],
                    markerSettings: const MarkerSettings(isVisible: true),
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                tooltipBehavior: TooltipBehavior(enable: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChart(List<MonthlyCase> monthlyData) {
    return Card(
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
                  'Monthly Incident Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                DropdownButton<int>(
                  value: _selectedMonthOffset,
                  items: [
                    DropdownMenuItem(value: 0, child: Text(DateFormat('MMMM yyyy').format(DateTime.now()))),
                    DropdownMenuItem(value: -1, child: Text(DateFormat('MMMM yyyy').format(DateTime(DateTime.now().year, DateTime.now().month - 1)))),
                    DropdownMenuItem(value: -2, child: Text(DateFormat('MMMM yyyy').format(DateTime(DateTime.now().year, DateTime.now().month - 2)))),
                    DropdownMenuItem(value: -3, child: Text(DateFormat('MMMM yyyy').format(DateTime(DateTime.now().year, DateTime.now().month - 3)))),
                  ],
                  onChanged: _handleMonthOffsetChange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getMonthLabel(),
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
                  minimum: 0,
                ),
                series: <CartesianSeries>[
                  ColumnSeries<MonthlyCase, String>(
                    dataSource: monthlyData,
                    xValueMapper: (data, _) => data.month,
                    yValueMapper: (data, _) => data.count,
                    color: Colors.teal[700],
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                tooltipBehavior: TooltipBehavior(enable: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentTypeChart(List<IncidentTypeCase> incidentTypeData) {
    final totalCount = incidentTypeData.fold(0, (previousValue, item) => previousValue + item.count);
    
    return Card(
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
            Text(
              'Total: $totalCount incidents',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: SfCircularChart(
                legend: Legend(
                  isVisible: true,
                  overflowMode: LegendItemOverflowMode.wrap,
                  textStyle: const TextStyle(fontSize: 12),
                  position: LegendPosition.bottom,
                ),
                series: <CircularSeries>[
                  DoughnutSeries<IncidentTypeCase, String>(
                    dataSource: incidentTypeData,
                    xValueMapper: (data, _) => data.type,
                    yValueMapper: (data, _) => data.count,
                    pointColorMapper: (data, _) => data.color,
                    dataLabelMapper: (data, _) => '${data.count}',
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      labelPosition: ChartDataLabelPosition.outside,
                    ),
                    innerRadius: '60%',
                  ),
                ],
                tooltipBehavior: TooltipBehavior(enable: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCountSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: UserService.getUserCountStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorCard('Error loading user data: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
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

  Widget _buildErrorCard(String error) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(error),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}