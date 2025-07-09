import 'package:flutter/material.dart';
import 'package:radar_dashboard/navigation/main_navigation.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => NavigationScreen(
                  isDarkMode: false,
                  onToggleTheme: (val) {},
                  userRole: 'admin', // or 'user', based on actual role
                ),
              ),
            );

          },
          child: const Text('Login'),
        ),
      ),
    );
  }
}
