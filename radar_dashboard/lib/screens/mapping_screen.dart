import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Date selection mode enum (moved to top level)
enum DateSelectionMode {
  single,
  range,
  multiple,
  all
}

class MapMonitoringScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const MapMonitoringScreen({super.key, required this.onMenuPressed});

  @override
  State<MapMonitoringScreen> createState() => _MapMonitoringScreenState();
}

class _MapMonitoringScreenState extends State<MapMonitoringScreen> {
  static const latlng.LatLng _initialPosition = latlng.LatLng(14.5995, 120.9842); // Manila
  static const double _initialZoom = 13.0;

  final List<Marker> _markers = [];
  final Map<String, latlng.LatLng> _geocodingCache = {};
  final Map<String, Widget> _iconCache = {};
  MapController? _mapController;
  List<Map<String, dynamic>> _incidents = [];

  bool _legendVisible = true;
  bool _statsVisible = true;
  Map<String, dynamic>? _selectedIncident;
  bool _isLoading = true;
  bool _isZoomedToMarker = false;
  
  // Date filtering variables
  final DateTime _minDate = DateTime(2024, 1, 1);
  final DateTime _maxDate = DateTime(2025, 12, 31);
  
  // Enhanced date selection
  DateSelectionMode _dateSelectionMode = DateSelectionMode.single;
  DateTime _selectedSingleDate = DateTime.now();
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  Set<DateTime> _selectedMultipleDates = {DateTime.now()};
  
  // Statistics
  Map<String, int> _incidentStats = {};

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _preloadIcons().then((_) {
      _loadIncidents();
    });
  }

  // ========== DATE FILTERING METHODS ==========
  String get _dateFilterDisplayText {
    switch (_dateSelectionMode) {
      case DateSelectionMode.single:
        return _getFormattedDate(_selectedSingleDate);
      case DateSelectionMode.range:
        return '${_getFormattedDate(_selectedDateRange.start)} - ${_getFormattedDate(_selectedDateRange.end)}';
      case DateSelectionMode.multiple:
        if (_selectedMultipleDates.isEmpty) return 'Select dates';
        if (_selectedMultipleDates.length == 1) {
          return _getFormattedDate(_selectedMultipleDates.first);
        }
        return '${_selectedMultipleDates.length} dates selected';
      case DateSelectionMode.all:
        return 'All Dates';
    }
  }

  List<DateTime> get _selectedDates {
    switch (_dateSelectionMode) {
      case DateSelectionMode.single:
        return [_selectedSingleDate];
      case DateSelectionMode.range:
        final dates = <DateTime>[];
        DateTime current = _selectedDateRange.start;
        while (current.isBefore(_selectedDateRange.end) || current.isAtSameMomentAs(_selectedDateRange.end)) {
          dates.add(DateTime(current.year, current.month, current.day));
          current = current.add(const Duration(days: 1));
        }
        return dates;
      case DateSelectionMode.multiple:
        return _selectedMultipleDates.toList();
      case DateSelectionMode.all:
        return []; // Empty list means no date filtering
    }
  }

  Future<void> _showDateSelectionDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DateSelectionDialog(
        currentMode: _dateSelectionMode,
        singleDate: _selectedSingleDate,
        dateRange: _selectedDateRange,
        multipleDates: _selectedMultipleDates,
        minDate: _minDate,
        maxDate: _maxDate,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _dateSelectionMode = result['mode'] as DateSelectionMode;
        _selectedSingleDate = result['singleDate'] as DateTime;
        _selectedDateRange = result['dateRange'] as DateTimeRange;
        _selectedMultipleDates = Set<DateTime>.from(result['multipleDates'] as List<DateTime>);
      });
      _refreshMap();
    }
  }

  // ========== MAP & INCIDENT METHODS ==========
  Future<void> _preloadIcons() async {
    try {
      final types = ['fire', 'flood', 'accident', 'other accidents', 'unknown'];
      
      for (final type in types) {
        _iconCache[type] = _buildCustomMarkerIcon(type);
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error preloading icons: $e');
      _loadDefaultIcons();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadDefaultIcons() {
    final types = ['fire', 'flood', 'accident', 'other accidents', 'unknown'];
    for (final type in types) {
      _iconCache[type] = _buildCustomMarkerIcon(type);
    }
  }

  Widget _buildCustomMarkerIcon(String type) {
    final color = _getIncidentColor(type);
    const size = 52.0;
    
    return Container(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shadow
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              width: size - 12,
              height: size - 12,
              decoration: BoxDecoration(
                color: const Color(0xFF000000).withOpacity(0.4),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withOpacity(0.4),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),
          
          // Glow effect
          Container(
            width: size - 4,
            height: size - 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          
          // Main circle with gradient
          Container(
            width: size - 8,
            height: size - 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color, Color.lerp(color, const Color(0xFF000000), 0.2)!],
              ),
              border: Border.all(
                color: const Color(0xFFFFFFFF),
                width: 3.0,
              ),
            ),
          ),
          
          // Icon
          Icon(
            IconData(
              _getIconCodePoint(type),
              fontFamily: 'MaterialIcons',
            ),
            size: 22,
            color: const Color(0xFFFFFFFF),
          ),
        ],
      ),
    );
  }

  int _getIconCodePoint(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return 0xe1c3;
      case 'flood':
        return 0xe1c7;
      case 'accident':
        return 0xe1db;
      case 'other accidents':
        return 0xe1b8;
      default:
        return 0xe1ca;
    }
  }

  Future<void> _loadIncidents() async {
    try {
      setState(() => _isLoading = true);
      
      var query = _supabase
          .from('incidents')
          .select()
          .neq('status', 'resolved');

      final response = await query;
      
      debugPrint('Fetched ${response.length} incidents from Supabase');
      if (response.isNotEmpty) {
        debugPrint('First incident: ${response.first}');
      }
      
      if (mounted) {
        await _processIncidents(response);
      }
    } catch (e) {
      debugPrint('Error loading incidents: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load incidents: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processIncidents(List<dynamic> docs) async {
    final newMarkers = <Marker>[];
    final stats = <String, int>{};

    // Apply date filtering locally
    final filteredDocs = _filterIncidentsByDate(docs.cast<Map<String, dynamic>>());

    for (int i = 0; i < filteredDocs.length; i++) {
      final doc = filteredDocs[i];
      
      // Update statistics - use 'incident_type' to match your Supabase schema
      final type = (doc['incident_type'] ?? 'unknown').toString().toLowerCase();
      stats[type] = (stats[type] ?? 0) + 1;
      
      // Add small delay to prevent UI blocking
      if (i % 5 == 0) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      final position = await _getIncidentPosition(doc);
      if (position != null) {
        final marker = _createIncidentMarker(doc['id'] as String? ?? '', doc, position);
        newMarkers.add(marker);
      } else {
        debugPrint('Could not get position for incident: ${doc['id']}');
      }
    }

    if (mounted) {
      setState(() {
        _incidents = filteredDocs;
        _markers
          ..clear()
          ..addAll(newMarkers);
        _incidentStats = stats;
      });
    }
  }

  List<Map<String, dynamic>> _filterIncidentsByDate(List<Map<String, dynamic>> docs) {
    final selectedDates = _selectedDates;
    
    if (_dateSelectionMode == DateSelectionMode.all || selectedDates.isEmpty) {
      return docs;
    }

    return docs.where((doc) {
      final timestampStr = doc['timestamp'] as String?;
      if (timestampStr == null) return false;
      
      try {
        final timestamp = DateTime.parse(timestampStr);
        final incidentDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
        
        return selectedDates.any((selectedDate) => 
          incidentDate.year == selectedDate.year &&
          incidentDate.month == selectedDate.month &&
          incidentDate.day == selectedDate.day
        );
      } catch (e) {
        debugPrint('Error parsing timestamp for filtering: $e');
        return false;
      }
    }).toList();
  }

  Future<latlng.LatLng?> _getIncidentPosition(Map<String, dynamic> data) async {
    try {
      // First try to get coordinates directly
      final coordinates = _parseCoordinates(data);
      if (coordinates != null) return coordinates;

      // If no coordinates, try geocoding the address
      if (data['address'] != null) {
        return await _geocodeAddress(data['address'].toString());
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting position for incident: $e');
      return null;
    }
  }

  latlng.LatLng? _parseCoordinates(Map<String, dynamic> data) {
    try {
      // Try different possible field names for coordinates
      final lat = data['latitude'] ?? data['lat'];
      final lng = data['longitude'] ?? data['lng'] ?? data['lon'];
      
      double? parsedLat;
      double? parsedLng;
      
      if (lat is double) {
        parsedLat = lat;
      } else if (lat is int) {
        parsedLat = lat.toDouble();
      } else if (lat is String) {
        parsedLat = double.tryParse(lat);
      }
      
      if (lng is double) {
        parsedLng = lng;
      } else if (lng is int) {
        parsedLng = lng.toDouble();
      } else if (lng is String) {
        parsedLng = double.tryParse(lng);
      }

      return (parsedLat != null && parsedLng != null && _isValidLatLng(parsedLat, parsedLng)) 
          ? latlng.LatLng(parsedLat, parsedLng) 
          : null;
    } catch (_) {
      return null;
    }
  }

  bool _isValidLatLng(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  Future<latlng.LatLng?> _geocodeAddress(String address) async {
    if (_geocodingCache.containsKey(address)) {
      return _geocodingCache[address];
    }
    
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final pos = latlng.LatLng(locations.first.latitude, locations.first.longitude);
        _geocodingCache[address] = pos;
        return pos;
      }
    } catch (e) {
      debugPrint('Geocoding error for address "$address": $e');
    }
    
    return null;
  }

  // ========== MARKER METHODS ==========
  Marker _createIncidentMarker(String id, Map<String, dynamic> data, latlng.LatLng position) {
    // Use 'incident_type' instead of 'incident_type' to match your Supabase schema
    final type = (data['incident_type'] ?? 'unknown').toString().toLowerCase();
    final icon = _iconCache[type] ?? _buildCustomMarkerIcon(type);
    final isSelected = _selectedIncident != null && _selectedIncident!['id'] == id;

    return Marker(
      point: position,
      width: 52.0,
      height: 52.0,
      child: GestureDetector(
        onTap: () => _onMarkerTapped(id, data, position),
        child: Transform.scale(
          scale: isSelected ? 1.2 : 1.0,
          child: icon,
        ),
      ),
    );
  }

  void _onMarkerTapped(String id, Map<String, dynamic> data, latlng.LatLng position) {
    setState(() {
      _selectedIncident = {
        'id': id,
        // Use 'incident_type' to match your Supabase schema
        'type': (data['incident_type'] ?? 'unknown').toString().toLowerCase(),
        'status': (data['status'] ?? 'pending').toString(),
        'address': (data['address'] ?? 'Unknown location').toString(),
        'timestamp': (data['timestamp'] ?? DateTime.now().toIso8601String()).toString(),
        'description': data['description']?.toString() ?? 'No description provided',
      };
      _isZoomedToMarker = true;
    });
    
    _mapController?.move(position, 16);
  }

  Color _getIncidentColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return const Color(0xFFFF5252);
      case 'flood':
        return const Color(0xFF448AFF);
      case 'accident':
        return const Color(0xFFFF9800);
      case 'other accidents':
        return const Color(0xFFE040FB);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  // ========== UI COMPONENTS ==========
  Widget _buildDateFilterButton() {
    return GestureDetector(
      onTap: _showDateSelectionDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withAlpha(26), // 10% opacity
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF2C5282)),
            const SizedBox(width: 6),
            Text(
              _dateFilterDisplayText,
              style: const TextStyle(fontSize: 14, color: Color(0xFF2C5282)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF2C5282)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsPanel() {
    if (!_statsVisible || _incidentStats.isEmpty) return const SizedBox();

    final totalIncidents = _incidentStats.values.fold(0, (int sum, int count) => sum + count);

    return Positioned(
      top: 80,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF).withAlpha(242), // 95% opacity
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFFFFF).withAlpha(77)), // 30% opacity
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'INCIDENT STATS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C5282),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _statsVisible = false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Total: $totalIncidents',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xDE000000).withOpacity(0.87), // 87% opacity
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ..._incidentStats.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getIncidentColor(entry.key),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFFFFF), width: 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xDE000000).withOpacity(0.87), // 87% opacity
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C5282),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    if (!_legendVisible) return const SizedBox();

    final entries = {
      'Fire': _getIncidentColor('fire'),
      'Flood': _getIncidentColor('flood'),
      'Accident': _getIncidentColor('accident'),
      'Other': _getIncidentColor('other accidents'),
      'Unknown': _getIncidentColor('unknown'),
    };

    return Positioned(
      top: 80,
      left: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF).withAlpha(242), // 95% opacity
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFFFFF).withAlpha(77)), // 30% opacity
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'LEGEND',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C5282),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _legendVisible = false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...entries.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: e.value,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFFFFF), width: 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xDE000000).withOpacity(0.87), // 87% opacity
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

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
        color: color.withAlpha(38), // 15% opacity
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

  Widget _buildIncidentDetailsPanel() {
    if (_selectedIncident == null) return const SizedBox();

    final data = _selectedIncident!;
    
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFAFAFA),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _getIncidentColor(data['type']),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF000000).withAlpha(26), // 10% opacity
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['type'].toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xDE000000).withOpacity(0.87), // 87% opacity
                      ),
                    ),
                  ),
                  _buildStatusChip(data['status']),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF9E9E9E)),
                    onPressed: _closeDetailsPanel,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.location_on, data['address']),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.access_time, 'Reported: ${_formatTimestamp(data['timestamp'])}'),
              if (data['description'] != null && data['description'].isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetailRow(Icons.description, data['description'], maxLines: 3),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2C5282)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13, 
              color: const Color(0xDE000000).withOpacity(0.87) // 87% opacity
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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

  String _getFormattedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    
    return '${date.month}/${date.day}/${date.year}';
  }

  void _closeDetailsPanel() {
    setState(() => _selectedIncident = null);
    _resetToDefaultView();
  }

  void _resetToDefaultView() {
    _mapController?.move(_initialPosition, _initialZoom);
    setState(() => _isZoomedToMarker = false);
  }

  void _refreshMap() {
    _geocodingCache.clear();
    _resetToDefaultView();
    setState(() => _selectedIncident = null);
    _loadIncidents();
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Color(0xFFFFFFFF)),
        onPressed: widget.onMenuPressed,
      ),
      title: const Text(
        'MAP MONITORING',
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      backgroundColor: const Color(0xFF2C5282),
      elevation: 4,
      shadowColor: const Color(0xFF000000).withAlpha(77), // 30% opacity
      actions: [
        _buildDateFilterButton(),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(_statsVisible ? Icons.analytics : Icons.analytics_outlined, color: const Color(0xFFFFFFFF)),
          onPressed: () => setState(() => _statsVisible = !_statsVisible),
          tooltip: 'Statistics',
        ),
        IconButton(
          icon: Icon(_legendVisible ? Icons.legend_toggle : Icons.legend_toggle_outlined, color: const Color(0xFFFFFFFF)),
          onPressed: () => setState(() => _legendVisible = !_legendVisible),
          tooltip: 'Legend',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFFFFFFFF)),
          onPressed: _refreshMap,
          tooltip: 'Refresh',
        ),
        if (_isZoomedToMarker)
          IconButton(
            icon: const Icon(Icons.zoom_out_map, color: Color(0xFFFFFFFF)),
            onPressed: _resetToDefaultView,
            tooltip: 'Reset View',
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
          FlutterMap(
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: _initialZoom,
              maxZoom: 18,
              minZoom: 3,
              onTap: (_, __) {
                // Close details panel when tapping on map
                if (_selectedIncident != null) {
                  setState(() => _selectedIncident = null);
                }
              },
            ),
            children: [
              // OpenStreetMap Tile Layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              
              // Marker Layer
              MarkerLayer(markers: _markers),
            ],
            mapController: _mapController,
          ),

          Positioned(
            right: 20,
            bottom: _selectedIncident != null ? 220 : 20,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'location',
                  onPressed: () {
                    _mapController?.move(_initialPosition, _initialZoom);
                  },
                  backgroundColor: const Color(0xFFFFFFFF),
                  child: const Icon(Icons.my_location, color: Color(0xFF2C5282)),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    final currentZoom = _mapController?.camera.zoom ?? _initialZoom;
                    _mapController?.move(_mapController!.camera.center, currentZoom + 1);
                  },
                  backgroundColor: const Color(0xFFFFFFFF),
                  child: const Icon(Icons.add, color: Color(0xFF2C5282)),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    final currentZoom = _mapController?.camera.zoom ?? _initialZoom;
                    _mapController?.move(_mapController!.camera.center, currentZoom - 1);
                  },
                  backgroundColor: const Color(0xFFFFFFFF),
                  child: const Icon(Icons.remove, color: Color(0xFF2C5282)),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C5282)),
              ),
            ),

          _buildLegend(),
          _buildStatisticsPanel(),
          _buildIncidentDetailsPanel(),
        ],
      ),
    );
  }
}

// ========== DATE SELECTION DIALOG ==========
class DateSelectionDialog extends StatefulWidget {
  final DateSelectionMode currentMode;
  final DateTime singleDate;
  final DateTimeRange dateRange;
  final Set<DateTime> multipleDates;
  final DateTime minDate;
  final DateTime maxDate;

  const DateSelectionDialog({
    super.key,
    required this.currentMode,
    required this.singleDate,
    required this.dateRange,
    required this.multipleDates,
    required this.minDate,
    required this.maxDate,
  });

  @override
  State<DateSelectionDialog> createState() => _DateSelectionDialogState();
}

class _DateSelectionDialogState extends State<DateSelectionDialog> {
  late DateSelectionMode _currentMode;
  late DateTime _selectedSingleDate;
  late DateTimeRange _selectedDateRange;
  late Set<DateTime> _selectedMultipleDates;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.currentMode;
    _selectedSingleDate = widget.singleDate;
    _selectedDateRange = widget.dateRange;
    _selectedMultipleDates = Set<DateTime>.from(widget.multipleDates);
  }

  Widget _buildModeSelector() {
    return Column(
      children: [
        _buildModeTile(
          'Single Date',
          Icons.calendar_today,
          DateSelectionMode.single,
        ),
        _buildModeTile(
          'Date Range',
          Icons.date_range,
          DateSelectionMode.range,
        ),
        _buildModeTile(
          'Multiple Dates',
          Icons.calendar_view_day,
          DateSelectionMode.multiple,
        ),
        _buildModeTile(
          'All Dates',
          Icons.all_inclusive,
          DateSelectionMode.all,
        ),
      ],
    );
  }

  Widget _buildModeTile(String title, IconData icon, DateSelectionMode mode) {
    final isSelected = _currentMode == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF2C5282) : const Color(0xFF9E9E9E)),
      title: Text(title, style: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? const Color(0xFF2C5282) : const Color(0xDE000000).withOpacity(0.87),
      )),
      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF2C5282)) : null,
      onTap: () {
        setState(() => _currentMode = mode);
      },
    );
  }

  Widget _buildDateSelector() {
    switch (_currentMode) {
      case DateSelectionMode.single:
        return _buildSingleDateSelector();
      case DateSelectionMode.range:
        return _buildRangeDateSelector();
      case DateSelectionMode.multiple:
        return _buildMultipleDateSelector();
      case DateSelectionMode.all:
        return _buildAllDatesSelector();
    }
  }

  Widget _buildSingleDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Selected: ${_getFormattedDate(_selectedSingleDate)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(
          height: 300,
          child: CalendarDatePicker(
            initialDate: _selectedSingleDate,
            firstDate: widget.minDate,
            lastDate: widget.maxDate,
            onDateChanged: (date) {
              setState(() => _selectedSingleDate = date);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRangeDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Text(
            'From: ${_getFormattedDate(_selectedDateRange.start)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Text(
            'To: ${_getFormattedDate(_selectedDateRange.end)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(
          height: 300,
          child: CalendarDatePicker(
            initialDate: _selectedDateRange.start,
            firstDate: widget.minDate,
            lastDate: widget.maxDate,
            onDateChanged: (date) {
              setState(() {
                _selectedDateRange = DateTimeRange(
                  start: date.isBefore(_selectedDateRange.end) ? date : _selectedDateRange.end,
                  end: date.isAfter(_selectedDateRange.start) ? date : _selectedDateRange.start,
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMultipleDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Selected: ${_selectedMultipleDates.length} dates',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(
          height: 300,
          child: CalendarDatePicker(
            initialDate: _selectedMultipleDates.isNotEmpty ? _selectedMultipleDates.first : DateTime.now(),
            firstDate: widget.minDate,
            lastDate: widget.maxDate,
            onDateChanged: (date) {
              setState(() {
                if (_selectedMultipleDates.contains(date)) {
                  _selectedMultipleDates.remove(date);
                } else {
                  _selectedMultipleDates.add(DateTime(date.year, date.month, date.day));
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllDatesSelector() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          Icon(Icons.all_inclusive, size: 48, color: Color(0xFF2C5282)),
          SizedBox(height: 16),
          Text(
            'Showing incidents from all available dates',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _getFormattedDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _applySelection() {
    final result = {
      'mode': _currentMode,
      'singleDate': _selectedSingleDate,
      'dateRange': _selectedDateRange,
      'multipleDates': _selectedMultipleDates.toList(),
    };
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Select Date Filter',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C5282),
                  ),
                ),
              ),
              
              // Mode Selector
              Expanded(
                flex: 0,
                child: Card(
                  elevation: 2,
                  child: _buildModeSelector(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Date Selector (Scrollable)
              Expanded(
                child: Card(
                  elevation: 2,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildDateSelector(),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2C5282),
                        side: const BorderSide(color: Color(0xFF2C5282)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applySelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C5282),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'APPLY',
                        style: TextStyle(color: Color(0xFFFFFFFF)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}