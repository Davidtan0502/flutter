import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EmergenciesScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const EmergenciesScreen({super.key, required this.onMenuPressed});

  @override
  State<EmergenciesScreen> createState() => _EmergenciesScreenState();
}

class _EmergenciesScreenState extends State<EmergenciesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'resolved':
      return Colors.green;
    case 'in progress':
      return Colors.orange;
    case 'pending':
      return Colors.amber;
    default:
      return Colors.grey;
  }
}

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: widget.onMenuPressed,
        ),
        title: const Text('EMERGENCY INCIDENT REPORT'),
        titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
        backgroundColor: Color (0xFF2C5282),
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 20),
              Expanded(
                child: _buildEmergencyList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search Incidents...',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, color: Colors.blue[800]),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.blue[800]),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildEmergencyList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('incidents')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[700]),
                const SizedBox(height: 16),
                const Text('Failed to load data',
                    style: TextStyle(color: Colors.red)),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
        }

        final filteredDocs = _filterEmergencies(snapshot.data!.docs);

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.blue[800]),
                const SizedBox(height: 16),
                Text(
                  'No incidents found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.blue[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your search',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: filteredDocs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _EmergencyCard(
              data: data,
              onTap: () => _showEmergencyDetails(doc),
            );
          },
        );
      },
    );
  }

  List<QueryDocumentSnapshot> _filterEmergencies(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final location = (data['address'] ?? '').toString().toLowerCase();
      final type = (data['incidentType'] ?? '').toString().toLowerCase();

      return _searchQuery.isEmpty ||
          location.contains(_searchQuery) ||
          type.contains(_searchQuery);
    }).toList();
  }

void _showEmergencyDetails(QueryDocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final timestamp = data['timestamp'] as Timestamp?;
  String currentStatus = (data['status'] ?? 'pending').toString().toLowerCase();
  final statusOptions = ['pending', 'in progress', 'resolved'];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 6,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Incident Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  icon: Icons.warning_amber_rounded,
                  title: data['incidentType']?.toString() ?? 'Unknown type',
                  iconColor: _getIncidentColor(data['incidentType']),
                ),
                const SizedBox(height: 20),
                _buildDetailSection(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  content: data['address'] ?? 'Unknown location',
                ),
                _buildDetailSection(
                  icon: Icons.access_time,
                  title: 'Reported',
                  content: timestamp != null
                      ? DateFormat('MMMM d, y - h:mm a').format(timestamp.toDate())
                      : 'Unknown time',
                ),
                _buildDetailSection(
                  icon: Icons.phone,
                  title: 'Contact',
                  content: data['contactNumber'] ?? 'Not provided',
                ),
                _buildDetailSection(
                  icon: Icons.person,
                  title: 'Reporter',
                  content: data['name'] ?? 'Anonymous',
                ),
                if (data['description'] != null) ...[
                  const SizedBox(height: 16),
                  _buildDetailSection(
                    icon: Icons.description,
                    title: 'Description',
                    content: data['description']!.toString(),
                    isDescription: true,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.flag, size: 20, color: Colors.blue[800]),
                    const SizedBox(width: 8),
                    Text(
                      'Status',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 128, vertical: 6),
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(currentStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(currentStatus),
                      width: 1.5,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentStatus,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      dropdownColor: Colors.white,
                      style: TextStyle(
                        color: _getStatusColor(currentStatus),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      onChanged: (value) async {
                        if (value != null && value != currentStatus) {
                          await FirebaseFirestore.instance
                              .collection('incidents')
                              .doc(doc.id)
                              .update({'status': value});
                          setModalState(() {
                            currentStatus = value;
                          });
                          setState(() {}); // refresh outer screen
                        }
                      },
                      items: statusOptions.map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    label: const Text('CLOSE'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}



  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required String title,
    required String content,
    bool isDescription = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.blue[800]),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              content,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: isDescription ? 14 : 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getIncidentColor(String? incidentType) {
    switch (incidentType?.toLowerCase()) {
      case 'fire':
        return Colors.red;
      case 'accident':
        return Colors.orange;
      case 'flood':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }
}

class _EmergencyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _EmergencyCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = data['timestamp'] as Timestamp?;
    final time = timestamp != null 
        ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
        : 'Unknown time';
    
    final location = data['address']?.toString() ?? 'Unknown location';
    final incidentType = data['incidentType']?.toString() ?? 'Unknown type';
    final reporter = data['name']?.toString() ?? 'Anonymous';
    final iconColor = _getIncidentColor(data['incidentType']);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    incidentType,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 6),
                Text(
                  reporter,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getIncidentColor(String? incidentType) {
    switch (incidentType?.toLowerCase()) {
      case 'fire':
        return Colors.red;
      case 'accident':
        return Colors.orange;
      case 'flood':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

}
