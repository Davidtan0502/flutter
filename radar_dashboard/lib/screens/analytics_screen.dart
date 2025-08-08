
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class AnalyticsScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const AnalyticsScreen({super.key, required this.onMenuPressed});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<EmergencyAlert> activeAlerts = [];
  List<EmergencyCase> weeklyCases = [];
  List<ResponseTime> responseTimes = [];
  int respondersActive = 0;
  int resolvedToday = 0;
  int totalIncidents = 0;
  Map<String, int> typeCounts = {
    'Fire': 0,
    'Accident': 0,
    'Flood': 0,
    'Other': 0,
  };

  @override
  void initState() {
    super.initState();
    fetchAnalyticsData();
  }

  Future<void> fetchAnalyticsData() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    final alertsRef = FirebaseFirestore.instance.collection('alerts');
    final incidentsRef = FirebaseFirestore.instance.collection('incidents');

    final alertsSnapshot = await alertsRef.get();
    final alertsData = alertsSnapshot.docs;

    final activeAlertsList = alertsData.where((doc) => doc['status'] == 'active').map((doc) {
      final data = doc.data();
      final severity = data['severity'] ?? 'Low';
      return EmergencyAlert(
        data['title'] ?? 'Unknown',
        data['location'] ?? 'Unknown',
        severity,
        severity == 'High' ? Icons.local_fire_department : severity == 'Medium' ? Icons.medical_services : Icons.power,
        severity == 'High' ? Colors.red : severity == 'Medium' ? Colors.orange : Colors.amber,
      );
    }).toList();

    final responders = alertsData.map((doc) => doc['responderId']).toSet().length;

    final resolvedTodaySnapshot = await alertsRef
        .where('status', isEqualTo: 'resolved')
        .where('resolvedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .get();

    final weeklySnapshot = await alertsRef.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart)).get();
    final Map<String, int> dayCounts = {
      'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0
    };
    for (var doc in weeklySnapshot.docs) {
      final date = (doc['timestamp'] as Timestamp).toDate();
      final day = DateFormat('E').format(date);
      if (dayCounts.containsKey(day)) dayCounts[day] = dayCounts[day]! + 1;
    }

    final allIncidents = await incidentsRef.get();
    final incidentTypeCounts = {
      'Fire': 0,
      'Accident': 0,
      'Flood': 0,
      'Other': 0,
    };
    for (var doc in allIncidents.docs) {
      final type = doc['incidentType'] ?? '';
      if (type == 'Fire' || type == 'Accident' || type == 'Flood') {
        incidentTypeCounts[type] = incidentTypeCounts[type]! + 1;
      } else {
        incidentTypeCounts['Other'] = incidentTypeCounts['Other']! + 1;
      }
    }

    final incidentsWithTimestamps = alertsData.where((doc) => doc['respondedAt'] != null).toList();
    final responseDurations = incidentsWithTimestamps.map((doc) {
      final created = (doc['timestamp'] as Timestamp).toDate();
      final responded = (doc['respondedAt'] as Timestamp).toDate();
      return responded.difference(created).inMinutes.toDouble();
    }).toList();
    final averageResponse = responseDurations.isNotEmpty
        ? responseDurations.reduce((a, b) => a + b) / responseDurations.length
        : 0.0;

    setState(() {
      activeAlerts = activeAlertsList;
      weeklyCases = dayCounts.entries.map((e) => EmergencyCase(e.key, e.value)).toList();
      responseTimes = [ResponseTime("Avg Response", averageResponse)];
      respondersActive = responders;
      resolvedToday = resolvedTodaySnapshot.size;
      totalIncidents = allIncidents.size;
      typeCounts = incidentTypeCounts;
    });
  }

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopStats(),
                  const SizedBox(height: 24),
                  _buildChartsSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopStats() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard("Active Emergencies", activeAlerts.length.toString(), Icons.warning, Colors.orange),
        _buildStatCard("Responders Active", respondersActive.toString(), Icons.people, Colors.blue),
        _buildStatCard("Avg. Response Time", "${responseTimes.isNotEmpty ? responseTimes.first.minutes.toStringAsFixed(1) : "0.0"} min", Icons.timer, Colors.green),
        _buildStatCard("Resolved Today", resolvedToday.toString(), Icons.check_circle, Colors.purple),
        _buildStatCard("Total Incidents", totalIncidents.toString(), Icons.list_alt, Colors.teal),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
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
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Emergency Cases This Week", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: SfCartesianChart(
            primaryXAxis: CategoryAxis(),
            series: <CartesianSeries>[
              LineSeries<EmergencyCase, String>(
                dataSource: weeklyCases,
                xValueMapper: (EmergencyCase data, _) => data.day,
                yValueMapper: (EmergencyCase data, _) => data.count,
                color: Colors.red,
                markerSettings: const MarkerSettings(isVisible: true),
                dataLabelSettings: const DataLabelSettings(isVisible: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text("Incident Types Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              )
            ],
          ),
        ),
      ],
    );
  }
}

class EmergencyAlert {
  final String title;
  final String location;
  final String severity;
  final IconData icon;
  final Color color;

  EmergencyAlert(this.title, this.location, this.severity, this.icon, this.color);
}

class EmergencyCase {
  final String day;
  final int count;

  EmergencyCase(this.day, this.count);
}

class ResponseTime {
  final String type;
  final double minutes;

  ResponseTime(this.type, this.minutes);
}
