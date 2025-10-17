import 'package:flutter/foundation.dart';
import 'package:radar_dashboard/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class AdminManagementService {
  // Use your config values
  static final SupabaseClient _adminClient = SupabaseClient(
    SupabaseConfig.url, // From your config
    SupabaseConfig.serviceRoleKey // From your config
  );

  // Promote user to admin
  static Future<bool> promoteToAdmin(String userId) async {
    try {
      await _adminClient
          .from('dashboard_users')
          .update({'role': 'admin'})
          .eq('id', userId);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error promoting user to admin: $e');
      }
      return false;
    }
  }

  // Demote admin to user
  static Future<bool> demoteToUser(String userId) async {
    try {
      await _adminClient
          .from('dashboard_users')
          .update({'role': 'user'})
          .eq('id', userId);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error demoting admin to user: $e');
      }
      return false;
    }
  }

  // Get service role client for complex operations
  static SupabaseClient get adminClient => _adminClient;
}