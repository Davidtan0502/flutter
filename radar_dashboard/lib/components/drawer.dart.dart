import 'package:flutter/material.dart';

class RadarDrawer extends StatelessWidget {
  const RadarDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color.fromARGB(255, 239, 239, 239),
      elevation: 4,
      child: ListView(
        children: [
          _buildDrawerHeader(),
          _buildDrawerItem(Icons.dashboard_outlined, 'Dashboard', true),
          _buildDrawerItem(Icons.emergency_outlined, 'Active Emergencies', false),
          _buildDrawerItem(Icons.map_outlined, 'Hazard Mapping', false),
          _buildDrawerItem(Icons.analytics_outlined, 'Analytics', false),
          _buildDrawerItem(Icons.people_outlined, 'Response Teams', false),
          _buildDrawerItem(Icons.settings_outlined, 'System Settings', false),
          const Divider(color: Colors.grey, height: 32, thickness: 0.5),
          _buildDrawerItem(Icons.exit_to_app_outlined, 'Logout', false),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
      decoration: const BoxDecoration(
        color: Color(0xFF2C5282),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROJECT RADAR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Emergency Response System',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'VERSION 2.1.0',
              style: TextStyle(
                color: Colors.blueGrey,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, bool isSelected) {
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? Colors.blue[600] : Colors.blueGrey[600]),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue[600] : Colors.blueGrey[800],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      selected: isSelected,
      hoverColor: Colors.blue[50],
      onTap: () {},
    );
  }
}