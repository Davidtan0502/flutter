// lib/services/incident_service.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncidentService {
  static final IncidentService _instance = IncidentService._internal();
  factory IncidentService() => _instance;
  IncidentService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final List<Map<String, dynamic>> _incidents = [];
  final StreamController<List<Map<String, dynamic>>> _incidentsController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();
  StreamSubscription? _subscription;

  List<Map<String, dynamic>> get incidents => List.from(_incidents);
  Stream<List<Map<String, dynamic>>> get incidentsStream => _incidentsController.stream;

  Future<void> initialize() async {
    await _loadInitialIncidents();
    _setupRealTimeSubscription();
  }

  Future<void> _loadInitialIncidents() async {
    try {
      final response = await _supabase
          .from('incidents')
          .select('*')
          .order('timestamp', ascending: false);

      _incidents.clear();
      _incidents.addAll(List<Map<String, dynamic>>.from(response));
      _incidentsController.add(List.from(_incidents));
      
      print('✅ Loaded ${_incidents.length} initial incidents');
    } catch (e) {
      print('❌ Error loading initial incidents: $e');
    }
  }

  void _setupRealTimeSubscription() {
    _subscription = _supabase
        .from('incidents')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> events) {
      _handleRealTimeUpdates(events);
    }, onError: (error) {
      print('❌ Real-time subscription error: $error');
      // Attempt to reconnect after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        _setupRealTimeSubscription();
      });
    });

    print('✅ Real-time subscription started');
  }

  void _handleRealTimeUpdates(List<Map<String, dynamic>> events) {
    print('🔄 Real-time update: ${events.length} events');
    
    bool hasChanges = false;

    for (final event in events) {
      final eventType = event['type'] as String?;
      final newData = event['new'] as Map<String, dynamic>?;
      final oldData = event['old'] as Map<String, dynamic>?;

      switch (eventType) {
        case 'INSERT':
          if (newData != null) {
            _incidents.insert(0, newData);
            hasChanges = true;
            print('➕ New incident: ${newData['id']}');
          }
          break;
        case 'UPDATE':
          if (newData != null) {
            final index = _incidents.indexWhere(
              (incident) => incident['id'] == newData['id'],
            );
            if (index != -1) {
              _incidents[index] = newData;
              hasChanges = true;
              print('✏️ Updated incident: ${newData['id']}');
            }
          }
          break;
        case 'DELETE':
          if (oldData != null) {
            _incidents.removeWhere(
              (incident) => incident['id'] == oldData['id'],
            );
            hasChanges = true;
            print('🗑️ Deleted incident: ${oldData['id']}');
          }
          break;
      }
    }

    if (hasChanges) {
      print('📊 Total incidents: ${_incidents.length}');
      _incidentsController.add(List.from(_incidents));
    }
  }

  void dispose() {
    _subscription?.cancel();
    _incidentsController.close();
    print('🔴 Incident service disposed');
  }
}