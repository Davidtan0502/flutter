import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class MapMonitoring extends StatefulWidget {
  final DateTimeRange? dateRange;

  const MapMonitoring({super.key, this.dateRange});

  @override
  State<MapMonitoring> createState() => _MapMonitoringState();
}

class _MapMonitoringState extends State<MapMonitoring> {
  // Constants
  static const LatLng _initialPosition = LatLng(14.5995, 120.9842);
  static const double _initialZoom = 13.0;
  static const double _mapHeight = 660.5;

  // State
  final List<Marker> _markers = [];
  final Map<String, LatLng> _geocodingCache = {};
  final Map<String, Color> _iconColorCache = {};
  MapController? _mapController;
  StreamSubscription? _incidentsSub;

  Map<String, dynamic>? _selectedIncident;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Debounce
  DateTime _lastGeocodeTime = DateTime.now();
  static const Duration _geocodeDebounce = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _preloadColors();
    _loadIncidents();
  }

  @override
  void didUpdateWidget(MapMonitoring oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if the dateRange has changed
    if (widget.dateRange != oldWidget.dateRange) {
      _loadIncidents();
    }
  }

  Future<void> _preloadColors() async {
    for (final type in ['fire', 'flood', 'accident', 'typhoon', 'other']) {
      _iconColorCache[type] = _getDisasterColor(type);
    }
  }

  Future<void> _loadIncidents() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final supabase = Supabase.instance.client;
      
      // Get all incidents first
      final response = await supabase
          .from('incidents')
          .select('*')
          .order('timestamp', ascending: false);

      List<Map<String, dynamic>> allIncidents = List<Map<String, dynamic>>.from(response);
      
      // Apply date filtering locally
      final filteredIncidents = _filterIncidentsByDate(allIncidents);
      await _processIncidents(filteredIncidents);
      
    } catch (error) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error loading incidents: $error';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _filterIncidentsByDate(List<Map<String, dynamic>> incidents) {
    final now = DateTime.now();
    DateTime start, end;

    if (widget.dateRange != null) {
      start = DateTime(
        widget.dateRange!.start.year,
        widget.dateRange!.start.month,
        widget.dateRange!.start.day,
        0, 0, 0,
      );
      end = DateTime(
        widget.dateRange!.end.year,
        widget.dateRange!.end.month,
        widget.dateRange!.end.day,
        23, 59, 59, 999,
      );
    } else {
      start = DateTime(now.year, now.month, now.day, 0, 0, 0);
      end = now;
    }

    return incidents.where((incident) {
      final timestamp = incident['timestamp'];
      if (timestamp == null) return false;
      
      try {
        final incidentDate = DateTime.parse(timestamp);
        return incidentDate.isAfter(start) && incidentDate.isBefore(end);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Future<void> _processIncidents(List<Map<String, dynamic>> incidents) async {
    if (!mounted) return;
    
    final newMarkers = <Marker>[];
    final processed = <String>{};

    for (final incident in incidents) {
      final id = incident['id'].toString();
      if (processed.contains(id)) continue;
      processed.add(id);
      
      // Filter out resolved and declined incidents
      final status = (incident['status'] ?? '').toString().toLowerCase();
      if (status == 'resolved' || status == 'declined') {
        continue;
      }

      final pos = await _getIncidentPosition(incident);
      if (pos != null) {
        final marker = _createMarker(id, incident, pos);
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

  Marker _createMarker(String id, Map<String, dynamic> data, LatLng pos) {
    final type = (data['incident_type'] ?? 'other').toString().toLowerCase();
    final markerColor = _iconColorCache[type] ?? _getDisasterColor(type);

    return Marker(
      point: pos,
      width: 40,
      height: 40,
      child: GestureDetector(
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
          });
          _mapController?.move(pos, 18);
        },
        child: Icon(
          Icons.location_on,
          color: markerColor,
          size: 40,
        ),
      ),
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
        color = Colors.blue;
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
      case 'declined':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38), // Fixed: replaced withOpacity with withAlpha
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is String) {
      try {
        final date = DateTime.parse(timestamp);
        return DateFormat('MMM d, h:mm a').format(date);
      } catch (e) {
        return 'Unknown';
      }
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
          color: Colors.white.withAlpha(242), // Fixed: replaced withOpacity with withAlpha
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 6, offset: const Offset(0, 2)), // Fixed
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
                const Icon(Icons.map_rounded, size: 24, color: Colors.black),
                const SizedBox(width: 12),
                const Text('MAP MONITORING',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: "Refresh Map",
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  onPressed: () {
                    setState(() {
                      _selectedIncident = null;
                      _markers.clear();
                      _isLoading = true;
                      _hasError = false;
                    });
                    _loadIncidents();
                    _mapController?.move(_initialPosition, _initialZoom);
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
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialPosition,
                    initialZoom: _initialZoom,
                    onTap: (_, __) => setState(() => _selectedIncident = null), // Fixed: single underscore
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(markers: _markers),
                  ],
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