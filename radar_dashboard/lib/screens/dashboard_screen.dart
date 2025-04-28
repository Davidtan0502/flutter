import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:radar_dashboard/components/drawer.dart.dart';
import 'package:radar_dashboard/screens/emergency_severity.dart.dart';
import 'package:radar_dashboard/screens/incident_report.dart';
import 'package:radar_dashboard/screens/map_monitoring.dart.dart';
import 'package:radar_dashboard/screens/monthly_incident_report.dart.dart';
import 'package:radar_dashboard/screens/weather_monitoring.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: const RadarDrawer(),
      body: _buildDashboardBody(),
      backgroundColor: Colors.grey[50],
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Emergency Response Dashboard',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
      centerTitle: true,
      backgroundColor: const Color(0xFF2C5282),
      elevation: 1,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, size: 22),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 22),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDashboardBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmergencyHeader(),
              const SizedBox(height: 30),
              _buildDashboardGrid(),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildEmergencyHeader() {
  return Card(
    color: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('incidents').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading incident data'));
          }

          final incidents = snapshot.data!.docs;
          
          // Count incidents by type
          final fireCount = incidents.where((doc) => doc['incidentType'] == 'Fire').length;
          final accidentCount = incidents.where((doc) => doc['incidentType'] == 'Accident').length;
          final floodCount = incidents.where((doc) => doc['incidentType'] == 'Flood').length;
          final otherAccidentsCount = incidents.where((doc) => doc['incidentType'] == 'Other Accidents').length;
          final totalCount = incidents.length;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.fireplace_outlined, 'Fire', '$fireCount', Colors.deepOrange),
              _buildStatItem(Icons.car_crash_outlined, 'Accidents', '$accidentCount', Colors.orange),
              _buildStatItem(Icons.flood_outlined, 'Flood', '$floodCount', Colors.blue),
              _buildStatItem(Icons.warning_outlined, 'Other', '$otherAccidentsCount', Colors.red),
              _buildStatItem(Icons.list_alt, 'Total', '$totalCount', Colors.purple),
            ],
          );
        },
      ),
    ),
  );
}

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3))
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardGrid() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildTopRow(),
              const SizedBox(height: 20),
              _buildBottomRow(),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 2,
          child: MapMonitoring(),
        ),
      ],
    );
  }

  Widget _buildTopRow() {
    return Row(
      children: [
        Expanded(child: IncidentReportScreen()),
        const SizedBox(width: 20),
        Expanded(child: MonthlyIncidentReport()),
      ],
    );
  }

  Widget _buildBottomRow() {
    return Row(
      children: [
        Expanded(child: EmergencySeverity()),
        const SizedBox(width: 20),
        Expanded(child: WeatherMonitoring()),
      ],
    );
  }
}