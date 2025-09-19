import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardScreen(
      onMenuPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User menu clicked")),
        );
      },
    );
  }
}
