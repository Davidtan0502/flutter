import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final FirebasePerformance _performance = FirebasePerformance.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Trace> _activeTraces = {};
  final List<Map<String, dynamic>> _metrics = [];

  bool _isInitialized = false;
  static const int _maxMetrics = 1000;
  static const int _batchLimit = 500;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _performance.setPerformanceCollectionEnabled(!kDebugMode);
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('PerformanceMonitor initialized (debug mode: disabled)');
      }
    } catch (e, stack) {
      debugPrint('[PerformanceMonitor] Init error: $e\n$stack');
    }
  }

  Future<void> startCustomTrace(String name) async {
    if (!_isInitialized) await initialize();
    if (kDebugMode) return;
    if (_activeTraces.containsKey(name)) return;

    try {
      final trace = _performance.newTrace(name);
      await trace.start();
      _activeTraces[name] = trace;

      _addMetric({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'event': 'trace_start',
        'name': name,
        'type': 'custom',
      });
    } catch (e) {
      debugPrint('[PerformanceMonitor] Error starting trace $name: $e');
    }
  }

  Future<void> stopCustomTrace(String name) async {
    if (kDebugMode) return;

    final trace = _activeTraces.remove(name);
    if (trace != null) {
      try {
        await trace.stop();
        _addMetric({
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'event': 'trace_stop',
          'name': name,
          'type': 'custom',
        });
      } catch (e) {
        debugPrint('[PerformanceMonitor] Error stopping trace $name: $e');
      }
    }
  }

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    if (!_isInitialized) await initialize();
    try {
      await _analytics.logEvent(name: name, parameters: _sanitizeParams(params));
      _addMetric({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'event': name,
        'params': _sanitizeParams(params),
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
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      await logEvent('screen_view', {
        'screen_name': screenName,
        'screen_class': screenClass ?? screenName,
        ...?additionalParams,
      });
    } catch (e) {
      debugPrint('[PerformanceMonitor] Error logging screen view: $e');
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
    final sanitized = Map<String, Object>.from(params);
    sanitized.removeWhere((k, v) => v == null);
    return sanitized.map((k, v) {
      final key = k.toString().substring(0, k.toString().length.clamp(0, 40));
      final value = v.toString().substring(0, v.toString().length.clamp(0, 100));
      return MapEntry(key, value);
    });
  }

  Future<void> uploadMetrics() async {
    if (_metrics.isEmpty) return;

    try {
      final chunks = List.generate(
        (_metrics.length / _batchLimit).ceil(),
        (i) => _metrics.skip(i * _batchLimit).take(_batchLimit).toList(),
      );

      for (final chunk in chunks) {
        final batch = _firestore.batch();
        final parent = _firestore
            .collection('performance_metrics')
            .doc(DateTime.now().toUtc().toIso8601String())
            .collection('events');

        for (final metric in chunk) {
          batch.set(parent.doc(), metric);
        }

        await batch.commit();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _metrics.clear();
    } catch (e) {
      debugPrint('[PerformanceMonitor] Error uploading metrics: $e');
    }
  }

  Future<void> dispose() async {
    for (final trace in _activeTraces.values) {
      try {
        await trace.stop();
      } catch (_) {}
    }
    _activeTraces.clear();
    await uploadMetrics();
  }
}
