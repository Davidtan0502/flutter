import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class ModeratorDashboard extends StatelessWidget {
  const ModeratorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardScreen(
      onMenuPressed: () {
        Navigator.pushNamed(context, '/moderator-panel');
      },
    );
  }
}