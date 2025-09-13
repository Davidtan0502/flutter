import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'dart:async';


class MapMonitoring extends StatefulWidget {
  const MapMonitoring({super.key});

  @override
  State<MapMonitoring> createState() => _MapMonitoringState();
}

class _MapMonitoringState extends State<MapMonitoring> {
  // Constants
  static const LatLng _initialPosition = LatLng(14.5995, 120.9842);
  static const double _initialZoom = 13.0;
  static const double _mapHeight = 671.5;

  // State
  final Set<Marker> _markers = {};
  final Map<String, LatLng> _geocodingCache = {};
  final Map<String, BitmapDescriptor> _iconCache = {};
  GoogleMapController? _mapController;
  StreamSubscription<QuerySnapshot>? _incidentsSub;

  Map<String, dynamic>? _selectedIncident;
  LatLng? _selectedPosition;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Debounce
  DateTime _lastGeocodeTime = DateTime.now();
  static const Duration _geocodeDebounce = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _preloadIcons();
    _listenToIncidents();
  }

  Future<void> _preloadIcons() async {
    for (final type in ['fire', 'flood', 'accident', 'typhoon', 'other']) {
      _iconCache[type] = await _getDisasterIcon(type);
    }
  }

  void _listenToIncidents() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    _incidentsSub = FirebaseFirestore.instance
        .collection('incidents')
        .where('status', isNotEqualTo: 'resolved')
        .snapshots()
        .listen(
      (snapshot) => _processIncidents(snapshot.docs),
      onError: (error) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Error loading incidents: $error';
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _processIncidents(List<QueryDocumentSnapshot> docs) async {
    if (!mounted) return;
    final newMarkers = <Marker>{};
    final processed = <String>{};

    for (final doc in docs) {
      if (processed.contains(doc.id)) continue;
      processed.add(doc.id);

      final data = doc.data() as Map<String, dynamic>;
      final pos = await _getIncidentPosition(data);
      if (pos != null) {
        final marker = await _createMarker(doc.id, data, pos);
        newMarkers.add(marker);
      }
    }

    if (mounted) {
      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
        _isLoading = false;
      });
    }
  }

  Future<LatLng?> _getIncidentPosition(Map<String, dynamic> data) async {
    try {
      final coords = _parseCoordinates(data);
      if (coords != null) return coords;

      final address = data['address'] as String?;
      if (address != null && address.isNotEmpty) {
        final now = DateTime.now();
        if (now.difference(_lastGeocodeTime) < _geocodeDebounce) {
          await Future.delayed(_geocodeDebounce);
        }
        _lastGeocodeTime = DateTime.now();
        return await _geocodeAddress(address);
      }
    } catch (e) {
      debugPrint('Error getting position: $e');
    }
    return null;
  }

  LatLng? _parseCoordinates(Map<String, dynamic> data) {
    try {
      final lat = double.tryParse(data['latitude']?.toString() ?? '');
      final lng = double.tryParse(data['longitude']?.toString() ?? '');
      return (lat != null && lng != null && lat != 0.0 && lng != 0.0)
          ? LatLng(lat, lng)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    if (_geocodingCache.containsKey(address)) return _geocodingCache[address];
    try {
      final locs = await locationFromAddress(address);
      if (locs.isNotEmpty) {
        final pos = LatLng(locs.first.latitude, locs.first.longitude);
        _geocodingCache[address] = pos;
        return pos;
      }
    } catch (e) {
      debugPrint('Geocoding failed: $address | $e');
    }
    return null;
  }

  Future<Marker> _createMarker(
      String id, Map<String, dynamic> data, LatLng pos) async {
    final type = (data['incidentType'] ?? 'other').toString().toLowerCase();
    final markerIcon = _iconCache[type] ?? await _getDisasterIcon(type);

    return Marker(
      markerId: MarkerId(id),
      position: pos,
      icon: markerIcon,
      onTap: () {
        setState(() {
          _selectedIncident = {
            'id': id,
            'type': type,
            'status': data['status'] ?? 'pending',
            'address': data['address'] ?? 'Unknown',
            'description': data['description'] ?? '',
            'timestamp': data['timestamp'],
          };
          _selectedPosition = pos;
        });
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: pos, zoom: 15),
          ),
        );
      },
    );
  }

  Future<BitmapDescriptor> _getDisasterIcon(String type) async {
    return BitmapDescriptor.defaultMarkerWithHue(
      HSLColor.fromColor(_getDisasterColor(type)).hue,
    );
  }

  Color _getDisasterColor(String type) {
    switch (type) {
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

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'resolved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'in progress':
        color = Colors.orange;
        icon = Icons.build_circle;
        break;
      case 'pending':
        color = Colors.amber;
        icon = Icons.access_time;
        break;
      case 'under review':
        color = Colors.purple;
        icon = Icons.visibility;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(status.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('MMM d, h:mm a').format(ts.toDate());
    }
    return 'Unknown';
  }

  Widget _buildIncidentDetails() {
    if (_selectedIncident == null) return const SizedBox();
    final incident = _selectedIncident!;

    return Positioned(
      right: 16,
      top: 16,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: _getDisasterColor(incident['type']), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      incident['type'].toString().toUpperCase(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _selectedIncident = null),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(incident['address'], style: const TextStyle(fontSize: 14)),
              if (incident['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(incident['description'],
                    style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusChip(incident['status']),
                  const Spacer(),
                  if (incident['timestamp'] != null)
                    Text(_formatTimestamp(incident['timestamp']),
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _LegendItem(color: Colors.red, label: 'Fire'),
            _LegendItem(color: Colors.blue, label: 'Flood'),
            _LegendItem(color: Colors.orange, label: 'Accident'),
            _LegendItem(color: Colors.green, label: 'Typhoon'),
            _LegendItem(color: Colors.grey, label: 'Other'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & refresh
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                const Icon(Icons.map_rounded, size: 24, color: Colors.blue),
                const SizedBox(width: 12),
                const Text('MAP MONITORING',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: "Refresh Map",
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  onPressed: () {
                    setState(() {
                      _selectedIncident = null;
                      _markers.clear();
                      _isLoading = true;
                      _hasError = false;
                    });
                    _listenToIncidents();
                    _mapController?.animateCamera(
                      CameraUpdate.newCameraPosition(
                          const CameraPosition(target: _initialPosition, zoom: _initialZoom)),
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
                  initialCameraPosition: const CameraPosition(
                      target: _initialPosition, zoom: _initialZoom),
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  markers: _markers,
                  onMapCreated: (controller) => _mapController = controller,
                  onTap: (_) => setState(() => _selectedIncident = null),
                ),
                if (_selectedIncident != null) _buildIncidentDetails(),
                if (_hasError)
                  Center(
                    child: Text(_errorMessage,
                        style: const TextStyle(color: Colors.red)),
                  ),
                if (_isLoading && !_hasError)
                  const Center(child: CircularProgressIndicator(color: Colors.blue)),
                _buildLegend(),
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
    _incidentsSub?.cancel();
    super.dispose();
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.location_on, color: color, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
