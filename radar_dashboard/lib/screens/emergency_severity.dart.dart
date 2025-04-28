import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:radar_dashboard/components/section_header.dart';


class EmergencySeverity extends StatelessWidget {
  final Map<String, double> severityData;

  const EmergencySeverity({
    super.key,
    this.severityData = const {
      'Critical': 0,
      'High': 0,
      'Medium': 0,
      'Low': 0,
    },
  });

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
              icon: Icons.pie_chart_outline,
              title: 'EMERGENCY SEVERITY',
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                _emergencyAnalyticsData(),
                swapAnimationDuration: const Duration(milliseconds: 500),
              ),
            ),
            const SizedBox(height: 16),
            _buildChartLegend(),
          ],
        ),
      ),
    );
  }

  PieChartData _emergencyAnalyticsData() {
    final critical = severityData['Critical'] ?? 0;
    final high = severityData['High'] ?? 0;
    final medium = severityData['Medium'] ?? 0;
    final low = severityData['Low'] ?? 0;

    return PieChartData(
      sectionsSpace: 0,
      centerSpaceRadius: 60,
      sections: [
        PieChartSectionData(
          value: critical,
          color: Colors.red[400],
          title: '$critical%',
          radius: 30,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        PieChartSectionData(
          value: high,
          color: Colors.orange[400]!,
          title: '$high%',
          radius: 25,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        PieChartSectionData(
          value: medium,
          color: Colors.blue[400]!,
          title: '$medium%',
          radius: 25,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        PieChartSectionData(
          value: low,
          color: Colors.green[400]!,
          title: '$low%',
          radius: 20,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildChartLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem(Colors.red[400]!, 'Critical'),
        _buildLegendItem(Colors.orange[400]!, 'High'),
        _buildLegendItem(Colors.blue[400]!, 'Medium'),
        _buildLegendItem(Colors.green[400]!, 'Low'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.blueGrey[700],
          ),
        ),
      ],
    );
  }
}