import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:radar_dashboard/components/involved_barangay.dart';
import 'package:radar_dashboard/components/report_table.dart';
import 'package:radar_dashboard/components/map_monitoring.dart';
import 'package:radar_dashboard/components/weather_monitoring.dart';
import 'package:radar_dashboard/components/monthly_incident_report.dart';
import 'package:radar_dashboard/login/admin/admin_panel_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const DashboardScreen({
    super.key,
    required this.onMenuPressed,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTimeRange? _dateRange;
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, Map<String, dynamic>> _incidentsMap = {};
  bool _isLoading = true;
  StreamSubscription? _incidentsSubscription;
  StreamSubscription? _statusUpdatesSubscription;
  int _updateCounter = 0; // Counter to force widget rebuilds

  @override
  void initState() {
    super.initState();
    _initializeRealTimeUpdates();
  }

  @override
  void dispose() {
    _incidentsSubscription?.cancel();
    _statusUpdatesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeRealTimeUpdates() async {
    await _loadInitialIncidents();
    _setupRealTimeSubscriptions();
  }

  Future<void> _loadInitialIncidents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('incidents')
          .select('*')
          .order('timestamp', ascending: false);

      setState(() {
        _incidentsMap.clear();
        for (final incident in response) {
          final id = incident['id'].toString();
          _incidentsMap[id] = Map<String, dynamic>.from(incident);
        }
        _isLoading = false;
        _updateCounter++; // Increment counter on initial load
      });
      debugPrint('✅ Loaded ${_incidentsMap.length} initial incidents');
    } catch (e) {
      debugPrint('❌ Error loading initial incidents: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupRealTimeSubscriptions() {
    _setupIncidentsSubscription();
    _setupStatusUpdatesSubscription();
  }

  void _setupIncidentsSubscription() {
    _incidentsSubscription?.cancel();
    
    _incidentsSubscription = _supabase
        .from('incidents')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .handleError((error) {
      debugPrint('❌ Dashboard incidents stream error: $error');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _setupIncidentsSubscription();
      });
    }).listen(_handleIncidentsUpdate);

    debugPrint('🎯 Dashboard real-time incidents listener started');
  }

  void _setupStatusUpdatesSubscription() {
    _statusUpdatesSubscription?.cancel();
    
    _statusUpdatesSubscription = _supabase
        .from('incident_status_updates')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .handleError((error) {
      debugPrint('❌ Dashboard status updates stream error: $error');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _setupStatusUpdatesSubscription();
      });
    }).listen(_handleStatusUpdates);

    debugPrint('🎯 Dashboard real-time status updates listener started');
  }

  void _handleIncidentsUpdate(List<Map<String, dynamic>> incidents) {
    debugPrint('🔄 Dashboard received ${incidents.length} incidents from stream');
    
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
            debugPrint('➕ Dashboard: NEW incident - $id');
          }
          break;
        case 'UPDATE':
          if (newData != null) {
            _incidentsMap[id] = {
              ..._incidentsMap[id] ?? {},
              ...newData,
            };
            hasChanges = true;
            debugPrint('✏️ Dashboard: UPDATED incident - $id');
          }
          break;
        case 'DELETE':
          if (oldData != null) {
            _incidentsMap.remove(id);
            hasChanges = true;
            debugPrint('🗑️ Dashboard: DELETED incident - $id');
          }
          break;
        default:
          // Initial data or full refresh
          _incidentsMap[id] = incident;
          hasChanges = true;
      }
    }

    if (hasChanges && mounted) {
      setState(() {
        _updateCounter++; // Force rebuild of all widgets
      });
      debugPrint('📊 Dashboard total incidents in map: ${_incidentsMap.length}, Update counter: $_updateCounter');
    }
  }

  void _handleStatusUpdates(List<Map<String, dynamic>> statusUpdates) {
    debugPrint('🔄 Dashboard received ${statusUpdates.length} status updates from stream');
    
    bool hasChanges = false;
    
    for (final update in statusUpdates) {
      final eventType = update['type'] as String?;
      final newData = update['new'] as Map<String, dynamic>?;
      
      if (eventType == 'INSERT' && newData != null) {
        final incidentId = newData['incident_id'].toString();
        final status = newData['status'].toString();
        final timestamp = newData['created_at'] as String?;
        
        if (_incidentsMap.containsKey(incidentId)) {
          // Update the incident with latest status
          _incidentsMap[incidentId] = {
            ..._incidentsMap[incidentId]!,
            'latest_status': status,
            'status_updated_at': timestamp,
          };
          hasChanges = true;
          debugPrint('🔄 Dashboard status updated for incident $incidentId: $status');
        }
      }
    }
    
    if (hasChanges && mounted) {
      setState(() {
        _updateCounter++;
      });
    }
  }

  List<Map<String, dynamic>> get _allIncidents => _incidentsMap.values.toList();

  List<Map<String, dynamic>> _getFilteredIncidents() {
    if (_incidentsMap.isEmpty) return [];

    final now = DateTime.now();
    DateTime start, end;

    if (_dateRange != null) {
      // Use selected date range - show ALL incidents including resolved
      start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23, 59, 59, 999,
      );
    } else {
      // Default to today (from 12:00 AM to 11:59:59 PM)
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    }

    // First filter by date
    final dateFiltered = _allIncidents.where((incident) {
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
    final statusFiltered = _dateRange == null 
        ? dateFiltered.where((incident) {
            // In Today view: filter out resolved and declined incidents
            final status = (incident['latest_status'] ?? incident['status'] ?? 'pending').toString().toLowerCase();
            return status != 'resolved' && status != 'declined';
          }).toList()
        : dateFiltered; // When date range is selected: show ALL statuses

    debugPrint('📋 Dashboard filtered ${_allIncidents.length} → ${statusFiltered.length} incidents');
    debugPrint('📅 Date range: ${_dateRange != null ? "Custom" : "Today"} - Status filter: ${_dateRange == null ? "Active only" : "All statuses"}');

    return statusFiltered;
  }

  void _updateDateRange(DateTimeRange? newDateRange) {
    debugPrint('📅 Date range updated: $newDateRange');
    setState(() {
      _dateRange = newDateRange;
      _updateCounter++; // Force rebuild when date range changes
    });
  }

  void _refreshData() {
    debugPrint('🔄 Manual refresh triggered');
    _loadInitialIncidents();
  }

  @override
  Widget build(BuildContext context) {
    final filteredIncidents = _getFilteredIncidents();
    
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildDashboardBody(context, filteredIncidents),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: widget.onMenuPressed,
      ),
      title: const Center(
        child: Text('EMERGENCY RESPONSE DASHBOARD'),
      ),
      backgroundColor: const Color(0xFF2C5282),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      actions: [
        _buildAdminPanelButton(),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Refresh Data',
          onPressed: _refreshData,
        ),
      ],
    );
  }

  Widget _buildAdminPanelButton() {
    return FutureBuilder<String>(
      future: _getUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data != 'admin') {
          return const SizedBox.shrink();
        }

        return IconButton(
          icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
          tooltip: 'Admin Panel',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
            );
          },
        );
      },
    );
  }

  Future<String> _getUserRole() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 'user';

      final response = await _supabase
          .from('dashboard_users')
          .select('role')
          .eq('id', user.id)
          .single()
          .timeout(const Duration(seconds: 5));

      return response['role'] as String? ?? 'user';
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return 'user';
    }
  }

  Widget _buildDashboardBody(BuildContext context, List<Map<String, dynamic>> filteredIncidents) {
    // Use the update counter in the key to force rebuild of the entire dashboard
    return KeyedSubtree(
      key: ValueKey('dashboard_body_$_updateCounter'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopSection(context, filteredIncidents),
                const SizedBox(height: 24),
                _buildMetricsSection(context, filteredIncidents),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context, List<Map<String, dynamic>> filteredIncidents) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;

        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildEmergencyStats(context, filteredIncidents),
                        const SizedBox(height: 16),
                        ReportTableScreen(
                          key: ValueKey('report_table_${filteredIncidents.length}_$_updateCounter'),
                          dateRange: _dateRange,
                          onDateRangeChanged: _updateDateRange,
                          incidents: filteredIncidents,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: MapMonitoring(
                      key: ValueKey('map_${filteredIncidents.length}_$_updateCounter'),
                      dateRange: _dateRange,
                      onDateRangeChanged: _updateDateRange,
                      incidents: filteredIncidents,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildEmergencyStats(context, filteredIncidents),
                  const SizedBox(height: 16),
                  ReportTableScreen(
                    key: ValueKey('report_table_${filteredIncidents.length}_$_updateCounter'),
                    dateRange: _dateRange,
                    onDateRangeChanged: _updateDateRange,
                    incidents: filteredIncidents,
                  ),
                  const SizedBox(height: 16),
                  MapMonitoring(
                    key: ValueKey('map_${filteredIncidents.length}_$_updateCounter'),
                    dateRange: _dateRange,
                    onDateRangeChanged: _updateDateRange,
                    incidents: filteredIncidents,
                  ),
                ],
              );
      },
    );
  }

  Widget _buildEmergencyStats(BuildContext context, List<Map<String, dynamic>> filteredIncidents) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: IncidentStatsWidget(
          key: ValueKey('stats_${filteredIncidents.length}_$_updateCounter'),
          dateRange: _dateRange,
          incidents: filteredIncidents,
        ),
      ),
    );
  }

  Widget _buildMetricsSection(BuildContext context, List<Map<String, dynamic>> filteredIncidents) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: isWide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: MonthlyIncidentReport(
                            key: ValueKey('monthly_${_allIncidents.length}_$_updateCounter'),
                            incidents: _allIncidents,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InvolvedBarangays(
                            key: ValueKey('barangay_${filteredIncidents.length}_$_updateCounter'),
                            dateRange: _dateRange,
                            incidents: filteredIncidents,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(child: WeatherMonitoring()),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      MonthlyIncidentReport(
                        key: ValueKey('monthly_${_allIncidents.length}_$_updateCounter'),
                        incidents: _allIncidents,
                      ),
                      const SizedBox(height: 16),
                      InvolvedBarangays(
                        key: ValueKey('barangay_${filteredIncidents.length}_$_updateCounter'),
                        dateRange: _dateRange,
                        incidents: filteredIncidents,
                      ),
                      const SizedBox(height: 16),
                      const WeatherMonitoring(),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class IncidentStatsWidget extends StatefulWidget {
  final DateTimeRange? dateRange;
  final List<Map<String, dynamic>> incidents;

  const IncidentStatsWidget({
    super.key, 
    this.dateRange, 
    required this.incidents
  });

  @override
  State<IncidentStatsWidget> createState() => _IncidentStatsWidgetState();
}

class _IncidentStatsWidgetState extends State<IncidentStatsWidget> {
  final List<IncidentStat> _stats = const [
    IncidentStat(
      icon: Icons.fireplace_outlined,
      label: 'Fire',
      type: 'fire',
      color: Colors.deepOrange,
    ),
    IncidentStat(
      icon: Icons.car_crash_outlined,
      label: 'Accidents',
      type: 'accident',
      color: Colors.orange,
    ),
    IncidentStat(
      icon: Icons.flood_outlined,
      label: 'Flood',
      type: 'flood',
      color: Colors.blue,
    ),
    IncidentStat(
      icon: Icons.warning_outlined,
      label: 'Other',
      type: 'other',
      color: Colors.red,
    ),
    IncidentStat(
      icon: Icons.list_alt,
      label: 'Total',
      type: 'Total',
      color: Colors.purple,
      isTotal: true,
    ),
  ];

  @override
  void didUpdateWidget(IncidentStatsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incidents != widget.incidents) {
      debugPrint('📊 IncidentStatsWidget: Received ${widget.incidents.length} incidents');
    }
  }

  int _getIncidentCount(IncidentStat stat) {
    if (stat.isTotal) {
      return widget.incidents.length;
    } else if (stat.type == 'other') {
      return widget.incidents.where((incident) {
        final type = incident['incident_type']?.toString().toLowerCase();
        return type != 'fire' && type != 'flood' && type != 'accident' && type != null && type.isNotEmpty;
      }).length;
    } else {
      return widget.incidents
          .where((incident) {
            final incidentType = incident['incident_type']?.toString().toLowerCase();
            return incidentType == stat.type.toLowerCase();
          })
          .length;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📊 IncidentStatsWidget building with ${widget.incidents.length} incidents');
    
    return Column(
      children: [
        // Date range indicator
        if (widget.dateRange != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.green[700]),
                const SizedBox(width: 6),
                Text(
                  'Showing all incidents including resolved',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            
            return isWide
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _stats.map((stat) {
                      final count = _getIncidentCount(stat);
                      return Expanded(
                        child: IncidentStatItem(stat: stat, count: count),
                      );
                    }).toList(),
                  )
                : Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 16,
                    runSpacing: 16,
                    children: _stats.map((stat) {
                      final count = _getIncidentCount(stat);
                      return SizedBox(
                        width: 100,
                        child: IncidentStatItem(stat: stat, count: count),
                      );
                    }).toList(),
                  );
          },
        ),
      ],
    );
  }
}

class IncidentStat {
  final IconData icon;
  final String label;
  final String type;
  final Color color;
  final bool isTotal;

  const IncidentStat({
    required this.icon,
    required this.label,
    required this.type,
    required this.color,
    this.isTotal = false,
  });
}

class IncidentStatItem extends StatelessWidget {
  final IncidentStat stat;
  final int count;

  const IncidentStatItem({
    super.key,
    required this.stat,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      constraints: const BoxConstraints(minWidth: 80, maxWidth: 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: stat.color.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(
                color: stat.color.withAlpha(76),
                width: 2,
              ),
            ),
            child: Icon(
              stat.icon,
              size: 24,
              color: stat.color,
            ),
          ),
          const SizedBox(height: 12),
          // Count
          Text(
            _formatCount(count),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Label
          Text(
            stat.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(178),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}