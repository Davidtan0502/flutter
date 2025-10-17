import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, Map<String, dynamic>> _activeTraces = {};
  final List<Map<String, dynamic>> _metrics = [];

  bool _isInitialized = false;
  static const int _maxMetrics = 1000;
  static const int _batchLimit = 500;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('PerformanceMonitor initialized with Supabase');
      }
    } catch (e, stack) {
      debugPrint('[PerformanceMonitor] Init error: $e\n$stack');
    }
  }

  Future<void> startCustomTrace(String name) async {
    if (!_isInitialized) await initialize();
    if (_activeTraces.containsKey(name)) return;

    try {
      final traceData = {
        'name': name,
        'start_time': DateTime.now().toUtc().toIso8601String(),
        'type': 'custom',
      };
      _activeTraces[name] = traceData;

      _addMetric({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'event': 'trace_start',
        'name': name,
        'type': 'custom',
        'user_id': _supabase.auth.currentUser?.id,
      });
    } catch (e) {
      debugPrint('[PerformanceMonitor] Error starting trace $name: $e');
    }
  }

  Future<void> stopCustomTrace(String name) async {
    final trace = _activeTraces.remove(name);
    if (trace != null) {
      try {
        final duration = DateTime.now().difference(DateTime.parse(trace['start_time']));
        
        _addMetric({
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'event': 'trace_stop',
          'name': name,
          'type': 'custom',
          'duration_ms': duration.inMilliseconds,
          'user_id': _supabase.auth.currentUser?.id,
        });
      } catch (e) {
        debugPrint('[PerformanceMonitor] Error stopping trace $name: $e');
      }
    }
  }

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    if (!_isInitialized) await initialize();
    try {
      _addMetric({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'event': name,
        'params': _sanitizeParams(params),
        'user_id': _supabase.auth.currentUser?.id,
        'session_id': _supabase.auth.currentSession?.accessToken,
      });
    } catch (e) {
      debugPrint('[PerformanceMonitor] Error logging event $name: $e');
    }
  }

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? additionalParams,
  }) async {
    try {
      await logEvent('screen_view', {
        'screen_name': screenName,
        'screen_class': screenClass ?? screenName,
        ...?additionalParams,
      });
    } catch (e) {
      debugPrint('[PerformanceMonitor] Error logging screen view: $e');
    }
  }

  Future<void> logApiCall({
    required String endpoint,
    required String method,
    required int statusCode,
    required int durationMs,
    int? responseSize,
    String? error,
  }) async {
    try {
      _addMetric({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'event': 'api_call',
        'endpoint': endpoint,
        'method': method,
        'status_code': statusCode,
        'duration_ms': durationMs,
        'response_size': responseSize,
        'error': error,
        'user_id': _supabase.auth.currentUser?.id,
      });
    } catch (e) {
      debugPrint('[PerformanceMonitor] Error logging API call: $e');
    }
  }

  void _addMetric(Map<String, dynamic> metric) {
    _metrics.add(metric);
    if (_metrics.length > _maxMetrics) {
      _metrics.removeRange(0, _metrics.length - _maxMetrics);
    }
  }

  Map<String, Object>? _sanitizeParams(Map<String, Object>? params) {
    if (params == null) return null;
    final sanitized = <String, Object>{};
    params.forEach((key, value) {
      final sanitizedKey = key.toString().substring(0, key.toString().length.clamp(0, 40));
      final sanitizedValue = value.toString().substring(0, value.toString().length.clamp(0, 100));
      sanitized[sanitizedKey] = sanitizedValue;
    });
    return sanitized;
  }

  Future<void> uploadMetrics() async {
    if (_metrics.isEmpty) return;

    try {
      // Upload metrics to Supabase table
      final response = await _supabase
          .from('performance_metrics')
          .insert(_metrics);

      // In newer Supabase versions, errors are thrown as exceptions
      // So we don't need to check response.error

      _metrics.clear();
      debugPrint('[PerformanceMonitor] Successfully uploaded metrics');
    } catch (e) {
      debugPrint('[PerformanceMonitor] Error uploading metrics: $e');
      // Optionally implement retry logic here
    }
  }

  Future<void> uploadMetricsInBatches() async {
    if (_metrics.isEmpty) return;

    try {
      final chunks = <List<Map<String, dynamic>>>[];
      for (var i = 0; i < _metrics.length; i += _batchLimit) {
        final end = (i + _batchLimit < _metrics.length) ? i + _batchLimit : _metrics.length;
        chunks.add(_metrics.sublist(i, end));
      }

      for (final chunk in chunks) {
        await _supabase
            .from('performance_metrics')
            .insert(chunk);

        await Future.delayed(const Duration(milliseconds: 100));
      }

      _metrics.clear();
      debugPrint('[PerformanceMonitor] Successfully uploaded metrics in batches');
    } catch (e) {
      debugPrint('[PerformanceMonitor] Error uploading metrics in batches: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMetrics({
    DateTime? startDate,
    DateTime? endDate,
    String? eventType,
    int limit = 100,
  }) async {
    try {
      // Build query using string filters for date ranges
      String query = '''
        SELECT * FROM performance_metrics 
        WHERE 1=1
        ${startDate != null ? "AND timestamp >= '${startDate.toUtc().toIso8601String()}'" : ""}
        ${endDate != null ? "AND timestamp <= '${endDate.toUtc().toIso8601String()}'" : ""}
        ${eventType != null ? "AND event = '$eventType'" : ""}
        ORDER BY timestamp DESC 
        LIMIT $limit
      ''';

      var queryBuilder = _supabase
          .from('performance_metrics')
          .select();

      if (startDate != null) {
        queryBuilder = queryBuilder.gte('timestamp', startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        queryBuilder = queryBuilder.lte('timestamp', endDate.toUtc().toIso8601String());
      }
      if (eventType != null) {
        queryBuilder = queryBuilder.eq('event', eventType);
      }

      final response = await queryBuilder
          .order('timestamp', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[PerformanceMonitor] Error fetching metrics: $e');
      return [];
    }
  }

  // Alternative method using raw SQL if the above doesn't work
  Future<List<Map<String, dynamic>>> getMetricsRaw({
    DateTime? startDate,
    DateTime? endDate,
    String? eventType,
    int limit = 100,
  }) async {
    try {
      String query = '''
        SELECT * FROM performance_metrics 
        WHERE 1=1
        ${startDate != null ? "AND timestamp >= '${startDate.toUtc().toIso8601String()}'" : ""}
        ${endDate != null ? "AND timestamp <= '${endDate.toUtc().toIso8601String()}'" : ""}
        ${eventType != null ? "AND event = '$eventType'" : ""}
        ORDER BY timestamp DESC 
        LIMIT $limit
      ''';

      final response = await _supabase.rpc('exec_sql', params: {'query': query});
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[PerformanceMonitor] Error fetching metrics with raw SQL: $e');
      return [];
    }
  }

  Future<void> dispose() async {
    // Stop all active traces
    final tracesToStop = List<String>.from(_activeTraces.keys);
    for (final traceName in tracesToStop) {
      await stopCustomTrace(traceName);
    }
    
    // Upload remaining metrics
    await uploadMetrics();
  }
}