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
    required String collectionName,
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

      await _adminClient
          .from(collectionName)
          .delete()
          .eq('id', userId);

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
        _showErrorSnackbar(context, e.toString());
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
        content: Text('Failed to delete user: $error'),
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