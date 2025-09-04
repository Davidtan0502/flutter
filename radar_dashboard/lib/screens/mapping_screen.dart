import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

class MapMonitoringpingScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const MapMonitoringpingScreen({super.key, required this.onMenuPressed});

  @override
  State<MapMonitoringpingScreen> createState() =>
      _MapMonitoringpingScreenState();
}

class _MapMonitoringpingScreenState extends State<MapMonitoringpingScreen> {
  static const LatLng _initialPosition = LatLng(14.5995, 120.9842); // Manila
  static const double _initialZoom = 13.0;

  final Set<Marker> _markers = {};
  final Map<String, LatLng> _geocodingCache = {};
  GoogleMapController? _mapController;
  Stream<QuerySnapshot>? _incidentsStream;
  String? _lastIncidentId;

  bool _legendVisible = false;
  Map<String, dynamic>? _selectedIncident;
  LatLng? _selectedPosition;

  @override
  void initState() {
    super.initState();
    _setupRealTimeIncidents();
  }

  void _setupRealTimeIncidents() {
    _incidentsStream = FirebaseFirestore.instance
        .collection('incidents')
        .where('status', isNotEqualTo: 'resolved')
        .snapshots();

    _incidentsStream?.listen((snapshot) {
      _processIncidents(snapshot.docs);
    });
  }

  Future<void> _processIncidents(List<QueryDocumentSnapshot> docs) async {
    final newMarkers = <Marker>{};
    String? latestId;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final position = await _getIncidentPosition(data);

      if (position != null) {
        final marker = await _createIncidentMarker(doc.id, data, position);
        newMarkers.add(marker);
        latestId = doc.id;
      }
    }

    if (mounted) {
      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
      });

      if (_mapController != null && latestId != null) {
        if (_lastIncidentId == null || latestId != _lastIncidentId) {
          final latestMarker =
              newMarkers.firstWhere((m) => m.markerId.value == latestId);
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(latestMarker.position, 15),
          );
          _lastIncidentId = latestId;
        }
      }
    }
  }

  Future<LatLng?> _getIncidentPosition(Map<String, dynamic> data) async {
    final coordinates = _parseCoordinates(data);
    if (coordinates != null) return coordinates;

    if (data['address'] != null) {
      return await _geocodeAddress(data['address'].toString());
    }
    return null;
  }

  LatLng? _parseCoordinates(Map<String, dynamic> data) {
    try {
      final lat = data['latitude'] is double
          ? data['latitude']
          : double.tryParse(data['latitude']?.toString() ?? '');
      final lng = data['longitude'] is double
          ? data['longitude']
          : double.tryParse(data['longitude']?.toString() ?? '');

      return (lat != null && lng != null) ? LatLng(lat, lng) : null;
    } catch (_) {
      return null;
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    if (_geocodingCache.containsKey(address)) {
      return _geocodingCache[address];
    }
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final pos = LatLng(locations.first.latitude, locations.first.longitude);
        _geocodingCache[address] = pos;
        return pos;
      }
    } catch (_) {}
    return null;
  }

  Future<Marker> _createIncidentMarker(
      String id, Map<String, dynamic> data, LatLng position) async {
    final type = (data['incidentType'] ?? 'Incident').toString();

    return Marker(
      markerId: MarkerId(id),
      position: position,
      onTap: () {
        setState(() {
          _selectedIncident = {
            'id': id,
            'type': type,
            'status': (data['status'] ?? 'pending').toString(),
            'address': (data['address'] ?? 'Unknown').toString(),
          };
          _selectedPosition = position;
        });
      },
      icon: await _getIncidentIcon(type),
    );
  }

  Future<BitmapDescriptor> _getIncidentIcon(String type) async {
    final color = _getIncidentColor(type);
    return BitmapDescriptor.defaultMarkerWithHue(_colorToHue(color));
  }

  Color _getIncidentColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return Colors.red;
      case 'flood':
        return Colors.blue;
      case 'accident':
        return Colors.orange;
      case 'other accidents':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  double _colorToHue(Color c) => HSLColor.fromColor(c).hue;

  // === LEGEND ===
  Widget _buildLegend() {
    final entries = {
      'Fire': Colors.red,
      'Flood': Colors.blue,
      'Accident': Colors.orange,
      'Other Accidents': Colors.purple,
      'Unknown': Colors.grey,
    };

    if (!_legendVisible) return const SizedBox();

    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.entries
              .map((e) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_pin, color: e.value, size: 18),
                      const SizedBox(width: 6),
                      Text(e.key,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }

  // === STATUS CHIP ===
  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'resolved':
        color = Colors.green;
        break;
      case 'in progress':
        color = Colors.orange;
        break;
      case 'pending':
        color = Colors.amber;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // === INCIDENT DETAILS NEAR MARKER ===
  Widget _buildIncidentDetails() {
    if (_selectedIncident == null || _selectedPosition == null) {
      return const SizedBox();
    }
    final data = _selectedIncident!;
    final screenPointFuture =
        _mapController?.getScreenCoordinate(_selectedPosition!);

    return FutureBuilder<ScreenCoordinate>(
      future: screenPointFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final screenPoint = snapshot.data!;
        final dx = screenPoint.x.toDouble();
        final dy = screenPoint.y.toDouble();

        return Positioned(
          left: dx - 120,
          top: dy - 120,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 240,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_pin,
                          color: _getIncidentColor(data['type']), size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data['type'],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildStatusChip(data['status']),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data['address'],
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // === APPBAR ===
  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: widget.onMenuPressed,
      ),
      title: const Text(
        'MAP MONITORING',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      backgroundColor: const Color(0xFF2C5282), 
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: _initialZoom,
            ),
            markers: _markers,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
          ),

          // Legend (collapsible)
          _buildLegend(),

          // Legend toggle button
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                setState(() => _legendVisible = !_legendVisible);
              },
              child: Icon(
                _legendVisible ? Icons.close : Icons.list,
                color: Colors.black87,
              ),
            ),
          ),

          // Incident details beside marker
          _buildIncidentDetails(),
        ],
      ),
    );
  }
}
