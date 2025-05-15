import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:radar_dashboard/components/section_header.dart';
import 'package:radar_dashboard/services/cache_manager.dart';
import 'package:radar_dashboard/services/performance_monitor.dart';

class MapMonitoring extends StatefulWidget {
  const MapMonitoring({super.key});

  @override
  State<MapMonitoring> createState() => _MapMonitoringState();
}

class _MapMonitoringState extends State<MapMonitoring> {
  final LatLng _initialPosition = const LatLng(14.5995, 120.9842);
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController; // Made nullable since it's not always used
  final _perfMonitor = PerformanceMonitor();
  final _cacheManager = DashboardCacheManager();
  final _geocodingCache = <String, LatLng>{};

  @override
  void initState() {
    super.initState();
    _perfMonitor.startCustomTrace('map_initialization'); // Changed to startCustomTrace
    _loadCachedData();
    _fetchAndGeocodeIncidents();
  }

  Future<void> _loadCachedData() async {
    final cachedMarkers = await _cacheManager.getData<List<dynamic>>(
      key: 'cached_markers',
      fetchData: () async => [],
      cacheDuration: const Duration(hours: 1),
    );
    
    if (cachedMarkers.isNotEmpty) {
      setState(() {
        _markers.addAll(cachedMarkers.cast<Marker>());
      });
    }
  }

  Future<void> _fetchAndGeocodeIncidents() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('incidents')
          .where('address', isNotEqualTo: null)
          .limit(100)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (data, _) => data,
          )
          .get(const GetOptions(source: Source.serverAndCache));

      final batchSize = 5;
      for (var i = 0; i < querySnapshot.docs.length; i += batchSize) {
        final batch = querySnapshot.docs.sublist(i, i + batchSize);
        await _processBatch(batch);
      }

      _perfMonitor.stopCustomTrace('map_initialization'); // Changed to stopCustomTrace
    } catch (e) {
      _perfMonitor.logEvent('map_error', {'error': e.toString()});
      debugPrint('Map error: $e');
    }
  }

  Future<void> _processBatch(List<QueryDocumentSnapshot> batch) async {
    final newMarkers = <Marker>[];
    
    await Future.wait(batch.map((doc) async {
      final data = doc.data() as Map<String, dynamic>;
      final address = data['address'] as String? ?? '';

      try {
        final position = await _getCachedGeocode(address);
        if (position != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: position,
              infoWindow: InfoWindow(
                title: data['incidentType']?.toString() ?? 'Incident',
                snippet: address,
              ),
              icon: await _getCustomMarkerIcon(data['severity']?.toString() ?? 'unknown'), // Added null check
            ),
          );
        }
      } catch (e) {
        _perfMonitor.logEvent('geocode_failed', {'address': address});
      }
    }));

    setState(() {
      _markers.addAll(newMarkers);
    });

    await _cacheManager.saveData(
      key: 'cached_markers',
      data: newMarkers,
      duration: const Duration(minutes: 30),
    );
  }

  Future<BitmapDescriptor> _getCustomMarkerIcon(String severity) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(120, 120);
    final textPainter = TextPainter(
      text: TextSpan(
        text: severity[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    final paint = Paint()
      ..color = _getSeverityColor(severity)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.fromBytes(bytes); // Updated to use the non-deprecated method
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

  Future<LatLng?> _getCachedGeocode(String address) async {
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
      _perfMonitor.logEvent('geocode_error', {'address': address});
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: SectionHeader(
              icon: Icons.map_outlined,
              title: 'MAP MONITORING',
            ),
          ),
          SizedBox(
            height: 524,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _initialPosition,
                  zoom: 12,
                ),
                mapType: MapType.normal,
                myLocationEnabled: true,
                markers: _markers,
                onMapCreated: (controller) {
                  _mapController = controller;
                  _perfMonitor.logEvent('map_ready');
                },
                onTap: (position) => _perfMonitor.logEvent('map_tap'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _perfMonitor.uploadMetrics();
    _mapController?.dispose(); // Added controller disposal
    super.dispose();
  }
}