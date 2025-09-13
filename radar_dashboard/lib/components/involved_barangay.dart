import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:radar_dashboard/components/section_header.dart';

class InvolvedBarangays extends StatelessWidget {
  const InvolvedBarangays({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: _BarangayChartContent(),
      ),
    );
  }
}

class _BarangayChartContent extends StatelessWidget {
  const _BarangayChartContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.location_on_outlined,
          title: 'INVOLVED LOCATION', subtitle: '',
        ),
        const SizedBox(height: 20),
        _BarangayDataLoader(),
      ],
    );
  }
}

class _BarangayDataLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('incidents').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _ErrorDisplay(message: 'Error loading data');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _ErrorDisplay(message: 'No incident data available');
        }

        final dataProcessor = BarangayDataProcessor(snapshot.data!.docs);
        final chartData = dataProcessor.processData();

        return _BarangayChartDisplay(data: chartData);
      },
    );
  }
}

class BarangayDataProcessor {
  final List<QueryDocumentSnapshot> documents;

  BarangayDataProcessor(this.documents);

  BarangayChartData processData() {
    final barangayCounts = <String, int>{};
    
    for (final doc in documents) {
      final address = doc['address'] as String? ?? 'Unknown';
      final barangay = _determineBarangay(address);
      barangayCounts[barangay] = (barangayCounts[barangay] ?? 0) + 1;
    }

    final sortedBarangays = barangayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topBarangays = sortedBarangays.take(5).toList();
    final othersCount = sortedBarangays.length > 5
        ? sortedBarangays.sublist(5).fold(0, (sum, entry) => sum + entry.value)
        : 0;

    return BarangayChartData(
      topBarangays: topBarangays,
      othersCount: othersCount,
    );
  }

String _determineBarangay(String address) {
  try {
    // Common patterns that indicate a barangay reference
    final patterns = [
      'Barangay', 'Brgy.', 'Brgy', 'Bgy.', 'Bgy', 
      'Village', 'Subdivision', 'Subd.', 'Subd'
    ];
    
    // Convert to lowercase for case-insensitive matching
    final lowerAddress = address.toLowerCase();
    
    // Try to find barangay patterns
    for (final pattern in patterns) {
      final patternLower = pattern.toLowerCase();
      if (lowerAddress.contains(patternLower)) {
        final startIndex = lowerAddress.indexOf(patternLower) + patternLower.length;
        var barangayPart = address.substring(startIndex).trim();
        
        // Clean up the extracted part
        barangayPart = barangayPart.split(RegExp(r'[,\-]')).first.trim();
        
        // Remove any numbers or special characters that might follow
        barangayPart = barangayPart.replaceAll(RegExp(r'[0-9#]'), '').trim();
        
        if (barangayPart.isNotEmpty) {
          return barangayPart;
        }
      }
    }
    
    // Fallback: If no pattern found, try to extract the first meaningful word
    final parts = address.split(RegExp(r'[,\-]'));
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty && !trimmed.contains(RegExp(r'[0-9]'))) {
        return trimmed;
      }
    }
    
    return 'Unknown';
  } catch (e) {
    return 'Unknown';
  }
}
}

class BarangayChartData {
  final List<MapEntry<String, int>> topBarangays;
  final int othersCount;

  BarangayChartData({
    required this.topBarangays,
    required this.othersCount,
  });
}

class _BarangayChartDisplay extends StatelessWidget {
  final BarangayChartData data;

  const _BarangayChartDisplay({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            _buildChartData(),
            swapAnimationDuration: const Duration(milliseconds: 500),
          ),
        ),
        const SizedBox(height: 16),
        _buildChartLegend(),
      ],
    );
  }

  PieChartData _buildChartData() {
    final colors = _chartColors;
    
    return PieChartData(
      sectionsSpace: 0,
      centerSpaceRadius: 60,
      sections: [
        for (int i = 0; i < data.topBarangays.length; i++)
          PieChartSectionData(
            value: data.topBarangays[i].value.toDouble(),
            color: colors[i % colors.length],
            title: '${data.topBarangays[i].value}',
            radius: 25,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        if (data.othersCount > 0)
          PieChartSectionData(
            value: data.othersCount.toDouble(),
            color: Colors.grey[400]!,
            title: '${data.othersCount}',
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
    final colors = _chartColors;
    
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (int i = 0; i < data.topBarangays.length; i++)
          _LegendItem(
            color: colors[i % colors.length],
            text: '${data.topBarangays[i].key} (${data.topBarangays[i].value})',
          ),
        if (data.othersCount > 0)
          _LegendItem(
            color: Colors.grey[400]!,
            text: 'Others (${data.othersCount})',
          ),
      ],
    );
  }

  List<Color> get _chartColors => [
    Colors.blue[400]!,
    Colors.green[400]!,
    Colors.orange[400]!,
    Colors.purple[400]!,
    Colors.red[400]!,
    Colors.teal[400]!,
  ];
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
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

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorDisplay extends StatelessWidget {
  final String message;

  const _ErrorDisplay({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}