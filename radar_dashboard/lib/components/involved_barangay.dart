import 'dart:async' show StreamSubscription;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:radar_dashboard/components/section_header.dart';

class InvolvedBarangays extends StatefulWidget {
  final DateTimeRange? dateRange;
  final List<Map<String, dynamic>> incidents;

  const InvolvedBarangays({
    super.key, 
    this.dateRange, 
    required this.incidents
  });

  @override
  State<InvolvedBarangays> createState() => _InvolvedBarangaysState();
}

class _InvolvedBarangaysState extends State<InvolvedBarangays> {
  final Map<String, Map<String, dynamic>> _incidentsMap = {};
  StreamSubscription? _incidentsSubscription;
  StreamSubscription? _statusUpdatesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupRealTimeSubscriptions();
  }

  @override
  void didUpdateWidget(InvolvedBarangays oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incidents != widget.incidents) {
      _syncWithParentData();
    }
  }

  void _initializeData() {
    // Start with the incidents provided by parent
    for (final incident in widget.incidents) {
      final id = incident['id'].toString();
      _incidentsMap[id] = incident;
    }
    debugPrint('🎯 InvolvedBarangays initialized with ${_incidentsMap.length} incidents');
  }

  void _syncWithParentData() {
    // Merge parent data with our real-time updates
    for (final incident in widget.incidents) {
      final id = incident['id'].toString();
      if (!_incidentsMap.containsKey(id)) {
        _incidentsMap[id] = incident;
      }
    }
    debugPrint('🔄 InvolvedBarangays synced with parent - total incidents: ${_incidentsMap.length}');
    
    if (mounted) {
      setState(() {});
    }
  }

  void _setupRealTimeSubscriptions() {
    _setupIncidentsSubscription();
    _setupStatusUpdatesSubscription();
  }

  void _setupIncidentsSubscription() {
    _incidentsSubscription?.cancel();
    
    _incidentsSubscription = Supabase.instance.client
        .from('incidents')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .handleError((error) {
      debugPrint('❌ InvolvedBarangays incidents stream error: $error');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _setupIncidentsSubscription();
      });
    }).listen(_handleIncidentsUpdate);

    debugPrint('🎯 InvolvedBarangays real-time listener started');
  }

  void _setupStatusUpdatesSubscription() {
    _statusUpdatesSubscription?.cancel();
    
    _statusUpdatesSubscription = Supabase.instance.client
        .from('incident_status_updates')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .handleError((error) {
      debugPrint('❌ InvolvedBarangays status updates stream error: $error');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _setupStatusUpdatesSubscription();
      });
    }).listen(_handleStatusUpdates);
  }

  void _handleIncidentsUpdate(List<Map<String, dynamic>> incidents) {
    debugPrint('🔄 InvolvedBarangays received ${incidents.length} incidents from stream');
    
    bool hasChanges = false;
    
    for (final incident in incidents) {
      final id = incident['id'].toString();
      final eventType = incident['type'] as String?;
      final newData = incident['new'] as Map<String, dynamic>?;
      final oldData = incident['old'] as Map<String, dynamic>?;

      switch (eventType) {
        case 'INSERT':
          if (newData != null) {
            _incidentsMap[id] = newData;
            hasChanges = true;
            debugPrint('➕ InvolvedBarangays: NEW incident - $id');
          }
          break;
        case 'UPDATE':
          if (newData != null) {
            _incidentsMap[id] = {
              ..._incidentsMap[id] ?? {},
              ...newData,
            };
            hasChanges = true;
            debugPrint('✏️ InvolvedBarangays: UPDATED incident - $id');
          }
          break;
        case 'DELETE':
          if (oldData != null) {
            _incidentsMap.remove(id);
            hasChanges = true;
            debugPrint('🗑️ InvolvedBarangays: DELETED incident - $id');
          }
          break;
        default:
          // Initial data or full refresh
          _incidentsMap[id] = incident;
          hasChanges = true;
      }
    }

    if (hasChanges && mounted) {
      setState(() {});
      debugPrint('📊 InvolvedBarangays total incidents in map: ${_incidentsMap.length}');
    }
  }

  void _handleStatusUpdates(List<Map<String, dynamic>> statusUpdates) {
    debugPrint('🔄 InvolvedBarangays received ${statusUpdates.length} status updates from stream');
    
    bool hasChanges = false;
    
    for (final update in statusUpdates) {
      final eventType = update['type'] as String?;
      final newData = update['new'] as Map<String, dynamic>?;
      
      if (eventType == 'INSERT' && newData != null) {
        final incidentId = newData['incident_id'].toString();
        final status = newData['status'].toString();
        
        if (_incidentsMap.containsKey(incidentId)) {
          // Update the incident with latest status
          _incidentsMap[incidentId] = {
            ..._incidentsMap[incidentId]!,
            'latest_status': status,
          };
          hasChanges = true;
          debugPrint('🔄 InvolvedBarangays status updated for incident $incidentId: $status');
        }
      }
    }
    
    if (hasChanges && mounted) {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> get _allIncidents => _incidentsMap.values.toList();

  @override
  void dispose() {
    _incidentsSubscription?.cancel();
    _statusUpdatesSubscription?.cancel();
    super.dispose();
    debugPrint('🔴 InvolvedBarangays disposed');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _BarangayChartContent(
          dateRange: widget.dateRange,
          incidents: _allIncidents,
        ),
      ),
    );
  }
}

class _BarangayChartContent extends StatelessWidget {
  final DateTimeRange? dateRange;
  final List<Map<String, dynamic>> incidents;

  const _BarangayChartContent({this.dateRange, required this.incidents});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.location_on_outlined,
          title: 'INVOLVED LOCATIONS', 
          subtitle: 'Manila Barangays & Other Cities',
        ),
        const SizedBox(height: 20),
        _BarangayDataLoader(
          dateRange: dateRange,
          incidents: incidents,
        ),
      ],
    );
  }
}

class _BarangayDataLoader extends StatelessWidget {
  final DateTimeRange? dateRange;
  final List<Map<String, dynamic>> incidents;

  const _BarangayDataLoader({this.dateRange, required this.incidents});

  @override
  Widget build(BuildContext context) {
    // Apply date filtering to the incidents
    final filteredIncidents = _filterIncidentsByDateRange(incidents);

    if (filteredIncidents.isEmpty) {
      return _ErrorDisplay(
        message: dateRange == null 
          ? 'No incident data available for today' 
          : 'No incidents in selected date range'
      );
    }

    final dataProcessor = BarangayDataProcessor(filteredIncidents);
    final chartData = dataProcessor.processData();

    if (chartData.topBarangays.isEmpty && chartData.othersCount == 0) {
      return _ErrorDisplay(
        message: dateRange == null 
          ? 'No incident data available for today' 
          : 'No incidents in selected date range'
      );
    }

    return _BarangayChartDisplay(data: chartData, dateRange: dateRange);
  }

  List<Map<String, dynamic>> _filterIncidentsByDateRange(List<Map<String, dynamic>> incidents) {
    final now = DateTime.now();
    DateTime start, end;

    if (dateRange != null) {
      // Use selected date range - show ALL incidents including resolved
      start = DateTime(
        dateRange!.start.year,
        dateRange!.start.month,
        dateRange!.start.day,
      );
      end = DateTime(
        dateRange!.end.year,
        dateRange!.end.month,
        dateRange!.end.day,
        23, 59, 59, 999,
      );
    } else {
      // Default to today - filter out resolved and declined incidents
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    }

    final dateFiltered = incidents.where((incident) {
      final timestamp = incident['timestamp'];
      if (timestamp == null) return false;
      
      try {
        final incidentDate = DateTime.parse(timestamp);
        return incidentDate.isAfter(start.subtract(const Duration(seconds: 1))) && 
               incidentDate.isBefore(end.add(const Duration(seconds: 1)));
      } catch (e) {
        return false;
      }
    }).toList();

    // Apply status filtering ONLY when no date range is selected (Today view)
    final statusFiltered = dateRange == null 
        ? dateFiltered.where((incident) {
            // In Today view: filter out resolved and declined incidents
            final status = (incident['latest_status'] ?? incident['status'] ?? 'pending').toString().toLowerCase();
            return status != 'resolved' && status != 'declined';
          }).toList()
        : dateFiltered; // When date range is selected: show ALL statuses

    debugPrint('🔍 InvolvedBarangays filtered ${incidents.length} → ${statusFiltered.length} incidents');
    debugPrint('📅 Date range: ${dateRange != null ? "Custom" : "Today"} - Status filter: ${dateRange == null ? "Active only" : "All statuses"}');

    return statusFiltered;
  }
}

// ... REST OF THE CODE REMAINS THE SAME (BarangayDataProcessor, LocationExtractionResult, BarangayChartData, _BarangayChartDisplay, _LegendItem, _ErrorDisplay classes)
class BarangayDataProcessor {
  final List<Map<String, dynamic>> documents;

  BarangayDataProcessor(this.documents);

  BarangayChartData processData() {
    final locationCounts = <String, int>{};
    final manilaBarangayCounts = <String, int>{};
    
    for (final doc in documents) {
      final address = doc['address'] as String? ?? 'Unknown';
      final extractedLocation = _extractLocationFromAddress(address);
      
      locationCounts[extractedLocation.locationName] = 
          (locationCounts[extractedLocation.locationName] ?? 0) + 1;
      
      // Also track Manila barangays separately for the detailed list
      if (extractedLocation.isManila && extractedLocation.barangayName != 'Unknown') {
        manilaBarangayCounts[extractedLocation.barangayName] = 
            (manilaBarangayCounts[extractedLocation.barangayName] ?? 0) + 1;
      }
    }

    debugPrint('Total incidents: ${documents.length}');
    debugPrint('Unique locations: ${locationCounts.length}');

    final sortedLocations = locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topLocations = sortedLocations.take(5).toList();
    final othersCount = sortedLocations.length > 5
        ? sortedLocations.sublist(5).fold(0, (sum, entry) => sum + entry.value)
        : 0;

    // Sort Manila barangays by count
    final sortedManilaBarangays = manilaBarangayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    debugPrint('Top locations: $topLocations');
    debugPrint('Others count: $othersCount');

    return BarangayChartData(
      topBarangays: topLocations,
      othersCount: othersCount,
      allManilaBarangays: sortedManilaBarangays,
    );
  }

  LocationExtractionResult _extractLocationFromAddress(String address) {
    try {
      if (address == 'Unknown' || address.isEmpty) {
        return LocationExtractionResult('Unknown', 'Unknown', false);
      }

      final lowerAddress = address.toLowerCase();
      
      // Check if it's in Manila
      if (_isManilaAddress(lowerAddress)) {
        // For Manila, extract barangay/district
        final barangayName = _extractManilaBarangay(address, lowerAddress);
        return LocationExtractionResult('Manila - $barangayName', barangayName, true);
      } else {
        // For outside Manila, extract city
        final cityName = _extractCity(lowerAddress);
        return LocationExtractionResult(cityName, 'N/A', false);
      }
      
    } catch (e) {
      debugPrint('Error extracting location from address: $address, error: $e');
      return LocationExtractionResult('Unknown', 'Unknown', false);
    }
  }

  bool _isManilaAddress(String lowerAddress) {
    // Manila city indicators
    final manilaIndicators = [
      'manila',
      'city of manila',
      'metro manila',
      'ncr',
      'national capital region'
    ];
    
    // Check if it's Manila
    for (final indicator in manilaIndicators) {
      if (lowerAddress.contains(indicator)) {
        return true;
      }
    }
    
    // Check for Manila districts
    for (final district in _manilaDistricts) {
      if (lowerAddress.contains(district.toLowerCase())) {
        return true;
      }
    }
    
    return false;
  }

  String _extractManilaBarangay(String address, String lowerAddress) {
    // Try to extract using barangay indicators first
    final barangayIndicators = ['barangay', 'brgy.', 'brgy', 'bgy.', 'bgy'];
    
    for (final indicator in barangayIndicators) {
      if (lowerAddress.contains(indicator)) {
        final startIndex = lowerAddress.indexOf(indicator) + indicator.length;
        var extracted = address.substring(startIndex).trim();
        extracted = _cleanBarangayName(extracted);
        
        if (extracted.isNotEmpty && extracted != 'Unknown') {
          return extracted;
        }
      }
    }
    
    // Try to match known Manila districts
    for (final district in _manilaDistricts) {
      if (lowerAddress.contains(district.toLowerCase())) {
        return district;
      }
    }
    
    // Fallback for Manila addresses
    return 'Unknown Area';
  }

  String _extractCity(String lowerAddress) {
    // List of Metro Manila cities and other common Philippine cities
    final cities = [
      'quezon city', 'qc',
      'makati',
      'mandaluyong',
      'pasig',
      'pasay', 
      'taguig',
      'paranaque', 'parañaque',
      'las pinas', 'las piñas',
      'muntinlupa',
      'marikina',
      'valenzuela',
      'caloocan',
      'malabon',
      'navotas',
      'san juan',
      'pateros',
      'mandaluyong',
      // Other major cities
      'cebu city', 'cebu',
      'davao city', 'davao',
      'baguio city', 'baguio',
      'iloilo city', 'iloilo',
      'bacolod city', 'bacolod',
      'cagayan de oro', 'cdo',
      'zamboanga city', 'zamboanga',
      'general santos', 'gensan',
      'taguig city',
      'antipolo city', 'antipolo',
      'dasmarinas', 'dasma',
      'cavite city', 'cavite'
    ];

    // Try to find city name
    for (final city in cities) {
      if (lowerAddress.contains(city)) {
        // Format the city name properly
        return _formatCityName(city);
      }
    }

    // If no city found, try to extract from common patterns
    final cityRegex = RegExp(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*(?:city|City)\b');
    final match = cityRegex.firstMatch(lowerAddress);
    if (match != null) {
      return _formatCityName(match.group(1)!);
    }

    return 'Other Location';
  }

  String _formatCityName(String city) {
    // Convert to title case and remove duplicates
    final formatted = city.split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
    
    // Remove "City" if it's already in the name to avoid duplication
    if (formatted.toLowerCase().contains('city')) {
      return formatted;
    }
    return '$formatted City';
  }

  String _cleanBarangayName(String barangay) {
    var cleaned = barangay.split(RegExp(r'[,\-–—()\[\]{}]')).first.trim();
    
    // Remove numbers that might be street numbers
    cleaned = cleaned.replaceAll(RegExp(r'^\d+\s*'), '').trim();
    
    // Remove common street indicators
    final streetIndicators = [
      'st.', 'street', 'ave', 'avenue', 'blvd', 'boulevard', 'rd', 'road',
      'drive', 'dr', 'highway', 'hwy', 'circle', 'circ', 'court', 'ct',
      'ext.', 'extension'
    ];
    
    for (final indicator in streetIndicators) {
      final indicatorRegex = RegExp('\\b${indicator}\\b', caseSensitive: false);
      cleaned = cleaned.replaceAll(indicatorRegex, '').trim();
    }
    
    if (cleaned.isEmpty || cleaned.length < 2) {
      return 'Unknown';
    }
    
    return cleaned;
  }

  // Manila Administrative Districts (16 districts)
  final List<String> _manilaDistricts = [
    'Binondo',
    'Ermita', 
    'Intramuros',
    'Malate',
    'Paco',
    'Pandacan',
    'Port Area',
    'Quiapo',
    'Sampaloc',
    'San Andres',
    'San Miguel',
    'San Nicolas', 
    'Santa Ana',
    'Santa Cruz',
    'Santa Mesa',
    'Tondo'
  ];
}

class LocationExtractionResult {
  final String locationName;
  final String barangayName;
  final bool isManila;

  LocationExtractionResult(this.locationName, this.barangayName, this.isManila);
}

class BarangayChartData {
  final List<MapEntry<String, int>> topBarangays;
  final int othersCount;
  final List<MapEntry<String, int>> allManilaBarangays;

  BarangayChartData({
    required this.topBarangays,
    required this.othersCount,
    required this.allManilaBarangays,
  });
}

class _BarangayChartDisplay extends StatelessWidget {
  final BarangayChartData data;
  final DateTimeRange? dateRange;

  const _BarangayChartDisplay({required this.data, this.dateRange});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            _buildChartData(),
            duration: const Duration(milliseconds: 500),
          ),
        ),
        const SizedBox(height: 16),
        _buildChartLegend(),
        const SizedBox(height: 20),
        _buildManilaBarangaysList(),
      ],
    );
  }

  PieChartData _buildChartData() {
    final colors = _chartColors;
    final sections = <PieChartSectionData>[];
    
    // Add top locations
    for (int i = 0; i < data.topBarangays.length; i++) {
      sections.add(
        PieChartSectionData(
          value: data.topBarangays[i].value.toDouble(),
          color: colors[i % colors.length],
          title: '${data.topBarangays[i].value}',
          radius: 25,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
    }
    
    // Add "Others" section if needed
    if (data.othersCount > 0) {
      sections.add(
        PieChartSectionData(
          value: data.othersCount.toDouble(),
          color: Colors.grey[400]!,
          title: '${data.othersCount}',
          radius: 20,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
    }

    return PieChartData(
      sectionsSpace: 0,
      centerSpaceRadius: 60,
      sections: sections,
    );
  }

  Widget _buildChartLegend() {
    final colors = _chartColors;
    
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (int i = 0; i < data.topBarangays.length; i++)
          _LegendItem(
            color: colors[i % colors.length],
            text: '${data.topBarangays[i].key} (${data.topBarangays[i].value})',
          ),
        if (data.othersCount > 0)
          _LegendItem(
            color: Colors.grey[400]!,
            text: 'Others (${data.othersCount})',
          ),
      ],
    );
  }

  Widget _buildManilaBarangaysList() {
    final totalIncidents = data.allManilaBarangays.fold(0, (sum, entry) => sum + entry.value);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MANILA BARANGAYS BREAKDOWN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total: $totalIncidents',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data.allManilaBarangays.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'No Manila barangay data available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: data.allManilaBarangays.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getBarangayColor(entry.value),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey[700],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getBarangayColor(entry.value).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getBarangayColor(entry.value),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getBarangayColor(int count) {
    if (count >= 10) return Colors.red[400]!;
    if (count >= 5) return Colors.orange[400]!;
    if (count >= 3) return Colors.amber[600]!;
    if (count >= 1) return Colors.green[400]!;
    return Colors.grey[400]!;
  }

  List<Color> get _chartColors => [
    Colors.blue[400]!,
    Colors.green[400]!,
    Colors.orange[400]!,
    Colors.purple[400]!,
    Colors.red[400]!,
    Colors.teal[400]!,
  ];
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.blueGrey[700],
          ),
        ),
      ],
    );
  }
}

class _ErrorDisplay extends StatelessWidget {
  final String message;

  const _ErrorDisplay({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}