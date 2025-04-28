import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:radar_dashboard/components/section_header.dart';

class MonthlyIncidentReport extends StatelessWidget {
  const MonthlyIncidentReport({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              icon: Icons.bar_chart_outlined,
              title: 'MONTHLY INCIDENT REPORT',
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidents')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final incidents = snapshot.data!.docs;
                final monthlyCounts = _calculateMonthlyCounts(incidents);

                return SizedBox(
                  height: 250,
                  child: BarChart(
                    _monthlyIncidentData(monthlyCounts),
                    swapAnimationDuration: const Duration(milliseconds: 500),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<int> _calculateMonthlyCounts(List<QueryDocumentSnapshot> incidents) {
    final monthlyCounts = List<int>.filled(6, 0); // For Jan-Jun

    for (final doc in incidents) {
      final timestamp = doc['timestamp'] as Timestamp;
      final date = timestamp.toDate();
      final month = date.month - 1; // Convert to 0-11 index

      // Only count if month is between Jan (0) and Jun (5)
      if (month >= 0 && month <= 5) {
        monthlyCounts[month]++;
      }
    }

    return monthlyCounts;
  }

  BarChartData _monthlyIncidentData(List<int> monthlyCounts) {
    return BarChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: _calculateInterval(monthlyCounts),
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          );
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN'];
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  months[value.toInt()],
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: _calculateInterval(monthlyCounts),
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      barGroups: [
        BarChartGroupData(
          x: 0,
          barRods: [BarChartRodData(toY: monthlyCounts[0].toDouble(), color: Colors.blue[400]!, width: 16)],
        ),
        BarChartGroupData(
          x: 1,
          barRods: [BarChartRodData(toY: monthlyCounts[1].toDouble(), color: Colors.teal[400]!, width: 16)],
        ),
        BarChartGroupData(
          x: 2,
          barRods: [BarChartRodData(toY: monthlyCounts[2].toDouble(), color: Colors.orange[400]!, width: 16)],
        ),
        BarChartGroupData(
          x: 3,
          barRods: [BarChartRodData(toY: monthlyCounts[3].toDouble(), color: Colors.deepPurple[400]!, width: 16)],
        ),
        BarChartGroupData(
          x: 4,
          barRods: [BarChartRodData(toY: monthlyCounts[4].toDouble(), color: Colors.pink[400]!, width: 16)],
        ),
        BarChartGroupData(
          x: 5,
          barRods: [BarChartRodData(toY: monthlyCounts[5].toDouble(), color: Colors.green[400]!, width: 16)],
        ),
      ],
    );
  }

  double _calculateInterval(List<int> counts) {
    final maxCount = counts.reduce((a, b) => a > b ? a : b);
    if (maxCount <= 5) return 1;
    if (maxCount <= 10) return 2;
    if (maxCount <= 20) return 5;
    if (maxCount <= 50) return 10;
    if (maxCount <= 100) return 20;
    return 50;
  }
}