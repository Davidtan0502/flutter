import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

class MapMonitoring extends StatefulWidget {
  const MapMonitoring({super.key});

  @override
  State<MapMonitoring> createState() => _MapMonitoringState();
}

class _MapMonitoringState extends State<MapMonitoring> {
  // Constants
  static const LatLng _initialPosition = LatLng(14.5995, 120.9842);
  static const double _initialZoom = 13.0;
  static const double _mapHeight = 524.0;

  // State variables
  final Set<Marker> _markers = {};
  final Map<String, LatLng> _geocodingCache = {};
  GoogleMapController? _mapController;
  Stream<QuerySnapshot>? _incidentsStream;

  Map<String, dynamic>? _selectedIncident;
  LatLng? _selectedPosition;
  bool _isLoading = false; // NEW

  @override
  void initState() {
    super.initState();
    _setupRealTimeIncidents();
  }

  void _setupRealTimeIncidents() {
    setState(() => _isLoading = true); // start loading
    _incidentsStream = FirebaseFirestore.instance
        .collection('incidents')
        .where('status', isNotEqualTo: 'resolved')
        .snapshots();

    _incidentsStream?.listen((snapshot) async {
      await _processIncidents(snapshot.docs);
      if (mounted) setState(() => _isLoading = false); // stop loading
    });
  }

  Future<void> _processIncidents(List<QueryDocumentSnapshot> docs) async {
    final newMarkers = <Marker>{};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final position = await _getIncidentPosition(data);

      if (position != null) {
        final marker = await _createIncidentMarker(doc.id, data, position);
        newMarkers.add(marker);
      }
    }

    if (mounted) {
      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
      });
    }
  }

  Future<LatLng?> _getIncidentPosition(Map<String, dynamic> data) async {
    final coordinates = _parseCoordinates(data);
    if (coordinates != null) return coordinates;

    if (data['address'] != null) {
      return await _geocodeAddress(data['address'] as String);
    }

    return null;
  }

  LatLng? _parseCoordinates(Map<String, dynamic> data) {
    try {
      final lat = data['latitude'] as double? ??
          (data['latitude'] != null
              ? double.tryParse(data['latitude'].toString())
              : null);
      final lng = data['longitude'] as double? ??
          (data['longitude'] != null
              ? double.tryParse(data['longitude'].toString())
              : null);

      return (lat != null && lng != null) ? LatLng(lat, lng) : null;
    } catch (e) {
      debugPrint('Error parsing coordinates: $e');
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
        final position =
            LatLng(locations.first.latitude, locations.first.longitude);
        _geocodingCache[address] = position;
        return position;
      }
    } catch (e) {
      debugPrint('Geocoding failed for address: $address. Error: $e');
    }
    return null;
  }

Future<Marker> _createIncidentMarker(
    String id, Map<String, dynamic> data, LatLng position) async {
  final type = data['incidentType']?.toString() ?? 'other';
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

      //Animate the camera to center the tapped marker
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: 15, // adjust zoom level as you like
          ),
        ),
      );
    },
    icon: await _getDisasterIcon(type),
  );
}


  Future<BitmapDescriptor> _getDisasterIcon(String type) async {
    final color = _getDisasterColor(type);
    return BitmapDescriptor.defaultMarkerWithHue(
      _colorToHue(color),
    );
  }

  Color _getDisasterColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return Colors.red;
      case 'flood':
        return Colors.blue;
      case 'accident':
        return Colors.orange;
      case 'typhoon':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  double _colorToHue(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
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

  // === INCIDENT DETAILS BESIDE MARKER ===
  Widget _buildIncidentDetails() {
    if (_selectedIncident == null || _selectedPosition == null) {
      return const SizedBox();
    }

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
          left: dx + 30, // float to right of marker
          top: dy - 60,  // align near marker head
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          color: _getDisasterColor(_selectedIncident!['type']),
                          size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _selectedIncident!['type'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusChip(_selectedIncident!['status']),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedIncident!['address'],
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                const Icon(Icons.map_rounded, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'MAP MONITORING',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: "Refresh Map",
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  onPressed: () {
                    setState(() {
                      _selectedIncident = null;
                      _selectedPosition = null;
                      _markers.clear();
                      _isLoading = true;
                    });
                    _setupRealTimeIncidents();
                    _mapController?.animateCamera(
                      CameraUpdate.newCameraPosition(
                        const CameraPosition(
                          target: _initialPosition,
                          zoom: _initialZoom,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: _mapHeight,
            child: Stack(
              children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _initialPosition,
                      zoom: _initialZoom,
                    ),
                    mapType: MapType.normal,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    markers: _markers,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: (LatLng pos) {
                      setState(() {
                        _selectedIncident = null;
                        _selectedPosition = null;
                      });
                    },
                    
                  ),
                  

                if (_selectedIncident != null && _selectedPosition != null)
                  _buildIncidentDetails(),
                // === LOADING INDICATOR ===
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue,
                    ),
                  ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _LegendItem(color: Colors.red, label: 'Fire'),
                        _LegendItem(color: Colors.blue, label: 'Flood'),
                        _LegendItem(color: Colors.orange, label: 'Accidents'),
                        _LegendItem(color: Colors.grey, label: 'Other'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_pin, color: color, size: 20),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
