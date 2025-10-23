import 'dart:async';
import 'package:flutter/foundation.dart';
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
      
      debugPrint('✅ Loaded ${_incidents.length} initial incidents');
    } catch (e) {
      debugPrint('❌ Error loading initial incidents: $e');
    }
  }

  void _setupRealTimeSubscription() {
    _subscription = _supabase
        .from('incidents')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> events) {
      _handleRealTimeUpdates(events);
    }, onError: (error) {
      debugPrint('❌ Real-time subscription error: $error');
      // Attempt to reconnect after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        _setupRealTimeSubscription();
      });
    });

    debugPrint('✅ Real-time subscription started');
  }

  void _handleRealTimeUpdates(List<Map<String, dynamic>> events) {
    debugPrint('🔄 Real-time update: ${events.length} events');
    
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
            debugPrint('➕ New incident: ${newData['id']}');
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
              debugPrint('✏️ Updated incident: ${newData['id']}');
            }
          }
          break;
        case 'DELETE':
          if (oldData != null) {
            _incidents.removeWhere(
              (incident) => incident['id'] == oldData['id'],
            );
            hasChanges = true;
            debugPrint('🗑️ Deleted incident: ${oldData['id']}');
          }
          break;
      }
    }

    if (hasChanges) {
      debugPrint('📊 Total incidents: ${_incidents.length}');
      _incidentsController.add(List.from(_incidents));
    }
  }

  // Spam Filter Methods
  static Future<bool> isSpamIncident(Map<String, dynamic> incidentData) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Check 1: Recent duplicate incidents from same reporter
      final recentIncidents = await supabase
          .from('incidents')
          .select()
          .eq('contact_number', incidentData['contact_number'])
          .gte('created_at', 
              DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String())
          .limit(5);

      if (recentIncidents.length >= 3) {
        return true; // Too many incidents in short time
      }

      // Check 2: Similar content detection
      final description = incidentData['description']?.toString() ?? '';
      if (description.length > 20) {
        final similarIncidents = await supabase
            .from('incidents')
            .select()
            .ilike('description', '%${description.substring(0, 20)}%')
            .gte('created_at', 
                DateTime.now().subtract(const Duration(hours: 1)).toIso8601String())
            .limit(3);

        if (similarIncidents.length >= 2) {
          return true; // Similar descriptions recently
        }
      }

      // Check 3: Check against spam patterns
      final descLower = description.toLowerCase();
      final spamPatterns = [
        'http://', 'https://', 'www.', '.com', 'buy now', 'click here',
        'make money', 'free money', 'urgent money', 'lottery', 'winner',
        'earn money', 'work from home', 'get rich', 'investment', 'bitcoin',
        'crypto', 'password', 'login', 'account', 'verify', 'congratulations'
      ];

      for (final pattern in spamPatterns) {
        if (descLower.contains(pattern)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Spam check error: $e');
      return false; // Default to not spam if check fails
    }
  }

  static Future<void> createInitialIncidentWithSpamCheck(
    Map<String, dynamic> incidentData,
  ) async {
    try {
      // Check for spam before creating incident
      final isSpam = await isSpamIncident(incidentData);
      
      if (isSpam) {
        // Log spam attempt but don't create incident
        debugPrint('🚫 Spam incident blocked: ${incidentData['contact_number']}');
        throw Exception('This incident appears to be spam and cannot be submitted.');
      }

      // Proceed with normal incident creation if not spam
      await createInitialIncident(incidentData);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> createInitialIncident(
    Map<String, dynamic> incidentData,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Insert the main incident record
      final response = await supabase
          .from('incidents')
          .insert(incidentData)
          .select();
      
      if (response.isNotEmpty) {
        final incidentId = response.first['id'].toString();
        
        // Create initial status update record for 'pending'
        await supabase
            .from('incident_status_updates')
            .insert({
              'incident_id': incidentId,
              'status': 'pending',
              'note': 'Incident reported',
              'updated_by': incidentData['name'] ?? 'Anonymous',
              'created_at': DateTime.now().toIso8601String(),
            });
      }
    } catch (e) {
      throw Exception('Failed to create incident: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> getStatusUpdatesStream() {
    return Supabase.instance.client
        .from('incident_status_updates')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  static Future<void> deleteIncident(String id) async {
    await Supabase.instance.client
        .from('incidents')
        .delete()
        .eq('id', id);
  }

  static Future<List<StatusUpdate>> getStatusUpdates(String incidentId) async {
    final response = await Supabase.instance.client
        .from('incident_status_updates')
        .select()
        .eq('incident_id', incidentId)
        .order('created_at', ascending: true);

    return (response as List).map((update) => StatusUpdate.fromMap(update)).toList();
  }

  static Future<void> updateIncidentStatus(
    String id, {
    required String status,
    required String note,
    required String updatedBy,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Update incident status
      await supabase
          .from('incidents')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      // Create status update record
      await supabase
          .from('incident_status_updates')
          .insert({
            'incident_id': id,
            'status': status,
            'note': note,
            'updated_by': updatedBy,
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      throw Exception('Failed to update incident status: $e');
    }
  }

  static Future<void> batchUpdateStatus(
    List<String> ids,
    String status,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      
      for (final id in ids) {
        // Update incident status
        await supabase
            .from('incidents')
            .update({
              'status': status,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id);

        // Create status update record
        await supabase
            .from('incident_status_updates')
            .insert({
              'incident_id': id,
              'status': status,
              'note': 'Bulk status update',
              'updated_by': 'moderator',
              'created_at': DateTime.now().toIso8601String(),
            });
      }
    } catch (e) {
      throw Exception('Failed to batch update status: $e');
    }
  }

  static Future<void> batchDeleteIncidents(List<String> ids) async {
    try {
      final supabase = Supabase.instance.client;
      
      for (final id in ids) {
        await supabase
            .from('incidents')
            .delete()
            .eq('id', id);
      }
    } catch (e) {
      throw Exception('Failed to batch delete incidents: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _incidentsController.close();
    debugPrint('🔴 Incident service disposed');
  }
}

class StatusUpdate {
  final String id;
  final String incidentId;
  final String status;
  final String note;
  final String updatedBy;
  final DateTime createdAt;

  StatusUpdate({
    required this.id,
    required this.incidentId,
    required this.status,
    required this.note,
    required this.updatedBy,
    required this.createdAt,
  });

  factory StatusUpdate.fromMap(Map<String, dynamic> data) {
    return StatusUpdate(
      id: data['id'].toString(),
      incidentId: data['incident_id'].toString(),
      status: data['status'].toString(),
      note: data['note']?.toString() ?? '',
      updatedBy: data['updated_by'].toString(),
      createdAt: DateTime.parse(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incident_id': incidentId,
      'status': status,
      'note': note,
      'updated_by': updatedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}