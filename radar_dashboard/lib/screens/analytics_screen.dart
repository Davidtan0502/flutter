import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // Sample data - replace with real API calls
  List<EmergencyAlert> activeAlerts = [
    EmergencyAlert("Fire outbreak", "Downtown", "High", Icons.local_fire_department, Colors.red),
    EmergencyAlert("Medical emergency", "Central Hospital", "Medium", Icons.medical_services, Colors.orange),
    EmergencyAlert("Power outage", "North District", "Low", Icons.power, Colors.amber),
  ];
  
  List<EmergencyCase> weeklyCases = [
    EmergencyCase("Mon", 12),
    EmergencyCase("Tue", 18),
    EmergencyCase("Wed", 8),
    EmergencyCase("Thu", 15),
    EmergencyCase("Fri", 22),
    EmergencyCase("Sat", 14),
    EmergencyCase("Sun", 9),
  ];
  
  List<ResponseTime> responseTimes = [
    ResponseTime("Medical", 12.5),
    ResponseTime("Fire", 8.2),
    ResponseTime("Police", 10.7),
    ResponseTime("Rescue", 15.3),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Analytics Dashboard',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Last updated: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Overview Cards
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildStatCard("Active Emergencies", "18", Icons.warning, Colors.orange),
                _buildStatCard("Responders Active", "42", Icons.people, Colors.blue),
                _buildStatCard("Avg. Response Time", "9.2 min", Icons.timer, Colors.green),
                _buildStatCard("Resolved Today", "23", Icons.check_circle, Colors.purple),
              ],
            ),
            
            SizedBox(height: 24),
            
            // Main Content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        // Active Alerts
                        _buildActiveAlertsCard(),
                        SizedBox(height: 16),
                        // Response Times Chart
                        _buildResponseTimesChart(),
                      ],
                    ),
                  ),
                  
                  SizedBox(width: 16),
                  
                  // Right Column
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // Cases Over Time Chart
                        _buildCasesOverTimeChart(),
                        SizedBox(height: 16),
                        // Map and Details
                        _buildMapAndDetails(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 200,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAlertsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Alerts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text('${activeAlerts.length} Active'),
                  backgroundColor: Colors.red[50],
                  labelStyle: TextStyle(color: Colors.red),
                ),
              ],
            ),
            SizedBox(height: 8),
            ...activeAlerts.map((alert) => _buildAlertItem(alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(EmergencyAlert alert) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: alert.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(alert.icon, color: alert.color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  alert.location,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Chip(
            label: Text(alert.severity),
            backgroundColor: alert.severity == "High"
                ? Colors.red[50]
                : alert.severity == "Medium"
                    ? Colors.orange[50]
                    : Colors.amber[50],
            labelStyle: TextStyle(
              color: alert.severity == "High"
                  ? Colors.red
                  : alert.severity == "Medium"
                      ? Colors.orange
                      : Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildResponseTimesChart() {
  return Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Average Response Times',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          SizedBox(
            height: 250,
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(),
              series: <CartesianSeries>[
                BarSeries<ResponseTime, String>(
                  dataSource: responseTimes,
                  xValueMapper: (ResponseTime time, _) => time.type,
                  yValueMapper: (ResponseTime time, _) => time.minutes,
                  color: Colors.blue,
                  dataLabelSettings: DataLabelSettings(isVisible: true),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCasesOverTimeChart() {
  return Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Emergency Cases This Week',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.calendar_today, size: 18),
                onPressed: () {},
              ),
            ],
          ),
          SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(),
              primaryYAxis: NumericAxis(minimum: 0),
              series: <CartesianSeries>[
                LineSeries<EmergencyCase, String>(
                  dataSource: weeklyCases,
                  xValueMapper: (EmergencyCase cases, _) => cases.day,
                  yValueMapper: (EmergencyCase cases, _) => cases.count,
                  color: Colors.red,
                  markerSettings: MarkerSettings(isVisible: true),
                  dataLabelSettings: DataLabelSettings(isVisible: true),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildMapAndDetails() {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency Map',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              // Placeholder for map - replace with actual map widget
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 48, color: Colors.grey),
                        Text('Map visualization would appear here',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              // Quick actions
              Row(
                children: [
                  _buildQuickActionButton(Icons.add_alert, "New Alert"),
                  SizedBox(width: 8),
                  _buildQuickActionButton(Icons.assignment, "Generate Report"),
                  SizedBox(width: 8),
                  _buildQuickActionButton(Icons.settings, "Settings"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label) {
    return Expanded(
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label),
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// Data models
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