import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HazardMappingScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const HazardMappingScreen({super.key, required this.onMenuPressed});

  @override
  State<HazardMappingScreen> createState() => _HazardMappingScreenState();
}

class _HazardMappingScreenState extends State<HazardMappingScreen> {
  final MapController _mapController = MapController();
  final List<Map<String, dynamic>> _hazards = [];
  String _selectedHazardType = 'Flood';
  final LatLng _manilaCenter = const LatLng(14.5995, 120.9842); // Manila coordinates

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manila City Hazard Mapping'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: widget.onMenuPressed,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _showLayerOptions,
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerMap,
          ),
        ],
      ),
      body: Row(
        children: [
          // Side panel
          Container(
            width: 300,
            color: Colors.grey[100],
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hazard Reporting',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  onChanged: (value) {
                    setState(() {
                      _selectedHazardType = value!;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Hazard Type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _reportHazard,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Report Hazard'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recent Hazards',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _hazards.length,
                    itemBuilder: (context, index) {
                      final hazard = _hazards[index];
                      return ListTile(
                        leading: _getHazardIcon(hazard['type']),
                        title: Text(hazard['type']),
                        subtitle: Text('Reported: ${hazard['date']}'),
                        onTap: () => _zoomToHazard(hazard['location']),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Map area
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _manilaCenter,
                initialZoom: 13.0,
                maxZoom: 18,
                minZoom: 10,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.hazardmapping',
                ),
                MarkerLayer(
                  markers: _buildHazardMarkers(),
                ),
                PolygonLayer(
                  polygons: [
                    // Example flood-prone areas in Manila
                    Polygon(
                      points: [
                        const LatLng(14.5900, 120.9700),
                        const LatLng(14.5950, 120.9750),
                        const LatLng(14.5920, 120.9800),
                        const LatLng(14.5870, 120.9750),
                      ],
                      color: Colors.blue.withOpacity(0.3),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showLegend,
        child: const Icon(Icons.info),
      ),
    );
  }

  List<Marker> _buildHazardMarkers() {
    return _hazards.map((hazard) {
      return Marker(
        point: hazard['location'],
        width: 40,
        height: 40,
        child: _getHazardIcon(hazard['type'], size: 30),
      );
    }).toList();
  }

  Widget _getHazardIcon(String type, {double size = 24}) {
    IconData icon;
    Color color;
    
    switch (type) {
      case 'Flood':
        icon = Icons.water_damage;
        color = Colors.blue;
        break;
      case 'Fire':
        icon = Icons.local_fire_department;
        color = Colors.red;
        break;
      case 'Earthquake':
        icon = Icons.landscape;
        color = Colors.brown;
        break;
      case 'Landslide':
        icon = Icons.terrain;
        color = Colors.orange;
        break;
      case 'Traffic':
        icon = Icons.traffic;
        color = Colors.purple;
        break;
      default:
        icon = Icons.warning;
        color = Colors.yellow;
    }
    
    return Icon(icon, color: color, size: size);
  }

  void _reportHazard() {
    final random = Random();
    final randomOffset = (random.nextDouble() * 0.02) - 0.01;
    final hazardLocation = LatLng(
      _manilaCenter.latitude + randomOffset,
      _manilaCenter.longitude + randomOffset,
    );
    
    setState(() {
      _hazards.add({
        'type': _selectedHazardType,
        'location': hazardLocation,
        'date': DateTime.now().toString().substring(0, 16),
      });
    });
    
    // Zoom to the new hazard
    _mapController.move(hazardLocation, 15);
  }

  void _zoomToHazard(LatLng location) {
    _mapController.move(location, 15);
  }

  void _centerMap() {
    _mapController.move(_manilaCenter, 13);
  }

  void _showLayerOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Map Layers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Flood-prone Areas'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Fire Stations'),
              value: false,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Evacuation Centers'),
              value: false,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLegend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
}