import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:radar_dashboard/components/section_header.dart';

class WeatherMonitoring extends StatefulWidget {
  const WeatherMonitoring({super.key});

  @override
  State<WeatherMonitoring> createState() => _WeatherMonitoringState();
}

class _WeatherMonitoringState extends State<WeatherMonitoring> {
  Map<String, dynamic>? weatherData;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    const apiKey = '1e0dbc808580ffe843728e24a729dcee';
    const city = 'Manila';
    const countryCode = 'PH';
    const url = 'https://api.openweathermap.org/data/2.5/weather?q=$city,$countryCode&appid=$apiKey&units=metric';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          weatherData = {
            'city': city,
            'temp': '${data['main']['temp'].round()}°C',
            'feels_like': '${data['main']['feels_like'].round()}°C',
            'condition': data['weather'][0]['main'],
            'icon': _getWeatherIcon(data['weather'][0]['main']),
            'color': _getWeatherColor(data['weather'][0]['main']),
          };
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load weather data';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Connection error';
        isLoading = false;
      });
    }
  }

  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'rain': return Icons.water_drop;
      case 'thunderstorm': return Icons.electric_bolt;
      case 'clear': return Icons.wb_sunny;
      case 'clouds': return Icons.cloud;
      default: return Icons.cloud;
    }
  }

  Color _getWeatherColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'rain': return Colors.blue;
      case 'thunderstorm': return Colors.deepPurple;
      case 'clear': return Colors.orange;
      case 'clouds': return Colors.blueGrey;
      default: return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              icon: Icons.cloud,
              title: 'WEATHER MONITORING',
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage.isNotEmpty)
              Center(
                child: Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red[700]),
                ),
              )
            else
              _buildWeatherDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDisplay() {
    final color = weatherData!['color'];
    
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // City and condition
            Text(
              weatherData!['city'],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            
            // Weather icon and temperature
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  weatherData!['icon'],
                  size: 60,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  weatherData!['temp'],
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            
            // Feels like
            Text(
              'Feels like ${weatherData!['feels_like']}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}