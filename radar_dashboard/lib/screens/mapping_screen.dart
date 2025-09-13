import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

class MapMonitoringpingScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const MapMonitoringpingScreen({super.key, required this.onMenuPressed});

  @override
  State<MapMonitoringpingScreen> createState() => _MapMonitoringScreenState();
}

class _MapMonitoringScreenState extends State<MapMonitoringpingScreen> {
  static const LatLng _initialPosition = LatLng(14.5995, 120.9842); // Manila
  static const double _initialZoom = 13.0;

  final Set<Marker> _markers = {};
  final Map<String, LatLng> _geocodingCache = {};
  final Map<String, BitmapDescriptor> _iconCache = {};
  GoogleMapController? _mapController;
  Stream<QuerySnapshot>? _incidentsStream;

  bool _legendVisible = true;
  Map<String, dynamic>? _selectedIncident;
  LatLng? _selectedPosition;
  bool _isLoading = true;
  bool _isZoomedToMarker = false;

  @override
  void initState() {
    super.initState();
    _setupRealTimeIncidents();
    _preloadIcons();
  }

  void _preloadIcons() async {
    final types = ['fire', 'flood', 'accident', 'other accidents', 'unknown'];
    for (final type in types) {
      _iconCache[type] = await _getIncidentIcon(type);
    }
    setState(() => _isLoading = false);
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
    } catch (_) {
      // Could add retry logic or fallback to a simpler address parsing
    }
    return null;
  }

  Future<Marker> _createIncidentMarker(
      String id, Map<String, dynamic> data, LatLng position) async {
    final type = (data['incidentType'] ?? 'unknown').toString().toLowerCase();
    final icon = _iconCache[type] ?? await _getIncidentIcon(type);

    return Marker(
      markerId: MarkerId(id),
      position: position,
      onTap: () {
        setState(() {
          _selectedIncident = {
            'id': id,
            'type': type,
            'status': (data['status'] ?? 'pending').toString(),
            'address': (data['address'] ?? 'Unknown location').toString(),
            'timestamp': (data['timestamp'] ?? Timestamp.now()).toString(),
          };
          _selectedPosition = position;
          _isZoomedToMarker = true;
        });
        
        // Center map on selected marker with zoom
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(position, 20),
        );
      },
      icon: icon,
      zIndex: _selectedIncident != null && _selectedIncident!['id'] == id ? 2 : 1,
    );
  }

  Future<BitmapDescriptor> _getIncidentIcon(String type) async {
    final color = _getIncidentColor(type);
    
    // Create custom bitmap icon for better visual appearance
    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..color = color;
    
    // Draw a pin shape with a shadow
    canvas.drawCircle(const Offset(24, 24), 20, paint);
    canvas.drawShadow(Path()..addOval(Rect.fromCircle(center: Offset(24, 24), radius: 20)), 
                      Colors.black54, 2, false);
    
    // Convert to bitmap
    final picture = recorder.endRecording();
    final image = await picture.toImage(48, 48);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Color _getIncidentColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return const Color(0xFFE53935); // More vibrant red
      case 'flood':
        return const Color(0xFF1976D2); // Deeper blue
      case 'accident':
        return const Color(0xFFFF9800); // Brighter orange
      case 'other accidents':
        return const Color(0xFF9C27B0); // More vibrant purple
      default:
        return const Color(0xFF757575); // Softer grey
    }
  }

  // === LEGEND ===
  Widget _buildLegend() {
    if (!_legendVisible) return const SizedBox();

    final entries = {
      'Fire': _getIncidentColor('fire'),
      'Flood': _getIncidentColor('flood'),
      'Accident': _getIncidentColor('accident'),
      'Other Incidents': _getIncidentColor('other accidents'),
      'Unknown': _getIncidentColor('unknown'),
    };

    return Positioned(
      top: 80, // Below app bar
      left: 16,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26, 
              blurRadius: 8,
              offset: Offset(0, 2)
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'INCIDENT LEGEND',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...entries.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 2,
                          offset: Offset(0, 1)
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        fontSize: 13, 
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  // === STATUS CHIP ===
  Widget _buildStatusChip(String status) {
    Color color;
    String displayText;
    
    switch (status.toLowerCase()) {
      case 'resolved':
        color = const Color(0xFF4CAF50);
        displayText = 'RESOLVED';
        break;
      case 'in progress':
        color = const Color(0xFFFF9800);
        displayText = 'IN PROGRESS';
        break;
      case 'pending':
        color = const Color(0xFFF44336);
        displayText = 'PENDING';
        break;
      default:
        color = const Color(0xFF9E9E9E);
        displayText = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // === INCIDENT DETAILS PANEL ===
  Widget _buildIncidentDetailsPanel() {
    if (_selectedIncident == null) return const SizedBox();

    final data = _selectedIncident!;
    
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Material(
        child: Container( // Removed const from here
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26, 
                blurRadius: 8,
                offset: Offset(0, 2)
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getIncidentColor(data['type']),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['type'].toString().toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  _buildStatusChip(data['status']),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() => _selectedIncident = null);
                      // Reset to default view when closing details
                      _resetToDefaultView();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['address'],
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.black54),
                  const SizedBox(width: 8),
                  Text(
                    'Reported: ${_formatTimestamp(data['timestamp'])}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Unknown time';
    }
  }

  // Reset to default view
  void _resetToDefaultView() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          const CameraPosition(
            target: _initialPosition,
            zoom: _initialZoom,
          ),
        ),
      );
      setState(() {
        _isZoomedToMarker = false;
      });
    }
  }

  // Refresh map data and reset view
  void _refreshMap() {
    // Clear caches
    _geocodingCache.clear();
    
    // Reset to default view
    _resetToDefaultView();
    
    // Clear selection
    setState(() {
      _selectedIncident = null;
    });
    
    // Reload incidents
    _setupRealTimeIncidents();
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
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      backgroundColor: const Color(0xFF2C5282), 
      elevation: 2,
      actions: [
        IconButton(
          icon: const Icon(Icons.legend_toggle, color: Colors.white),
          onPressed: () {
            setState(() => _legendVisible = !_legendVisible);
          },
          tooltip: 'Toggle Legend',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _refreshMap,
          tooltip: 'Refresh',
        ),
        if (_isZoomedToMarker)
          IconButton(
            icon: const Icon(Icons.zoom_out_map, color: Colors.white),
            onPressed: _resetToDefaultView,
            tooltip: 'Reset Zoom',
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
            onMapCreated: (controller) {
              _mapController = controller;
              setState(() => _isLoading = false);
            },
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: _selectedIncident != null ? 180 : 20,
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C5282)),
              ),
            ),

          // Legend (upper left)
          _buildLegend(),

          // Incident details panel
          _buildIncidentDetailsPanel(),
        ],
      ),
    );
  }
}