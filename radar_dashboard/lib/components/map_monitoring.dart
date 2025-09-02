// Hazard Map (Focused)
// File: hazard_map.dart
// Description: Lightweight Flutter widget that renders hazard zones on Google Maps.
// Data sources supported:
//  - Firestore collection 'hazard_zones' (each doc: {name, severity, coordinates: [ {lat, lng}, ... ], description, colorHex?})
//  - Local GeoJSON (optional) — helper included
// Dependencies (add to pubspec.yaml):
//   google_maps_flutter: any
//   cloud_firestore: any
//   geojson: any (optional)

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMonitoring extends StatefulWidget {
  const MapMonitoring({super.key});

  /// If provided, the widget will read hazard zones from this path in Firestore.
  final String firestoreCollection = 'hazard_zones';

  @override
  State<MapMonitoring> createState() => _MapMonitoringState();
}

class _MapMonitoringState extends State<MapMonitoring> {
  static const LatLng _initialPosition = LatLng(14.5995, 120.9842);
  static const double _initialZoom = 12.0;

  GoogleMapController? _mapController;
  final Set<Polygon> _polygons = {};
  final Map<String, Map<String, dynamic>> _zoneMeta = {};
  StreamSubscription<QuerySnapshot>? _zonesSub;

  @override
  void initState() {
    super.initState();
    _subscribeZones();
  }

  void _subscribeZones() {
    final col = FirebaseFirestore.instance.collection('hazard_zones');
    _zonesSub = col.snapshots().listen((snap) {
      _loadZonesFromSnapshot(snap.docs);
    }, onError: (e) => debugPrint('Zones stream error: $e'));
  }

  void _loadZonesFromSnapshot(List<QueryDocumentSnapshot> docs) {
    final newPolys = <Polygon>{};
    final newMeta = <String, Map<String, dynamic>>{};

    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final id = doc.id;
        final name = data['name']?.toString() ?? id;
        final severity = (data['severity'] ?? 'unknown').toString();
        final description = data['description']?.toString() ?? '';

        // Expect coordinates as a list of maps: [{"lat": x, "lng": y}, ...]
        final coordsRaw = data['coordinates'];
        if (coordsRaw == null || coordsRaw is! List) continue;

        final points = <LatLng>[];
        for (final p in coordsRaw) {
          if (p is Map) {
            final lat = (p['lat'] as num?)?.toDouble();
            final lng = (p['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) points.add(LatLng(lat, lng));
          }
        }

        if (points.length < 3) continue; // not a polygon

        final color = _colorForSeverity(severity);

        final poly = Polygon(
          polygonId: PolygonId(id),
          points: points,
          fillColor: color.withOpacity(0.18),
          strokeColor: color.withOpacity(0.8),
          strokeWidth: 2,
          consumeTapEvents: true,
          onTap: () => _onZoneTap(id),
        );

        newPolys.add(poly);
        newMeta[id] = {'name': name, 'severity': severity, 'description': description, 'color': color};
      } catch (e) {
        debugPrint('Error parsing zone ${doc.id}: $e');
      }
    }

    if (mounted) {
      setState(() {
        _polygons
          ..clear()
          ..addAll(newPolys);
        _zoneMeta
          ..clear()
          ..addAll(newMeta);
      });
    }
  }

  Color _colorForSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.amber;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _onZoneTap(String id) {
    final meta = _zoneMeta[id];
    if (meta == null) return;

    showModalBottomSheet(context: context, builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 12, height: 12, color: meta['color'] as Color),
              const SizedBox(width: 8),
              Text(meta['name'] ?? 'Zone', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Chip(label: Text((meta['severity'] ?? '').toString().toUpperCase())),
            ]),
            const SizedBox(height: 8),
            Text(meta['description'] ?? ''),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            ])
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Icon(Icons.warning, size: 20),
            SizedBox(width: 8),
            Text('HAZARD MAP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
        ),
        const Divider(height: 1),
        SizedBox(
          height: 420,
          child: Stack(children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _initialPosition, zoom: _initialZoom),
              polygons: _polygons,
              onMapCreated: (ctrl) => _mapController = ctrl,
            ),
            Positioned(right: 12, top: 12, child: _legendCard()),
          ]),
        ),
      ]),
    );
  }

  Widget _legendCard() {
    final severities = ['critical', 'high', 'medium', 'low', 'unknown'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Legend', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          for (final s in severities)
            Row(children: [
              Container(width: 12, height: 12, color: _colorForSeverity(s)),
              const SizedBox(width: 6),
              Text(s.capitalize()),
            ])
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _zonesSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}

// Simple String extension for display
extension _Cap on String {
  String capitalize() => length > 0 ? '${this[0].toUpperCase()}${substring(1)}' : this;
}
