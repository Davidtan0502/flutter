import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Add this import
import 'package:radar_dashboard/components/section_header.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _ActiveEmergenciesState();
}

class _ActiveEmergenciesState extends State<IncidentReportScreen> {
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
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidents')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Error loading incidents');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final incidents = snapshot.data!.docs;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      icon: Icons.warning_amber_outlined,
                      title: 'INCIDENT REPORTS',
                      count: incidents.length,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 250,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Table(
                          columnWidths: const {
                            0: FixedColumnWidth(40),
                            1: FlexColumnWidth(),
                            2: FixedColumnWidth(80),
                            3: FlexColumnWidth(),
                            4: FixedColumnWidth(100),
                          },
                          border: TableBorder(
                            horizontalInside: BorderSide(
                              color: Colors.black.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          children: [
                            _buildTableHeader(),
                            ...incidents.map((doc) => _buildTableRow(doc)),
                          ],
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

  TableRow _buildTableHeader() {
    return const TableRow(
      decoration: BoxDecoration(color: Colors.white),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text('ID', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black,)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text('LOCATION', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black,)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text('TIME', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black,)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text('TYPE', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black,)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black,)),
        ),
      ],
    );
  }

  TableRow _buildTableRow(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp;
    final time = DateFormat('h:mm a').format(timestamp.toDate()); // Now properly formatted
    
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(
            doc.id.substring(0, 4),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black,),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(
            data['address'] ?? '',
            style: const TextStyle(fontSize: 12, color: Colors.black,),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(
            time,
            style: const TextStyle(fontSize: 12, color: Colors.black,),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(
            data['incidentType'] ?? '',
            style: const TextStyle(fontSize: 12, color: Colors.black,),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: _buildStatusCell(data['status'] ?? ''),
        ),
      ],
    );
  }

  Widget _buildStatusCell(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          status.length > 12 ? '${status.substring(0, 10)}...' : status,
          style: TextStyle(
            color: _getStatusColor(status),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.orange;
      case 'Investigation':
        return Colors.blue;
      case 'Resolved':
        return Colors.green;
      case 'Pending':
        return const Color.fromARGB(255, 95, 95, 95);
      default:
        return const Color.fromARGB(255, 0, 0, 0);
    }
  }
}