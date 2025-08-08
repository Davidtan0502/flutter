import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HazardMappingScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const HazardMappingScreen({super.key, required this.onMenuPressed});

  @override
  State<HazardMappingScreen> createState() => _HazardMappingScreenState();
}

class HazardItem {
  final String id;
  final String type;
  final String date;
  final LatLng location;

  HazardItem({required this.id, required this.type, required this.date, required this.location});
}

class _HazardMappingScreenState extends State<HazardMappingScreen> {
  late GoogleMapController _googleMapController;
  final LatLng _manilaCenter = const LatLng(14.5995, 120.9842);
  final List<HazardItem> _hazardItems = [];
  final Set<Polyline> _polylines = {};
  final Set<Polygon> _polygons = {
    Polygon(
      polygonId: const PolygonId('floodArea'),
      points: [
        LatLng(14.5900, 120.9700),
        LatLng(14.5950, 120.9750),
        LatLng(14.5920, 120.9800),
        LatLng(14.5870, 120.9750),
      ],
      fillColor: Colors.blue.withOpacity(0.3),
      strokeColor: Colors.blue,
      strokeWidth: 2,
    ),
  };

  String _selectedHazardType = 'Flood';
  List<HazardItem> _filteredHazards = [];
  String _filterType = 'All';

  @override
  void initState() {
    super.initState();
    _listenToHazards();
  }

  void _listenToHazards() {
    FirebaseFirestore.instance.collection('hazards').snapshots().listen((snapshot) {
      _hazardItems.clear();
      _polylines.clear();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final LatLng location = LatLng(data['lat'], data['lng']);
        final String type = data['type'];
        final String date = data['date'];
        final item = HazardItem(id: doc.id, type: type, date: date, location: location);

        _hazardItems.add(item);

        if (type == 'Traffic') {
          _polylines.add(
            Polyline(
              polylineId: PolylineId(doc.id),
              color: Colors.purple,
              width: 4,
              points: [
                location,
                LatLng(location.latitude + 0.001, location.longitude + 0.001),
              ],
            ),
          );
        }
      }
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredHazards = _filterType == 'All'
        ? List.from(_hazardItems)
        : _hazardItems.where((h) => h.type == _filterType).toList();
    _updateMarkers();
    setState(() {});
  }

  final Set<Marker> _markers = {};

  void _updateMarkers() {
    _markers.clear();
    for (final hazard in _filteredHazards) {
      _markers.add(
        Marker(
          markerId: MarkerId(hazard.id),
          position: hazard.location,
          icon: BitmapDescriptor.defaultMarkerWithHue(_getHazardHue(hazard.type)),
          infoWindow: InfoWindow(title: hazard.type, snippet: hazard.date),
        ),
      );
    }
  }

  double _getHazardHue(String type) {
    switch (type) {
      case 'Flood':
        return BitmapDescriptor.hueBlue;
      case 'Fire':
        return BitmapDescriptor.hueRed;
      case 'Earthquake':
        return BitmapDescriptor.hueOrange;
      case 'Landslide':
        return BitmapDescriptor.hueYellow;
      case 'Traffic':
        return BitmapDescriptor.hueViolet;
      default:
        return BitmapDescriptor.hueMagenta;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C5282),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: widget.onMenuPressed,
        ),
        title: const Text(
          'Manila City Hazard Mapping',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.filter_alt, color: Colors.white), onPressed: _showFilterDialog),
          IconButton(icon: const Icon(Icons.layers, color: Colors.white), onPressed: _showLayerOptions),
          IconButton(icon: const Icon(Icons.my_location, color: Colors.white), onPressed: _centerMap),
        ],
      ),
      body: Row(
        children: [
          _buildSidePanel(),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _manilaCenter, zoom: 13),
              onMapCreated: (controller) => _googleMapController = controller,
              markers: _markers,
              polygons: _polygons,
              polylines: _polylines,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2C5282),
        onPressed: _showLegend,
        icon: const Icon(Icons.info_outline, color: Colors.white),
        label: const Text('Legend', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hazard Reporting',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C5282)),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedHazardType,
            items: const [
              DropdownMenuItem(value: 'Flood', child: Text('Flood')),
              DropdownMenuItem(value: 'Fire', child: Text('Fire')),
              DropdownMenuItem(value: 'Earthquake', child: Text('Earthquake')),
              DropdownMenuItem(value: 'Landslide', child: Text('Landslide')),
              DropdownMenuItem(value: 'Traffic', child: Text('Traffic Accident')),
            ],
            onChanged: (value) => setState(() => _selectedHazardType = value!),
            decoration: InputDecoration(
              labelText: 'Select Hazard Type',
              labelStyle: const TextStyle(color: Colors.blueGrey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _reportHazard,
            icon: const Icon(Icons.add_location),
            label: const Text('Report Hazard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C5282),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent Hazards',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Divider(thickness: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredHazards.length,
              itemBuilder: (context, index) {
                final hazard = _filteredHazards[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(Icons.warning, color: _getHazardColor(hazard.type)),
                    title: Text(hazard.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Reported: ${hazard.date}'),
                    trailing: const Icon(Icons.zoom_in, color: Colors.blueGrey),
                    onTap: () => _googleMapController.animateCamera(CameraUpdate.newLatLng(hazard.location)),
                    onLongPress: () => _deleteHazard(hazard.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _deleteHazard(String id) async {
    await FirebaseFirestore.instance.collection('hazards').doc(id).delete();
  }

  void _reportHazard() async {
    final random = Random();
    final offset = (random.nextDouble() * 0.02) - 0.01;
    final location = LatLng(_manilaCenter.latitude + offset, _manilaCenter.longitude + offset);
    final date = DateTime.now().toString().substring(0, 16);

    await FirebaseFirestore.instance.collection('hazards').add({
      'type': _selectedHazardType,
      'lat': location.latitude,
      'lng': location.longitude,
      'date': date,
    });
  }

  void _centerMap() => _googleMapController.animateCamera(CameraUpdate.newLatLngZoom(_manilaCenter, 13));

  void _showLegend() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hazard Legend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLegendItem('Flood', Colors.blue),
            _buildLegendItem('Fire', Colors.red),
            _buildLegendItem('Earthquake', Colors.brown),
            _buildLegendItem('Landslide', Colors.orange),
            _buildLegendItem('Traffic', Colors.purple),
            const SizedBox(height: 10),
            Container(
              height: 20,
              width: double.infinity,
              color: Colors.blue.withOpacity(0.3),
              child: const Center(child: Text('Flood-prone Area')),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showLayerOptions() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Map Layers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CheckboxListTile(title: Text('Flood-prone Areas'), value: true, onChanged: null),
            CheckboxListTile(title: Text('Fire Stations'), value: false, onChanged: null),
            CheckboxListTile(title: Text('Evacuation Centers'), value: false, onChanged: null),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Filter by Hazard Type'),
        content: DropdownButtonFormField<String>(
          value: _filterType,
          items: const [
            DropdownMenuItem(value: 'All', child: Text('All')),
            DropdownMenuItem(value: 'Flood', child: Text('Flood')),
            DropdownMenuItem(value: 'Fire', child: Text('Fire')),
            DropdownMenuItem(value: 'Earthquake', child: Text('Earthquake')),
            DropdownMenuItem(value: 'Landslide', child: Text('Landslide')),
            DropdownMenuItem(value: 'Traffic', child: Text('Traffic Accident')),
          ],
          onChanged: (value) => setState(() => _filterType = value!),
          decoration: const InputDecoration(
            labelText: 'Hazard Type',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [TextButton(onPressed: () {
          Navigator.pop(context);
          _applyFilters();
        }, child: const Text('Apply'))],
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 16),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Color _getHazardColor(String type) {
    switch (type) {
      case 'Flood':
        return Colors.blue;
      case 'Fire':
        return Colors.red;
      case 'Earthquake':
        return Colors.brown;
      case 'Landslide':
        return Colors.orange;
      case 'Traffic':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
