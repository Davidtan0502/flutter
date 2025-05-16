import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:radar_dashboard/components/involved_barangay.dart';
import 'package:radar_dashboard/components/incident_report.dart';
import 'package:radar_dashboard/components/map_monitoring.dart';
import 'package:radar_dashboard/components/weather_monitoring.dart';
import 'package:radar_dashboard/components/monthly_incident_report.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onMenuPressed;

  const DashboardScreen({
    super.key,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildDashboardBody(context),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: onMenuPressed,
      ),
      title: const Text('EMERGENCY RESPONSE DASHBOARD'),
      centerTitle: true,
      backgroundColor: const Color(0xFF2C5282),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildDashboardBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopSection(context),
              const SizedBox(height: 24),
              _buildMetricsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildEmergencyStats(context),
                        const SizedBox(height: 16),
                        const IncidentReportScreen(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(flex: 2, child: MapMonitoring()),
                ],
              )
            : Column(
                children: [
                  _buildEmergencyStats(context),
                  const SizedBox(height: 16),
                  const IncidentReportScreen(),
                  const SizedBox(height: 16),
                  const MapMonitoring(),
                ],
              );
      },
    );
  }

  Widget _buildEmergencyStats(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: IncidentStatsWidget(),
      ),
    );
  }

  Widget _buildMetricsSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isWide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(child: MonthlyIncidentReport()),
                        const SizedBox(width: 16),
                        const Expanded(child: InvolvedBarangays()),
                        const SizedBox(width: 16),
                        const Expanded(child: WeatherMonitoring()),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      const MonthlyIncidentReport(),
                      const SizedBox(height: 16),
                      const InvolvedBarangays(),
                      const SizedBox(height: 16),
                      const WeatherMonitoring(),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class IncidentStatsWidget extends StatelessWidget {
  final List<StatItem> stats = const [
    StatItem(Icons.fireplace_outlined, 'Fire', 'Fire', Colors.deepOrange),
    StatItem(Icons.car_crash_outlined, 'Accidents', 'Accident', Colors.orange),
    StatItem(Icons.flood_outlined, 'Flood', 'Flood', Colors.blue),
    StatItem(Icons.warning_outlined, 'Other', 'Other Accidents', Colors.red),
    StatItem(Icons.list_alt, 'Total', 'Total', Colors.purple, isTotal: true), 
  ];

  const IncidentStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('incidents').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingIndicator();
        if (snapshot.hasError) return const ErrorDisplay();

        final incidents = snapshot.data!.docs;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: stats.map((stat) {
            int count;
            if (stat.isTotal) {
              count = incidents.length;
            } else if (stat.label == 'Other') {
              count = incidents.where((doc) {
                final type = doc['incidentType'];
                return type != 'Fire' && type != 'Flood' && type != 'Accident';
              }).length;
            } else {
              count = incidents.where((doc) => doc['incidentType'] == stat.type).length;
            }
            return StatItemWidget(stat: stat, count: count);
          }).toList(),
        );
      },
    );
  }
}

class StatItem {
  final IconData icon;
  final String label;
  final String type;
  final Color color;
  final bool isTotal;

  const StatItem(this.icon, this.label, this.type, this.color, 
      {this.isTotal = false});
}

class StatItemWidget extends StatelessWidget {
  final StatItem stat;
  final int count;

  const StatItemWidget({
    super.key,
    required this.stat,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      constraints: const BoxConstraints(minWidth: 100),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: stat.color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: stat.color.withOpacity(0.3)),
            ),
            child: Icon(stat.icon, size: 24, color: stat.color),
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Error loading incident data',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}