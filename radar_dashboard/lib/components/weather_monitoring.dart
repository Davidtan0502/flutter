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
  List<Map<String, dynamic>> forecastData = [];
  bool isLoading = false;
  String errorMessage = '';
  final TextEditingController _cityController = TextEditingController();
  String currentCity = 'Manila';

  @override
  void initState() {
    super.initState();
    _fetchWeatherData(currentCity);
  }

  Future<void> _fetchWeatherData(String city) async {
    const apiKey = '1e0dbc808580ffe843728e24a729dcee';
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          weatherData = {
            'city': city,
            'temp': data['main']['temp']?.toDouble() ?? 0.0,
            'condition': data['weather'][0]['main'] ?? 'N/A',
            'clouds': data['clouds']['all']?.toString() ?? '0',
            'humidity': data['main']['humidity']?.toString() ?? '0',
            'pressure': data['main']['pressure']?.toString() ?? '0',
          };
          isLoading = false;
          currentCity = city;
          _cityController.clear();
        });
        
        // Generate mock forecast data for today, tomorrow, and next day
        _generateMockForecast();
      } else if (response.statusCode == 404) {
        setState(() {
          errorMessage = 'City "$city" not found. Please try another location.';
          isLoading = false;
        });
      } else {
        final data = json.decode(response.body);
        setState(() {
          errorMessage = data['message'] ?? 'Failed to load weather data';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Connection error. Please check your internet.';
        isLoading = false;
      });
    }
  }

  void _generateMockForecast() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final nextDay = now.add(const Duration(days: 2));
    
    // Mock forecast data based on current condition
    final currentCondition = weatherData!['condition'];
    final currentTemp = weatherData!['temp'];
    
    setState(() {
      forecastData = [
        {
          'date': now,
          'day': 'Today',
          'temp': currentTemp,
          'condition': currentCondition,
        },
        {
          'date': tomorrow,
          'day': 'Tomorrow',
          'temp': currentTemp + (currentCondition.toLowerCase() == 'rain' ? -2 : 1),
          'condition': currentCondition,
        },
        {
          'date': nextDay,
          'day': 'Next Day',
          'temp': currentTemp + (currentCondition.toLowerCase() == 'rain' ? -1 : 2),
          'condition': currentCondition,
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: double.infinity,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SectionHeader(
                icon: Icons.cloud,
                title: 'WEATHER UPDATES', subtitle: '',
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _cityController,
                decoration: InputDecoration(
                  hintText: 'Enter city name',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue, size: 20),
                    onPressed: () {
                      if (_cityController.text.isNotEmpty) {
                        _fetchWeatherData(_cityController.text);
                      }
                    },
                  ),
                  errorText: errorMessage.isNotEmpty && !isLoading ? errorMessage : null,
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _fetchWeatherData(value);
                  }
                },
              ),
              const SizedBox(height: 5),
              
              if (isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue,
                    ),
                  ),
                )
              else if (weatherData != null)
                Column(
                  children: [
                    _buildWeatherDisplay(),
                    const SizedBox(height: 5),
                    _buildForecastContainer(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // City name with location icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.blue, size: 16),
              const SizedBox(width: 6),
              Text(
                currentCity,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Temperature display
          Text(
            '${weatherData!['temp'].toStringAsFixed(1)}°C',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Weather condition with icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getWeatherIcon(weatherData!['condition']),
                size: 20,
                color: _getWeatherColor(weatherData!['condition']),
              ),
              const SizedBox(width: 6),
              Text(
                weatherData!['condition'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          
          // Weather details
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildWeatherDetail('Clouds', '${weatherData!['clouds']}%', Icons.cloud),
              _buildWeatherDetail('Humidity', '${weatherData!['humidity']}%', Icons.water_drop),
              _buildWeatherDetail('Pressure', '${weatherData!['pressure']} hPa', Icons.speed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForecastContainer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'WEATHER FORECAST',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800],
                ),
              ),
              Text(
                '3-Day Forecast',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (forecastData.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'No forecast data available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: forecastData.map((forecast) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 1,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          forecast['day'],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.blueGrey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          _getWeatherIcon(forecast['condition']),
                          size: 16,
                          color: _getWeatherColor(forecast['condition']),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${forecast['temp'].toStringAsFixed(0)}°C',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetail(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }
}