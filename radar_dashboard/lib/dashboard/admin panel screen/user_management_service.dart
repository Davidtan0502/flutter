import 'package:flutter/material.dart';
import 'package:radar_dashboard/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementService {
  static final SupabaseClient _adminClient = SupabaseClient(
    SupabaseConfig.url,
    SupabaseConfig.serviceRoleKey
  );

  static Future<void> deleteUserAccount({
    required BuildContext context,
    required String userId,
    required String userEmail,
    VoidCallback? onSuccess,
  }) async {
    final confirmed = await _showDeleteConfirmationDialog(context, userEmail);
    
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Deleting user account...'),
              ],
            ),
          );
        },
      );

      debugPrint('Attempting to delete user: $userId ($userEmail) from app_users table');
      
      // Use the admin client with service role key
      final response = await _adminClient
          .from('app_users')
          .delete()
          .eq('id', userId);

      debugPrint('Delete response: $response');

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackbar(context, userEmail);
      }

      onSuccess?.call();
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Check if it's an RLS policy error
        if (e.toString().contains('policy') || e.toString().contains('RLS')) {
          _showErrorSnackbar(
            context, 
            'Permission denied. Please add DELETE policy to app_users table.\nError: $e'
          );
        } else {
          _showErrorSnackbar(context, 'Delete failed: $e');
        }
        
        debugPrint('Detailed delete error: $e');
      }
    }
  }

  // Test method to verify service role access
  static Future<void> testServiceRoleAccess(BuildContext context) async {
    try {
      debugPrint('Testing service role access to app_users table...');
      
      // Test if we can query the table - REMOVED COUNT PARAMETER
      final testQuery = await _adminClient
          .from('app_users')
          .select('id, email')
          .limit(2);
      
      debugPrint('Query test successful. Found ${testQuery.length} users');
      
      // Test if we can count users - FIXED COUNT SYNTAX
      final countResponse = await _adminClient
          .from('app_users')
          .select('*')
          .limit(1); // Just get one to verify access
      
      debugPrint('Service role can access app_users table');
      
      _showSuccessSnackbar(context, 'Service role access verified');
      
    } catch (e) {
      debugPrint('Service role access test failed: $e');
      _showErrorSnackbar(context, 'Service role access failed: $e');
    }
  }

  // Check if user exists in app_users table
  static Future<bool> userExistsInAppUsers(String userId) async {
    try {
      final response = await _adminClient
          .from('app_users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      debugPrint('User existence check error: $e');
      return false;
    }
  }

  // Get user details from app_users table
  static Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final response = await _adminClient
          .from('app_users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      debugPrint('Get user details error: $e');
      return null;
    }
  }

  // Update user role in app_users table
  static Future<void> updateUserRole({
    required BuildContext context,
    required String userId,
    required String newRole,
    required String userEmail,
    VoidCallback? onSuccess,
  }) async {
    if (!context.mounted) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Updating user role...'),
              ],
            ),
          );
        },
      );

      final response = await _adminClient
          .from('app_users')
          .update({'role': newRole, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);

      debugPrint('Update role response: $response');

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully updated $userEmail role to $newRole'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      onSuccess?.call();
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _showErrorSnackbar(context, 'Failed to update role: $e');
      }
    }
  }

  // Update user status in app_users table
  static Future<void> updateUserStatus({
    required BuildContext context,
    required String userId,
    required String newStatus,
    required String userEmail,
    VoidCallback? onSuccess,
  }) async {
    if (!context.mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Updating user status...'),
              ],
            ),
          );
        },
      );

      final response = await _adminClient
          .from('app_users')
          .update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);

      debugPrint('Update status response: $response');

      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully updated $userEmail status to $newStatus'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      onSuccess?.call();
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _showErrorSnackbar(context, 'Failed to update status: $e');
      }
    }
  }

  // Show confirmation dialog
  static Future<bool> _showDeleteConfirmationDialog(
    BuildContext context,
    String userEmail,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Delete User Account'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this user account?',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  userEmail,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '⚠️ This action cannot be undone. All user data will be permanently deleted.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  static void _showSuccessSnackbar(BuildContext context, String userEmail) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('User $userEmail deleted successfully'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void _showErrorSnackbar(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}