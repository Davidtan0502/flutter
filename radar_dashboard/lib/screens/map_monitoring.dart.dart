import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:radar_dashboard/components/section_header.dart';

class MapMonitoring extends StatefulWidget {
  const MapMonitoring({super.key});

  @override
  State<MapMonitoring> createState() => _MapMonitoringState();
}

class _MapMonitoringState extends State<MapMonitoring> {
  final LatLng _initialPosition = const LatLng(14.5995, 120.9842); // Default Manila position
  Set<Marker> _markers = {};
  late GoogleMapController _mapController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndGeocodeIncidents();
  }

  Future<void> _fetchAndGeocodeIncidents() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('incidents')
          .where('address', isNotEqualTo: null)
          .get();

      final markers = <Marker>{};
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final address = data['address'] as String;
        
        // Geocode address to get coordinates
        final locations = await locationFromAddress(address);
        if (locations.isNotEmpty) {
          final location = locations.first;
          final position = LatLng(location.latitude, location.longitude);

          markers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: position,
              infoWindow: InfoWindow(
                title: data['incidentType'] ?? 'Incident',
                snippet: address,
              ),
            ),
          );
        }
      }

      setState(() {
        _markers = markers;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error (you might want to show a snackbar)
      debugPrint('Geocoding error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
            height: 600,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _initialPosition,
                        zoom: 12,
                      ),
                      mapType: MapType.normal,
                      myLocationEnabled: true,
                      markers: _markers,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}