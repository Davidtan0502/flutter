import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/components/section_header.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _ActiveEmergenciesState();
}

class _ActiveEmergenciesState extends State<IncidentReportScreen> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidents')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading incidents',
                        style: TextStyle(color: Colors.red)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final incidents = snapshot.data!.docs;
                
                if (incidents.isEmpty) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: Text('No incidents found')),
                  );
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      icon: Icons.warning_amber_outlined,
                      title: 'INCIDENT REPORTS',
                      count: incidents.length,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 250,
                      child: Scrollbar(
                        controller: _verticalScrollController,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          scrollDirection: Axis.vertical,
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            notificationPredicate: (notification) =>
                                notification.depth == 1,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 16,
                                horizontalMargin: 16,
                                headingRowHeight: 40,
                                dataRowHeight: 56,
                                columns: const [
                                  DataColumn(
                                    label: Text('ID',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text('LOCATION',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                    tooltip: 'Incident location address',
                                  ),
                                  DataColumn(
                                    label: Text('TYPE',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                    tooltip: 'Type of incident',
                                  ),
                                  DataColumn(
                                    label: Text('TIME',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                    tooltip: 'Time of incident',
                                  ),
                                  DataColumn(
                                    label: Text('STATUS',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                    tooltip: 'Current status',
                                  ),
                                ],
                                rows: incidents.map((doc) => _buildDataRow(doc)).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildDataRow(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp?;
    final time = timestamp != null 
        ? DateFormat('h:mm a').format(timestamp.toDate())
        : 'N/A';
    final status = data['status']?.toString() ?? 'Unknown';
    final location = data['address']?.toString() ?? 'Unknown';
    final incidentType = data['incidentType']?.toString() ?? 'Unknown';

    return DataRow(
      cells: [
        DataCell(
          Text(
            doc.id.length > 4 ? doc.id.substring(0, 4) : doc.id,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'RobotoMono',
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 250,
            child: Text(
              location,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 100,
            child: Text(
              incidentType,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
        DataCell(
          Text(
            time,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        DataCell(
          _buildStatusCell(status),
        ),
      ],
    );
  }

  Widget _buildStatusCell(String status) {
    final color = _getStatusColor(status);
    final text = status.length > 10 ? '${status.substring(0, 8)}...' : status;

    return Container(
      constraints: const BoxConstraints(minWidth: 80, maxWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('active')) return Colors.orange;
    if (lowerStatus.contains('investigat')) return Colors.blue;
    if (lowerStatus.contains('resolved')) return Colors.green;
    if (lowerStatus.contains('pending')) return Colors.grey;
    return Colors.black;
  }
}