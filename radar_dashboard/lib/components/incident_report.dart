import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:radar_dashboard/components/section_header.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  String _searchQuery = '';
  String _selectedType = 'All';
  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  final List<String> _incidentTypes = [
    'All',
    'Fire',
    'Accident',
    'Flood',
    'Other Accidents'
  ];

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              icon: Icons.warning_amber_outlined,
              title: 'EMERGENCIES',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by location or type',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      underline: const SizedBox(),
                      value: _selectedType,
                      icon: const Icon(Icons.arrow_drop_down),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedType = newValue!;
                        });
                      },
                      items: _incidentTypes
                          .map<DropdownMenuItem<String>>((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidents')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading incidents', style: TextStyle(color: Colors.red)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final allDocs = snapshot.data!.docs;
                final filtered = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final location = (data['address'] ?? '').toString().toLowerCase();
                  final type = (data['incidentType'] ?? '').toString().toLowerCase();

                  final matchesSearch = _searchQuery.isEmpty ||
                      location.contains(_searchQuery) ||
                      type.contains(_searchQuery);

                  final matchesType = _selectedType == 'All' ||
                      type == _selectedType.toLowerCase();

                  return matchesSearch && matchesType;
                }).toList();

                if (filtered.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Text('No matching incidents found')),
                  );
                }

                return SizedBox(
                  height: 250,
                  child: Scrollbar(
                    controller: _verticalScrollController,
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      scrollDirection: Axis.vertical,
                      child: Scrollbar(
                        controller: _horizontalScrollController,
                        notificationPredicate: (notification) => notification.depth == 1,
                        child: SingleChildScrollView(
                          controller: _horizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 58,
                            horizontalMargin: 16,
                            headingRowHeight: 40,
                            dataRowHeight: 56,
                            columns: const [
                              DataColumn(
                                label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text('LOCATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              DataColumn(
                                label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              DataColumn(
                                label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              DataColumn(
                                label: Text('TIME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              DataColumn(
                                label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                            rows: filtered.map((doc) => _buildDataRow(doc)).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
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
    final date = timestamp != null ? DateFormat('MMM d, yyyy').format(timestamp.toDate()) : 'N/A';
    final time = timestamp != null ? DateFormat('h:mm a').format(timestamp.toDate()) : 'N/A';
    final location = data['address']?.toString() ?? 'Unknown';
    final rawType = data['incidentType']?.toString() ?? '';
    final normalizedType = rawType.toLowerCase();
    final status = data['status']?.toString() ?? 'Pending'; // Default to 'Pending' if status is not set

    final knownTypes = ['fire', 'accident', 'flood'];
    final incidentType = knownTypes.contains(normalizedType)
        ? _capitalize(normalizedType)
        : 'Others';

    // Determine status color
    Color statusColor = Colors.grey; // Default color
    if (status.toLowerCase() == 'resolved') {
      statusColor = Colors.green;
    } else if (status.toLowerCase() == 'in progress') {
      statusColor = Colors.yellow;
    } else if (status.toLowerCase() == 'pending') {
      statusColor = Colors.blueGrey;
    }

    return DataRow(
      cells: [
        DataCell(Text(doc.id.substring(0, 4), style: const TextStyle(fontSize: 12, fontFamily: 'RobotoMono'))),
        DataCell(SizedBox(width: 170, child: Text(location, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 2))),
        DataCell(SizedBox(
          width: 50,
          child: Text(
            incidentType,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        )),
        DataCell(Text(date, style: const TextStyle(fontSize: 12))),
        DataCell(Text(time, style: const TextStyle(fontSize: 12))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor),
            ),
            child: Text(
              _capitalize(status),
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}