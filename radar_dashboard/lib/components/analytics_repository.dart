import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // All the same methods as above, but without FetchOptions usage...

  Future<int> getTotalIncidentsWithCount() async {
    try {
      // Simple approach without FetchOptions
      final response = await _supabase
          .from('incidents')
          .select();
      
      return response.length;
    } catch (e) {
      _logError('getTotalIncidentsWithCount', e);
      return 0;
    }
  }

  // Method to get efficient counts for large datasets
  Future<int> getEfficientCount(String tableName, {Map<String, dynamic>? filters}) async {
    try {
      // Select only the ID column for efficiency
      var query = _supabase.from(tableName).select('id');
      
      // Apply filters if provided
      if (filters != null) {
        filters.forEach((key, value) {
          query = query.eq(key, value);
        });
      }
      
      final response = await query;
      return response.length;
    } catch (e) {
      _logError('getEfficientCount', e);
      return 0;
    }
  }

  // Usage examples for efficient counting:
  Future<int> getActiveAlertsCount() async {
    return getEfficientCount('alerts', filters: {'status': 'active'});
  }

  Future<int> getResolvedIncidentsCount() async {
    return getEfficientCount('incidents', filters: {'status': 'resolved'});
  }

  Future<int> getTodayIncidentsCount() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    try {
      final response = await _supabase
          .from('incidents')
          .select('id')
          .gte('timestamp', todayStart.toIso8601String())
          .lte('timestamp', todayEnd.toIso8601String());
      
      return response.length;
    } catch (e) {
      _logError('getTodayIncidentsCount', e);
      return 0;
    }
  }

  void _logError(String method, dynamic error) {
    if (kDebugMode) {
      print('AnalyticsRepository error in $method: $error');
    }
  }
}