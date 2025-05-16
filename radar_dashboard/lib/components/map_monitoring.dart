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
  static const Duration _geocodeCacheDuration = Duration(hours: 1);
  static const Duration _markerCacheDuration = Duration(minutes: 30);

  // State variables
  final Set<Marker> _markers = {};
  final Map<String, LatLng> _geocodingCache = {};
  GoogleMapController? _mapController;
  Stream<QuerySnapshot>? _incidentsStream;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _loadCachedMarkers();
    _setupRealTimeIncidents();
  }

  Future<void> _loadCachedMarkers() async {
    // In a real app, you would load from cache manager
    // For demo purposes, we'll start with empty markers  
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
    // Try coordinates first
    final coordinates = _parseCoordinates(data);
    if (coordinates != null) return coordinates;

    // Fall back to geocoding if address exists
    if (data['address'] != null) {
      return await _geocodeAddress(data['address'] as String);
    }

    return null;
  }

  LatLng? _parseCoordinates(Map<String, dynamic> data) {
    try {
      final lat = data['latitude'] as double? ?? 
                 (data['latitude'] != null ? double.tryParse(data['latitude'].toString()) : null);
      final lng = data['longitude'] as double? ?? 
                 (data['longitude'] != null ? double.tryParse(data['longitude'].toString()) : null);

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
        final position = LatLng(locations.first.latitude, locations.first.longitude);
        _geocodingCache[address] = position;
        return position;
      }
    } catch (e) {
      debugPrint('Geocoding failed for address: $address. Error: $e');
    }
    return null;
  }

  Future<Marker> _createIncidentMarker(String id, Map<String, dynamic> data, LatLng position) async {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      infoWindow: InfoWindow(
        title: data['incidentType']?.toString() ?? 'Incident',
        snippet: data['address']?.toString() ?? 'No address provided',
      ),
      icon: await _getSeverityIcon(data['severity']?.toString() ?? 'unknown'),
    );
  }

  Future<BitmapDescriptor> _getSeverityIcon(String severity) async {
    // Simplified version - in production you might want to use pre-made assets
    final color = _getSeverityColor(severity);
    return BitmapDescriptor.defaultMarkerWithHue(
      _colorToHue(color),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  double _colorToHue(Color color) {
    // Convert color to HSV and return hue value
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
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
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                Icon(Icons.map_rounded, size: 24),
                SizedBox(width: 12),
                Text(
                  'MAP MONITORING',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: _mapHeight,
            child: GoogleMap(
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
              onTap: (position) {
                // Handle map taps if needed
              },
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