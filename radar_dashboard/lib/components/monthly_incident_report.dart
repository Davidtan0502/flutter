import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:radar_dashboard/components/section_header.dart';

class MonthlyIncidentReport extends StatefulWidget {
  final List<Map<String, dynamic>> incidents;

  const MonthlyIncidentReport({super.key, required this.incidents});

  @override
  State<MonthlyIncidentReport> createState() => _MonthlyIncidentReportState();
}

class _MonthlyIncidentReportState extends State<MonthlyIncidentReport> {
  int _currentSet = 0; // 0: Jan-Jun, 1: Jul-Dec
  final int _monthsPerSet = 6;

  @override
  Widget build(BuildContext context) {
    final monthlyCounts = _calculateMonthlyCounts(widget.incidents);
    final currentSetCounts = _getCurrentSetCounts(monthlyCounts);

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
              subtitle: '',
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                SizedBox(
                  height: 230,
                  child: BarChart(
                    _monthlyIncidentData(currentSetCounts),
                    swapAnimationDuration: const Duration(milliseconds: 500),
                  ),
                ),
                const SizedBox(height: 10),
                _buildNavigationControls(monthlyCounts.length),
                const SizedBox(height: 8),
                _buildStatsSummary(monthlyCounts),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<int> _calculateMonthlyCounts(List<Map<String, dynamic>> incidents) {
    final monthlyCounts = List<int>.filled(12, 0); // For all 12 months
    final currentYear = DateTime.now().year;

    for (final incident in incidents) {
      final timestamp = incident['timestamp'];
      if (timestamp != null) {
        try {
          final date = DateTime.parse(timestamp);
          // Only count incidents from current year
          if (date.year == currentYear) {
            final month = date.month - 1; // Convert to 0-11 index
            if (month >= 0 && month <= 11) {
              monthlyCounts[month]++;
            }
          }
        } catch (e) {
          debugPrint('Error parsing timestamp: $timestamp');
        }
      }
    }

    debugPrint('Monthly counts: $monthlyCounts');
    return monthlyCounts;
  }

  List<int> _getCurrentSetCounts(List<int> monthlyCounts) {
    final startIndex = _currentSet * _monthsPerSet;
    final endIndex = startIndex + _monthsPerSet;
    
    // Ensure we don't go beyond the available months
    if (endIndex > monthlyCounts.length) {
      return monthlyCounts.sublist(startIndex);
    }
    
    return monthlyCounts.sublist(startIndex, endIndex);
  }

  BarChartData _monthlyIncidentData(List<int> monthlyCounts) {
    final monthNames = _getMonthNames();
    final maxCount = monthlyCounts.isNotEmpty 
        ? monthlyCounts.reduce((a, b) => a > b ? a : b) 
        : 0;
    
    return BarChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: _calculateInterval(maxCount),
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
              final index = value.toInt();
              if (index >= 0 && index < monthlyCounts.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    monthNames[index],
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: _calculateInterval(maxCount),
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
      barGroups: monthlyCounts.asMap().entries.map((entry) {
        final index = entry.key;
        final count = entry.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(), 
              color: _getBarColor(index), 
              width: 16,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        );
      }).toList(),
    );
  }

  List<String> _getMonthNames() {
    if (_currentSet == 0) {
      return ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN'];
    } else {
      return ['JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    }
  }

  Color _getBarColor(int index) {
    final colors = [
      Colors.blue[400]!,
      Colors.teal[400]!,
      Colors.orange[400]!,
      Colors.deepPurple[400]!,
      Colors.pink[400]!,
      Colors.green[400]!,
      Colors.red[400]!,
      Colors.purple[400]!,
      Colors.amber[400]!,
      Colors.cyan[400]!,
      Colors.indigo[400]!,
      Colors.lime[400]!,
    ];
    
    final actualIndex = _currentSet * _monthsPerSet + index;
    return colors[actualIndex % colors.length];
  }

  double _calculateInterval(int maxCount) {
    if (maxCount <= 5) return 1;
    if (maxCount <= 10) return 2;
    if (maxCount <= 20) return 5;
    if (maxCount <= 50) return 10;
    if (maxCount <= 100) return 20;
    return 50;
  }

  Widget _buildNavigationControls(int totalMonths) {
    final totalSets = (totalMonths / _monthsPerSet).ceil();
    final hasPrevious = _currentSet > 0;
    final hasNext = _currentSet < totalSets - 1;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 16),
          onPressed: hasPrevious ? () {
            setState(() {
              _currentSet--;
            });
          } : null,
          color: hasPrevious ? Colors.blue : Colors.grey,
        ),
        Text(
          _getSetDisplayText(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.blueGrey[700],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: hasNext ? () {
            setState(() {
              _currentSet++;
            });
          } : null,
          color: hasNext ? Colors.blue : Colors.grey,
        ),
      ],
    );
  }

  String _getSetDisplayText() {
    final startMonth = _currentSet * _monthsPerSet + 1;
    final endMonth = (_currentSet + 1) * _monthsPerSet;
    
    if (_currentSet == 0) {
      return 'Jan - Jun';
    } else {
      return 'Jul - Dec';
    }
  }

  Widget _buildStatsSummary(List<int> monthlyCounts) {
    final totalIncidents = monthlyCounts.fold(0, (sum, count) => sum + count);
    final maxMonthIndex = monthlyCounts.indexWhere((count) => count == monthlyCounts.reduce((a, b) => a > b ? a : b));
    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 
                       'July', 'August', 'September', 'October', 'November', 'December'];
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', '$totalIncidents', Colors.blue),
          _buildStatItem('Peak Month', monthNames[maxMonthIndex], Colors.green),
          _buildStatItem('Peak Count', '${monthlyCounts[maxMonthIndex]}', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}