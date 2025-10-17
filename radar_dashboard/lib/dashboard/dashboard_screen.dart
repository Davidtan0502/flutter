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

  void _updateDateRange(DateTimeRange? newDateRange) {
    debugPrint('Date range updated: $newDateRange');
    setState(() {
      _dateRange = newDateRange;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildDashboardBody(context),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: widget.onMenuPressed,
      ),
      title: const Text('EMERGENCY RESPONSE DASHBOARD'),
      centerTitle: true,
      backgroundColor: const Color(0xFF2C5282),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      actions: [
        _buildAdminPanelButton(),
      ],
    );
  }

  Widget _buildAdminPanelButton() {
    return FutureBuilder<String>(
      future: _getUserRole(),
      builder: (context, snapshot) {
        // Show loading indicator while fetching role
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

        // Hide button if not admin or error
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
          .from('dashboard_users') // Fixed table name
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

  Widget _buildDashboardBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopSection(context),
              const SizedBox(height: 24),
              _buildMetricsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
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
                        _buildEmergencyStats(context),
                        const SizedBox(height: 16),
                        ReportTableScreen(
                          dateRange: _dateRange,
                          onDateRangeChanged: _updateDateRange,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: MapMonitoring(dateRange: _dateRange),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildEmergencyStats(context),
                  const SizedBox(height: 16),
                  ReportTableScreen(
                    dateRange: _dateRange,
                    onDateRangeChanged: _updateDateRange,
                  ),
                  const SizedBox(height: 16),
                  MapMonitoring(dateRange: _dateRange),
                ],
              );
      },
    );
  }

  Widget _buildEmergencyStats(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: IncidentStatsWidget(dateRange: _dateRange),
      ),
    );
  }

  Widget _buildMetricsSection(BuildContext context) {
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
                        Expanded(child: MonthlyIncidentReport()),
                        const SizedBox(width: 16),
                        Expanded(child: InvolvedBarangays(dateRange: _dateRange)),
                        const SizedBox(width: 16),
                        const Expanded(child: WeatherMonitoring()),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      MonthlyIncidentReport(),
                      const SizedBox(height: 16),
                      InvolvedBarangays(dateRange: _dateRange),
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

  const IncidentStatsWidget({super.key, this.dateRange});

  @override
  State<IncidentStatsWidget> createState() => _IncidentStatsWidgetState();
}

class _IncidentStatsWidgetState extends State<IncidentStatsWidget> {
  final SupabaseClient _supabase = Supabase.instance.client;
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

  List<Map<String, dynamic>> _incidents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  @override
  void didUpdateWidget(IncidentStatsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateRange != widget.dateRange) {
      _loadIncidents();
    }
  }

  Future<void> _loadIncidents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var query = _supabase
          .from('incidents')
          .select('id, incident_type, timestamp, status');

      // Apply date range filter
      if (widget.dateRange != null) {
        final start = DateTime(
          widget.dateRange!.start.year,
          widget.dateRange!.start.month,
          widget.dateRange!.start.day,
        );
        final end = DateTime(
          widget.dateRange!.end.year,
          widget.dateRange!.end.month,
          widget.dateRange!.end.day,
          23,
          59,
          59,
          999,
        );

        query = query
            .gte('timestamp', start.toIso8601String())
            .lte('timestamp', end.toIso8601String());
      } else {
        // Default: today's incidents
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

        query = query
            .gte('timestamp', startOfDay.toIso8601String())
            .lte('timestamp', endOfDay.toIso8601String());
      }

      final data = await query.timeout(const Duration(seconds: 10));
      
      debugPrint('Fetched ${data.length} incidents for stats');
      if (data.isNotEmpty) {
        debugPrint('First incident: ${data.first}');
      }

      setState(() {
        _incidents = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading incidents for stats: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int _getIncidentCount(IncidentStat stat) {
    if (stat.isTotal) {
      return _incidents.length;
    } else if (stat.type == 'other') {
      return _incidents.where((incident) {
        final type = incident['incident_type']?.toString().toLowerCase();
        return type != 'fire' && type != 'flood' && type != 'accident' && type != null && type.isNotEmpty;
      }).length;
    } else {
      return _incidents
          .where((incident) {
            final incidentType = incident['incident_type']?.toString().toLowerCase();
            return incidentType == stat.type.toLowerCase();
          })
          .length;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load incident data',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _loadIncidents,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
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
              color: stat.color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: stat.color.withOpacity(0.3),
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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