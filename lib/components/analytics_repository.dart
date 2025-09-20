import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AnalyticsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<QueryDocumentSnapshot>> getActiveAlerts() async {
    final snapshot = await _db.collection('alerts').where('status', isEqualTo: 'active').get();
    return snapshot.docs;
  }

  Future<int> getRespondersActive() async {
    final snapshot = await _db.collection('alerts').get();
    return snapshot.docs.map((doc) => doc['responderId']).toSet().length;
  }

  Future<int> getResolvedToday() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final snapshot = await _db
        .collection('alerts')
        .where('status', isEqualTo: 'resolved')
        .where('resolvedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .get();
    return snapshot.size;
  }

  Future<Map<String, int>> getWeeklyCases() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    final snapshot = await _db
        .collection('alerts')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .get();

    final Map<String, int> dayCounts = {
      'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0
    };

    for (var doc in snapshot.docs) {
      final date = (doc['timestamp'] as Timestamp).toDate();
      final day = DateFormat('E').format(date);
      if (dayCounts.containsKey(day)) {
        dayCounts[day] = dayCounts[day]! + 1;
      }
    }

    return dayCounts;
  }

  Future<Map<String, int>> getIncidentTypeCounts() async {
    final snapshot = await _db.collection('incidents').get();
    final counts = {
      'Fire': 0,
      'Accident': 0,
      'Flood': 0,
      'Other': 0,
    };

    for (var doc in snapshot.docs) {
      final type = doc['incidentType'] ?? '';
      if (counts.containsKey(type)) {
        counts[type] = counts[type]! + 1;
      } else {
        counts['Other'] = counts['Other']! + 1;
      }
    }

    return counts;
  }

  Future<double> getAverageResponseTime() async {
    final snapshot = await _db.collection('alerts').get();

    final incidents = snapshot.docs.where((doc) => doc['respondedAt'] != null);
    final durations = incidents.map((doc) {
      final created = (doc['timestamp'] as Timestamp).toDate();
      final responded = (doc['respondedAt'] as Timestamp).toDate();
      return responded.difference(created).inMinutes.toDouble();
    }).toList();

    if (durations.isEmpty) return 0.0;
    return durations.reduce((a, b) => a + b) / durations.length;
  }

  Future<int> getTotalIncidents() async {
    final snapshot = await _db.collection('incidents').get();
    return snapshot.size;
  }
}
