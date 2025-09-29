import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Delete user account with confirmation
  static Future<void> deleteUserAccount({
    required BuildContext context,
    required String userId,
    required String userEmail,
    required String collectionName,
    required VoidCallback onSuccess,
  }) async {
    final confirmed = await _showDeleteConfirmationDialog(
      context,
      userEmail,
    );

    if (confirmed) {
      await _performDeleteUser(
        context: context,
        userId: userId,
        collectionName: collectionName,
        userEmail: userEmail,
        onSuccess: onSuccess,
      );
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

  // Perform the actual deletion
  static Future<void> _performDeleteUser({
    required BuildContext context,
    required String userId,
    required String collectionName,
    required String userEmail,
    required VoidCallback onSuccess,
  }) async {
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

      // Delete user document
      await _firestore.collection(collectionName).doc(userId).delete();

      // If it's a radar app user, also delete their incidents
      if (collectionName == 'users') {
        await _deleteUserIncidents(userId);
      }

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      _showSuccessSnackbar(context, userEmail);

      // Call success callback
      onSuccess();
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      _showErrorSnackbar(context, e.toString());
    }
  }

  // Delete user incidents (for radar app users)
  static Future<void> _deleteUserIncidents(String userId) async {
    try {
      final incidentsSnapshot = await _firestore
          .collection('incidents')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in incidentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      if (incidentsSnapshot.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      // Log error but don't fail the main deletion
      debugPrint('Error deleting user incidents: $e');
    }
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