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
  List<Map<String, dynamic>> weatherData = [];
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
          weatherData = [
            {
              'city': city,
              'condition': data['weather'][0]['main'],
              'description': data['weather'][0]['description'],
              'temp': '${data['main']['temp'].round()}°C',
              'feels_like': '${data['main']['feels_like'].round()}°C',
              'icon': _getWeatherIcon(data['weather'][0]['main']),
              'humidity': '${data['main']['humidity']}%',
              'wind': '${(data['wind']['speed'] * 3.6).toStringAsFixed(1)} km/h',
              'pressure': '${data['main']['pressure']} hPa',
            }
          ];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load weather data: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching weather data: $e';
        isLoading = false;
      });
    }
  }

  IconData _getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'rain':
        return Icons.water_drop_outlined;
      case 'thunderstorm':
        return Icons.bolt_outlined;
      case 'clear':
        return Icons.wb_sunny_outlined;
      case 'clouds':
        return Icons.cloud_outlined;
      default:
        return Icons.cloud_outlined;
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
              icon: Icons.cloud_outlined,
              title: 'WEATHER MONITORING',
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage.isNotEmpty)
              Center(child: Text(errorMessage, style: TextStyle(color: Colors.red[700])))
            else
              _buildWeatherCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard() {
    final data = weatherData.first;
    
    return SizedBox(
      height: 250, // Maintain similar height to original
      child: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getWeatherIconColor(data['condition']).withOpacity(0.1),
                    _getWeatherIconColor(data['condition']).withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
          
          // Weather content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // City and condition
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data['city'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _getWeatherIconColor(data['condition']).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data['condition'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getWeatherIconColor(data['condition']),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Description
                Text(
                  data['description'].toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                    letterSpacing: 1.2,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Main temperature
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        data['icon'],
                        size: 60,
                        color: _getWeatherIconColor(data['condition']),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        data['temp'],
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Feels like
                Center(
                  child: Text(
                    'Feels like ${data['feels_like']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Weather details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWeatherDetail(Icons.water_drop, 'Humidity', data['humidity']),
                    _buildWeatherDetail(Icons.air, 'Wind', data['wind']),
                    _buildWeatherDetail(Icons.speed, 'Pressure', data['pressure']),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _getWeatherIconColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'rain':
        return Colors.blue[600]!;
      case 'thunderstorm':
        return Colors.deepPurple[600]!;
      case 'clear':
        return Colors.orange[600]!;
      case 'clouds':
        return Colors.blueGrey[600]!;
      default:
        return Colors.teal[600]!;
    }
  }
}