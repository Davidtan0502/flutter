import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:radar_dashboard/login/login_register_screen.dart';
import 'package:radar_dashboard/navigation/main_navigation.dart';
import 'package:radar_dashboard/login/admin_panel_screen.dart'; // ⬅️ add this
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? false;

  runApp(ProjectRadarApp(initialDarkMode: isDark));
}

class ProjectRadarApp extends StatefulWidget {
  final bool initialDarkMode;

  const ProjectRadarApp({super.key, required this.initialDarkMode});

  @override
  State<ProjectRadarApp> createState() => _ProjectRadarAppState();
}

class _ProjectRadarAppState extends State<ProjectRadarApp> {
  late bool isDarkMode;

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.initialDarkMode;
  }

  void toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = value;
    });
    await prefs.setBool('isDarkMode', value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project RADAR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const LoginRegisterScreen(), // ⬅️ Start at login
      routes: {
        '/admin-dashboard': (context) => NavigationScreen(
              isDarkMode: isDarkMode,
              onToggleTheme: toggleTheme,
              userRole: 'admin',
            ),
        '/user-dashboard': (context) => NavigationScreen(
              isDarkMode: isDarkMode,
              onToggleTheme: toggleTheme,
              userRole: 'user',
            ),
        '/admin-panel': (context) => const AdminPanelScreen(), // ⬅️ Add admin panel
      },
    );
  }
}
