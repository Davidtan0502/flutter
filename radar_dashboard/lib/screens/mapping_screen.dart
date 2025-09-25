import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

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
  static const LatLng _initialPosition = LatLng(14.5995, 120.9842); // Manila
  static const double _initialZoom = 13.0;

  final Set<Marker> _markers = {};
  final Map<String, LatLng> _geocodingCache = {};
  final Map<String, BitmapDescriptor> _iconCache = {};
  GoogleMapController? _mapController;
  Stream<QuerySnapshot>? _incidentsStream;

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

  @override
  void initState() {
    super.initState();
    _preloadIcons().then((_) {
      _setupRealTimeIncidents();
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
        _iconCache[type] = await _getCustomMarkerIcon(type);
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
    final colors = {
      'fire': Colors.red,
      'flood': Colors.blue,
      'accident': Colors.orange,
      'other accidents': Colors.purple,
      'unknown': Colors.grey,
    };
    
    colors.forEach((type, color) {
      _iconCache[type] = BitmapDescriptor.defaultMarkerWithHue(
        _colorToHue(color),
      );
    });
  }

  double _colorToHue(Color color) {
    if (color == Colors.red) return BitmapDescriptor.hueRed;
    if (color == Colors.blue) return BitmapDescriptor.hueBlue;
    if (color == Colors.orange) return BitmapDescriptor.hueOrange;
    if (color == Colors.purple) return BitmapDescriptor.hueViolet;
    return BitmapDescriptor.hueAzure;
  }

  void _setupRealTimeIncidents() {
    final selectedDates = _selectedDates;
    
    Query query = FirebaseFirestore.instance
        .collection('incidents')
        .where('status', isNotEqualTo: 'resolved');

    // Apply date filtering only if not "select all"
    if (_dateSelectionMode != DateSelectionMode.all && selectedDates.isNotEmpty) {
      final startDate = DateTime(selectedDates.first.year, selectedDates.first.month, selectedDates.first.day);
      final endDate = startDate.add(const Duration(days: 1));
      
      if (selectedDates.length == 1) {
        query = query
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('timestamp', isLessThan: Timestamp.fromDate(endDate));
      } else {
        // For multiple dates, use array-contains-any if supported, otherwise filter client-side
        query = query
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('timestamp', isLessThan: Timestamp.fromDate(endDate));
      }
    }

    _incidentsStream = query.snapshots();

    _incidentsStream?.listen((snapshot) {
      if (mounted) {
        _processIncidents(snapshot.docs);
      }
    }, onError: (error) {
      debugPrint('Error listening to incidents: $error');
    });
  }

  Future<void> _processIncidents(List<QueryDocumentSnapshot> docs) async {
    final newMarkers = <Marker>{};
    final stats = <String, int>{};

    for (int i = 0; i < docs.length; i++) {
      final doc = docs[i];
      final data = doc.data() as Map<String, dynamic>;
      
      // Update statistics
      final type = (data['incidentType'] ?? 'unknown').toString().toLowerCase();
      stats[type] = (stats[type] ?? 0) + 1;
      
      if (i % 5 == 0) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
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
        _incidentStats = stats;
      });
    }
  }

  Future<LatLng?> _getIncidentPosition(Map<String, dynamic> data) async {
    try {
      final coordinates = _parseCoordinates(data);
      if (coordinates != null) return coordinates;

      if (data['address'] != null) {
        return await _geocodeAddress(data['address'].toString());
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting position: $e');
      return null;
    }
  }

  LatLng? _parseCoordinates(Map<String, dynamic> data) {
    try {
      final lat = data['latitude'] is double
          ? data['latitude']
          : double.tryParse(data['latitude']?.toString() ?? '');
      final lng = data['longitude'] is double
          ? data['longitude']
          : double.tryParse(data['longitude']?.toString() ?? '');

      return (lat != null && lng != null && _isValidLatLng(lat, lng)) 
          ? LatLng(lat, lng) 
          : null;
    } catch (_) {
      return null;
    }
  }

  bool _isValidLatLng(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
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
    } catch (e) {
      debugPrint('Geocoding error for address "$address": $e');
    }
    
    return null;
  }

  // ========== MARKER METHODS ==========
  Future<BitmapDescriptor> _getCustomMarkerIcon(String type) async {
    try {
      final color = _getIncidentColor(type);
      const size = 52.0;
      
      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      final Paint shadowPaint = Paint()
        ..color = const Color(0xFF000000).withAlpha(102) // 40% opacity
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(const Offset(size/2 + 2, size/2 + 2), size/2 - 6, shadowPaint);
      
      final glowPaint = Paint()
        ..color = color.withAlpha(77) // 30% opacity
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);
      canvas.drawCircle(Offset(size/2, size/2), size/2 - 2, glowPaint);
      
      final gradient = RadialGradient(
        colors: [color, Color.lerp(color, const Color(0xFF000000), 0.2)!],
      );
      final gradientPaint = Paint()
        ..shader = gradient.createShader(Rect.fromCircle(center: Offset(size/2, size/2), radius: size/2 - 4));
      canvas.drawCircle(Offset(size/2, size/2), size/2 - 4, gradientPaint);
      
      final borderPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(Offset(size/2, size/2), size/2 - 4, borderPaint);

      final iconCodePoint = _getIconCodePoint(type);
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(iconCodePoint),
          style: TextStyle(
            fontSize: 22,
            color: const Color(0xFFFFFFFF),
            fontFamily: 'MaterialIcons',
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: const Color(0xFF000000).withAlpha(77), // 30% opacity
                blurRadius: 2,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size/2 - textPainter.width/2, size/2 - textPainter.height/2),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      
      return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error creating custom icon: $e');
      return BitmapDescriptor.defaultMarkerWithHue(_colorToHue(_getIncidentColor(type)));
    }
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

  Future<Marker> _createIncidentMarker(
      String id, Map<String, dynamic> data, LatLng position) async {
    final type = (data['incidentType'] ?? 'unknown').toString().toLowerCase();
    final icon = _iconCache[type] ?? await _getCustomMarkerIcon(type);
    final isSelected = _selectedIncident != null && _selectedIncident!['id'] == id;

    return Marker(
      markerId: MarkerId(id),
      position: position,
      onTap: () => _onMarkerTapped(id, data, position),
      icon: icon,
      zIndex: isSelected ? 2 : 1,
      anchor: const Offset(0.5, 0.5),
    );
  }

  void _onMarkerTapped(String id, Map<String, dynamic> data, LatLng position) {
    setState(() {
      _selectedIncident = {
        'id': id,
        'type': (data['incidentType'] ?? 'unknown').toString().toLowerCase(),
        'status': (data['status'] ?? 'pending').toString(),
        'address': (data['address'] ?? 'Unknown location').toString(),
        'timestamp': (data['timestamp'] ?? Timestamp.now()).toString(),
        'description': data['description']?.toString() ?? 'No description provided',
      };
      _isZoomedToMarker = true;
    });
    
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 16));
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
      final Timestamp ts;
      if (timestamp is String) {
        ts = Timestamp.fromDate(DateTime.parse(timestamp));
      } else {
        ts = timestamp as Timestamp;
      }
      final date = ts.toDate();
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
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _initialPosition, zoom: _initialZoom),
      ),
    );
    setState(() => _isZoomedToMarker = false);
  }

  void _refreshMap() {
    _geocodingCache.clear();
    _resetToDefaultView();
    setState(() => _selectedIncident = null);
    _setupRealTimeIncidents();
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
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: _initialZoom,
            ),
            markers: _markers,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: _selectedIncident != null ? 200 : 20,
              left: 20,
              right: 20,
            ),
          ),

          Positioned(
            right: 20,
            bottom: _selectedIncident != null ? 220 : 20,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'location',
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition, _initialZoom));
                  },
                  backgroundColor: const Color(0xFFFFFFFF),
                  child: const Icon(Icons.my_location, color: Color(0xFF2C5282)),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                  backgroundColor: const Color(0xFFFFFFFF),
                  child: const Icon(Icons.add, color: Color(0xFF2C5282)),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
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